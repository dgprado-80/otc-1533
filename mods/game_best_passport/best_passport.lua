-- Best Partner Passport client UI (benefits + private hunt builder)
-- Protocol: ExtendedOpcode ExtendedIds.BestPassport (223) + JSON
-- Docs: https://bestserverot.com.br/?passport_hunt

local OPCODE = (ExtendedIds and ExtendedIds.BestPassport) or 223

local window = nil
local currentTab = 'benefits'
local lastState = nil
local selectedMonsters = {}
local selectedDifficulty = 'normal'
local selectedRespawn = 'normal'
local monsterPage = 1
local monsterLetter = '*' -- all monsters by default
local searchQuery = ''
local searchMode = false
local totalPages = 1
local letterBarReady = false
local monsterLooks = {} -- name -> outfit table {type, auxType, head, ...}
local syncTimeoutEvent = nil
local searchEvent = nil
local focusedMonsterRow = nil
local lastBenefitsKey = nil
local lastMonsterRequestKey = nil
local MONSTER_PAGE_SIZE = 20

local function outfitFromItem(item)
  if type(item) ~= 'table' then
    local lookType = tonumber(item) or 0
    return { type = lookType, auxType = 0, head = 0, body = 0, legs = 0, feet = 0, addons = 0 }
  end
  local lookType = tonumber(item.lookType or item.type) or 0
  local lookTypeEx = tonumber(item.lookTypeEx or item.auxType) or 0
  return {
    type = lookType,
    auxType = lookType > 0 and 0 or lookTypeEx,
    head = tonumber(item.lookHead or item.head) or 0,
    body = tonumber(item.lookBody or item.body) or 0,
    legs = tonumber(item.lookLegs or item.legs) or 0,
    feet = tonumber(item.lookFeet or item.feet) or 0,
    addons = tonumber(item.lookAddons or item.addons) or 0,
  }
end

local function storeMonsterLook(name, item)
  if not name then return end
  monsterLooks[name:lower()] = outfitFromItem(item)
end

local function cancelSyncTimeout()
  removeEvent(syncTimeoutEvent)
  syncTimeoutEvent = nil
end

local function armSyncTimeout()
  cancelSyncTimeout()
  syncTimeoutEvent = scheduleEvent(function()
    syncTimeoutEvent = nil
    if not window or not window:isVisible() then return end
    if modules.game_textmessage then
      modules.game_textmessage.displayFailureMessage('Passport: server did not answer opcode 223')
    end
  end, 3000)
end

local function send(action, extra)
  if not g_game or not g_game.isOnline or not g_game.isOnline() then
    return false
  end
  local protocol = g_game.getProtocolGame and g_game.getProtocolGame() or nil
  if not protocol or not protocol.sendExtendedOpcode then
    if modules.game_textmessage then
      modules.game_textmessage.displayFailureMessage('Passport: no game protocol')
    end
    return false
  end
  local payload = extra or {}
  payload.action = action
  local ok, encoded = pcall(function() return json.encode(payload) end)
  if not ok or type(encoded) ~= 'string' then
    return false
  end
  local sentOk = pcall(function()
    protocol:sendExtendedOpcode(OPCODE, encoded)
  end)
  return sentOk and true or false
end

local function forceUiRefresh()
  -- Intentionally light: the old setWidth(w+/-1) nudge forced a full window
  -- layout every opcode and crushed FPS. Labels update via setText already.
end

local function setCreatureLook(widget, look)
  if not widget then return end
  local outfit = outfitFromItem(look)
  pcall(function()
    if (outfit.type and outfit.type > 0) or (outfit.auxType and outfit.auxType > 0) then
      widget:setOutfit(outfit)
      widget:setVisible(true)
    else
      widget:setOutfit({ type = 0, auxType = 0 })
      widget:setVisible(false)
    end
  end)
end

local function updateSelectedSlots()
  if not window then return end
  for i = 1, 4 do
    local slot = window:recursiveGetChildById('slot' .. i)
    if slot then
      local label = slot:getChildById('nameLabel')
      local previewBox = slot:getChildById('previewBox')
      local preview = previewBox and previewBox:getChildById('preview') or slot:recursiveGetChildById('preview')
      local name = selectedMonsters[i]
      if label then
        if name then
          label:setText(name)
          label:setColor('#ffd76aff')
        else
          label:setText(string.format('Slot %d', i))
          label:setColor('#808080ff')
        end
      end
      setCreatureLook(preview, name and monsterLooks[name:lower()] or nil)
    end
  end
end

local function updateDiffButtons()
  if not window then return end
  local map = {
    noob = 'diffNoob',
    normal = 'diffNormal',
    hardcore = 'diffHard',
  }
  for id, widgetId in pairs(map) do
    local btn = window:recursiveGetChildById(widgetId)
    if btn then
      btn:setEnabled(selectedDifficulty ~= id)
    end
  end
  local rmap = { normal = 'respawnNormal', slow = 'respawnSlow' }
  for id, widgetId in pairs(rmap) do
    local btn = window:recursiveGetChildById(widgetId)
    if btn then
      btn:setEnabled(selectedRespawn ~= id)
    end
  end
end

local function updateHeader(state)
  if not window or not state then return end
  local passport = state.passport or {}
  local focus = state.focus or {}
  local statusBig = window:recursiveGetChildById('statusBig')
  local statusSub = window:recursiveGetChildById('statusSub')
  local focusLabel = window:recursiveGetChildById('focusLabel')
  local focusBar = window:recursiveGetChildById('focusBar')
  local focusSub = window:recursiveGetChildById('focusSub')
  local shopButton = window:recursiveGetChildById('shopButton')

  if passport.active then
    if statusBig then
      statusBig:setText('ACTIVE')
      statusBig:setColor('#7dff9fff')
    end
    if statusSub then
      statusSub:setText(string.format('%d day(s) remaining | VIP %s', passport.daysRemaining or 0, passport.hasVip and 'ON' or 'OFF'))
    end
    if shopButton then shopButton:setText('Renew') end
  else
    if statusBig then
      statusBig:setText('INACTIVE')
      statusBig:setColor('#ff9090ff')
    end
    if statusSub then
      statusSub:setText('Support BestServer and unlock exclusive benefits')
    end
    if shopButton then shopButton:setText('Get Passport') end
  end

  if focusLabel then
    focusLabel:setText(string.format('Hunt Focus  %s', focus.label or '0h 00m'))
  end
  if focusBar then
    if focusBar.setOn then focusBar:setOn(true) end
    focusBar:setPercent(focus.percent or 0)
    focusBar:setText(focus.label or '')
    if focus.band == 'yellow' then
      focusBar:setBackgroundColor('#8a6a20ff')
    elseif focus.band == 'empty' then
      focusBar:setBackgroundColor('#6a2020ff')
    else
      focusBar:setBackgroundColor('#2a6a2aff')
    end
  end
  if focusSub then
    local xp = focus.xpMultiplier or 1
    local drain = focus.draining and 'draining' or 'recovering'
    focusSub:setText(string.format('%s | XP x%.1f in hunt', drain, xp))
  end
end

local function updateLiveBonuses(state)
  if not window or not state then return end
  local title = window:recursiveGetChildById('liveBonusTitle')
  local body = window:recursiveGetChildById('liveBonusBody')
  local passport = state.passport or {}
  local live = (state.benefits and state.benefits.live) or {}

  if not passport.active then
    if title then title:setText('Passport locked') end
    if body then
      body:setText('Purchase Best Partner Passport on the website to unlock VIP-level bonuses, private hunts and more on every character.')
      body:setColor('#c08080ff')
    end
    return
  end

  if title then title:setText('Your active bonuses') end
  if body then
    body:setText(string.format(
      'EXP +%d%% | Loot +%d%% | Skill +%d%% | Boss CD x%.1f | Dust x%d | Forge gold -%d%% | Tasks x2',
      live.expPercent or 0,
      live.lootPercent or 0,
      live.skillPercent or 0,
      live.bossCooldownMultiplier or 0.5,
      live.dustLimitMultiplier or 2,
      math.floor((live.forgeGoldDiscount or 0.5) * 100)
    ))
    body:setColor('#c8e0a8ff')
  end
end

local function fillBenefits(state)
  if not window or not state then return end
  local scroll = window:recursiveGetChildById('benefitsScroll')
  if not scroll then return end
  local list = (state.benefits and state.benefits.list) or {}
  local active = state.passport and state.passport.active and true or false
  local key = tostring(active) .. '#' .. tostring(#list)
  for i, benefit in ipairs(list) do
    key = key .. '|' .. tostring(benefit.title or '') .. ':' .. tostring(benefit.desc or '')
  end
  if key == lastBenefitsKey and scroll:getChildCount() == #list then
    return
  end
  lastBenefitsKey = key
  scroll:destroyChildren()
  for _, benefit in ipairs(list) do
    local card = g_ui.createWidget('PassportBenefitCard', scroll)
    local title = card:getChildById('title')
    local desc = card:getChildById('desc')
    if title then
      title:setText((active and '[ON] ' or '[ ] ') .. (benefit.title or 'Benefit'))
      title:setColor(active and '#7dff9fff' or '#ffd76aff')
    end
    if desc then
      desc:setText(benefit.desc or '')
    end
  end
end

local function updateHuntStatus(state)
  if not window or not state then return end
  local label = window:recursiveGetChildById('huntStatusLabel')
  local startBtn = window:recursiveGetChildById('startHuntButton')
  local joinBtn = window:recursiveGetChildById('joinHuntButton')
  local leaveBtn = window:recursiveGetChildById('leaveHuntButton')
  local hunt = state.hunt or {}
  local passport = state.passport or {}

  local lines = {}
  if not passport.active then
    lines[#lines + 1] = 'Passport required to create or join private hunts.'
  elseif hunt.inHunt then
    lines[#lines + 1] = string.format('Inside hunt #%s | %s | party %d/%d',
      tostring(hunt.slotId or '?'),
      table.concat(hunt.monsters or {}, ', '),
      hunt.partySize or 0,
      hunt.maxPartySize or 4)
  elseif hunt.hasOwnedHunt then
    lines[#lines + 1] = string.format('You own an active hunt - use Join to re-enter. Monsters: %s',
      table.concat(hunt.monsters or {}, ', '))
  else
    lines[#lines + 1] = string.format('Ready to build | max %d monsters | up to %d players',
      hunt.maxMonsterTypes or 4, hunt.maxPartySize or 4)
    if (hunt.cooldownRemaining or 0) > 0 then
      lines[#lines + 1] = string.format('Cooldown: %ds', hunt.cooldownRemaining)
    end
  end
  if label then label:setText(table.concat(lines, '  |  ')) end

  if startBtn then
    startBtn:setEnabled(passport.active and hunt.canOpen and #selectedMonsters > 0)
  end
  if joinBtn then
    joinBtn:setEnabled(passport.active and (hunt.hasOwnedHunt or not hunt.inHunt))
  end
  if leaveBtn then
    leaveBtn:setEnabled(hunt.inHunt and true or false)
  end
end

local function fillLetterBar(letters)
  if not window then return end
  local bar = window:recursiveGetChildById('letterBar')
  if not bar then return end
  bar:destroyChildren()
  letterBarReady = true

  local function addLetterButton(id, label)
    local btn = g_ui.createWidget('Button', bar)
    btn:setId('letter_' .. id)
    btn:setText(label)
    btn:setWidth(id == '*' and 28 or 16)
    btn:setHeight(20)
    btn:setFont('verdana-10px-rounded')
    btn.onClick = function()
      setMonsterLetter(id)
    end
    btn:setEnabled(monsterLetter ~= id or searchMode)
  end

  addLetterButton('*', 'All')
  for _, letter in ipairs(letters or {}) do
    addLetterButton(tostring(letter):lower(), tostring(letter):upper())
  end
end

local function fillMonsters(items)
  if not window then return end
  local list = window:recursiveGetChildById('monstersList')
  if not list then return end
  focusedMonsterRow = nil
  list:destroyChildren()

  local scroll = window:recursiveGetChildById('monstersScroll')
  if scroll and scroll.setValue then
    pcall(function() scroll:setValue(0) end)
  end

  if not items or #items == 0 then
    local row = g_ui.createWidget('PassportMonsterRow', list)
    local nameLabel = row:getChildById('nameLabel')
    if nameLabel then
      nameLabel:setText('No monsters found')
      nameLabel:setColor('#a0a0a0ff')
    end
    row:setFocusable(false)
    return
  end

  for _, item in ipairs(items) do
    local row = g_ui.createWidget('PassportMonsterRow', list)
    row.monsterName = item.name
    row.lookData = outfitFromItem(item)
    storeMonsterLook(item.name, item)
    local nameLabel = row:getChildById('nameLabel')
    local preview = row:getChildById('preview')
    if nameLabel then nameLabel:setText(item.name or '?') end
    setCreatureLook(preview, item)
    row.onFocusChange = function(widget, focused)
      if focused then
        focusedMonsterRow = widget
      end
    end
  end
end

function setMonsterLetter(letter)
  searchMode = false
  monsterLetter = letter or '*'
  monsterPage = 1
  if window then
    local edit = window:recursiveGetChildById('searchEdit')
    if edit then edit:setText('') end
  end
  searchQuery = ''
  lastMonsterRequestKey = nil
  requestMonsters()
  -- refresh enabled state on letter buttons
  if window then
    local bar = window:recursiveGetChildById('letterBar')
    if bar then
      for i = 1, bar:getChildCount() do
        local btn = bar:getChildByIndex(i)
        if btn then
          local id = btn:getId() or ''
          local key = id:gsub('^letter_', '')
          btn:setEnabled(key ~= monsterLetter)
        end
      end
    end
  end
end

local function applyState(state)
  if not state then return end
  cancelSyncTimeout()
  lastState = state
  updateHeader(state)
  updateLiveBonuses(state)
  fillBenefits(state)
  updateHuntStatus(state)
  updateSelectedSlots()
  updateDiffButtons()
  forceUiRefresh()
end

function requestMonsters()
  local key
  if searchMode and searchQuery ~= '' then
    key = 's:' .. searchQuery .. ':' .. tostring(monsterPage)
  else
    key = 'l:' .. tostring(monsterLetter or '*') .. ':' .. tostring(monsterPage)
  end
  if key == lastMonsterRequestKey then
    return
  end
  lastMonsterRequestKey = key
  if searchMode and searchQuery ~= '' then
    send('search', { query = searchQuery, page = monsterPage, pageSize = MONSTER_PAGE_SIZE })
  else
    send('monsters', { letter = monsterLetter or '*', page = monsterPage, pageSize = MONSTER_PAGE_SIZE })
  end
end

function setTab(tab)
  currentTab = tab or 'benefits'
  if not window then return end
  local benefitsPanel = window:recursiveGetChildById('benefitsPanel')
  local huntPanel = window:recursiveGetChildById('huntPanel')
  local tabBenefits = window:recursiveGetChildById('tabBenefits')
  local tabHunt = window:recursiveGetChildById('tabHunt')
  local isBenefits = currentTab == 'benefits'
  if benefitsPanel then benefitsPanel:setVisible(isBenefits) end
  if huntPanel then huntPanel:setVisible(not isBenefits) end
  if tabBenefits then tabBenefits:setEnabled(not isBenefits) end
  if tabHunt then tabHunt:setEnabled(isBenefits) end
  if not isBenefits then
    requestMonsters()
    updateHuntStatus(lastState or {})
  end
end

function setDifficulty(id)
  selectedDifficulty = id or 'normal'
  updateDiffButtons()
end

function setRespawn(id)
  selectedRespawn = id or 'normal'
  updateDiffButtons()
end

function clearSelection()
  selectedMonsters = {}
  updateSelectedSlots()
  if lastState then updateHuntStatus(lastState) end
end

function addSelectedMonster()
  if not window then return end
  local list = window:recursiveGetChildById('monstersList')
  if not list then return end
  local focused = focusedMonsterRow
  if (not focused or not focused.monsterName) and list.getFocusedChild then
    focused = list:getFocusedChild()
  end
  if not focused or not focused.monsterName then
    if modules.game_textmessage then
      modules.game_textmessage.displayFailureMessage('Select a monster from the list first')
    end
    return
  end
  if #selectedMonsters >= 4 then
    if modules.game_textmessage then
      modules.game_textmessage.displayFailureMessage('You can select up to 4 monsters')
    end
    return
  end
  for _, name in ipairs(selectedMonsters) do
    if name:lower() == focused.monsterName:lower() then
      return
    end
  end
  selectedMonsters[#selectedMonsters + 1] = focused.monsterName
  if focused.lookData then
    storeMonsterLook(focused.monsterName, focused.lookData)
  end
  updateSelectedSlots()
  if lastState then updateHuntStatus(lastState) end
end

function doSearch()
  if not window then return end
  local edit = window:recursiveGetChildById('searchEdit')
  local nextQuery = edit and edit:getText() or ''
  local nextMode = #nextQuery >= 2
  if nextQuery == searchQuery and nextMode == searchMode and monsterPage == 1 then
    return
  end
  searchQuery = nextQuery
  monsterPage = 1
  if nextMode then
    searchMode = true
  else
    searchMode = false
    if monsterLetter == '' then monsterLetter = '*' end
  end
  lastMonsterRequestKey = nil
  requestMonsters()
end

function onSearchChanged()
  removeEvent(searchEvent)
  searchEvent = scheduleEvent(function()
    doSearch()
  end, 550)
end

function prevPage()
  if monsterPage > 1 then
    monsterPage = monsterPage - 1
    lastMonsterRequestKey = nil
    requestMonsters()
  end
end

function nextPage()
  if monsterPage < totalPages then
    monsterPage = monsterPage + 1
    lastMonsterRequestKey = nil
    requestMonsters()
  end
end

function startHunt()
  if #selectedMonsters < 1 then return end
  if not send('create', {
    monsters = selectedMonsters,
    difficulty = selectedDifficulty,
    respawn = selectedRespawn,
  }) then return end
  armSyncTimeout()
end

function joinHunt()
  if not send('join') then return end
  armSyncTimeout()
end

function leaveHunt()
  if not send('leave') then return end
  armSyncTimeout()
end

function openShop()
  local url = (lastState and lastState.passport and lastState.passport.shopUrl) or 'https://bestserverot.com.br/'
  g_platform.openUrl(url)
end

function openGuide()
  local url = (lastState and lastState.passport and lastState.passport.guideUrl) or 'https://bestserverot.com.br/?passport_hunt'
  g_platform.openUrl(url)
end

function refresh()
  if send('sync') then
    armSyncTimeout()
  end
end

local function onOpcode(protocol, opcode, buffer)
  if opcode ~= OPCODE then return end
  local ok, data = pcall(function() return json.decode(buffer) end)
  if not ok or type(data) ~= 'table' then
    return
  end

  if data.action == 'error' then
    if modules.game_textmessage then
      modules.game_textmessage.displayFailureMessage(data.message or 'Passport error')
    end
    send('sync')
    return
  end

  if data.state then
    applyState(data.state)
  end

  if data.action == 'monsters' or data.action == 'search' then
    monsterPage = data.page or monsterPage
    totalPages = data.totalPages or 1
    if data.action == 'monsters' and data.letters and not letterBarReady then
      fillLetterBar(data.letters)
    elseif data.action == 'monsters' and data.letters and window then
      -- keep bar, just refresh enabled states
      local bar = window:recursiveGetChildById('letterBar')
      if bar and bar:getChildCount() == 0 then
        fillLetterBar(data.letters)
      end
    end
    fillMonsters(data.items)
    updateSelectedSlots()
  end

  if (data.action == 'created' or data.action == 'joined' or data.action == 'left') and data.message then
    if modules.game_textmessage then
      modules.game_textmessage.displayStatusMessage(data.message)
    end
  end
end

local function online()
  if ProtocolGame and ProtocolGame.registerExtendedOpcode then
    pcall(function() ProtocolGame.unregisterExtendedOpcode(OPCODE) end)
    ProtocolGame.registerExtendedOpcode(OPCODE, onOpcode)
  end
end

local function offline()
  hide()
  lastState = nil
  selectedMonsters = {}
  monsterLooks = {}
  focusedMonsterRow = nil
  letterBarReady = false
  lastBenefitsKey = nil
  lastMonsterRequestKey = nil
  monsterLetter = '*'
  searchMode = false
  if ProtocolGame and ProtocolGame.unregisterExtendedOpcode then
    pcall(function() ProtocolGame.unregisterExtendedOpcode(OPCODE) end)
  end
end

function init()
  window = g_ui.displayUI('best_passport')
  if window then window:hide() end
  connect(g_game, { onGameStart = online, onGameEnd = offline })
  if g_game.isOnline() then online() end
end

function terminate()
  removeEvent(searchEvent)
  cancelSyncTimeout()
  offline()
  disconnect(g_game, { onGameStart = online, onGameEnd = offline })
  if window then
    window:destroy()
    window = nil
  end
end

function toggle()
  if not g_game.isOnline() then return end
  if window and window:isVisible() then hide() else show() end
end

function show()
  if not window or not g_game.isOnline() then return end
  window:show()
  window:raise()
  window:focus()
  local crest = window:getChildById('crest')
  if crest then crest:raise() end
  setTab(currentTab or 'benefits')
  refresh()
end

function hide()
  cancelSyncTimeout()
  if window then window:hide() end
end
