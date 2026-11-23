-- Skills & Perks client UI (Exalted Core permanent upgrades)
-- Protocol: ExtendedOpcode ExtendedIds.SkillPerks (222) + JSON
-- Docs: https://bestserverot.com.br/?perk_system

local OPCODE = (ExtendedIds and ExtendedIds.SkillPerks) or 222
local ICON_DIR = '/images/game/skill_perks/'

local window = nil
local currentTab = 'core'
local lastState = nil
local selectedPerk = nil
local syncTimeoutEvent = nil
local lastPerksKey = nil

-- Custom stylized icons. Falls back to server itemId sprite when missing.
local PERK_ICONS = {
  potion = 'potion',
  regen = 'regen',
  money = 'money',
  damage = 'damage',
  health = 'health',
  mana = 'mana',
  resPhysical = 'resPhysical',
  resFire = 'resFire',
  resEnergy = 'resEnergy',
  resIce = 'resIce',
  resEarth = 'resEarth',
  resHoly = 'resHoly',
  resDeath = 'resDeath',
  resLifedrain = 'resLifedrain',
  resManadrain = 'resManadrain',
  resDrown = 'resDrown',
}

-- Every artwork above ships with its own ornate frame (52x52), so the slot
-- background is dropped and the art is drawn 1:1 to stay sharp.
local FRAMED_ICON_SIZE = 52

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
      modules.game_textmessage.displayFailureMessage('Skills & Perks: server did not answer opcode 222')
    end
  end, 2500)
end

local function send(action, extra)
  if not g_game or not g_game.isOnline or not g_game.isOnline() then
    return false
  end
  local protocol = g_game.getProtocolGame and g_game.getProtocolGame() or nil
  if not protocol or not protocol.sendExtendedOpcode then
    if modules.game_textmessage then
      modules.game_textmessage.displayFailureMessage('Skills & Perks: no game protocol')
    end
    return false
  end
  local payload = extra or {}
  payload.action = action
  local ok, encoded = pcall(function() return json.encode(payload) end)
  if not ok or type(encoded) ~= 'string' then
    if modules.game_textmessage then
      modules.game_textmessage.displayFailureMessage('Skills & Perks: failed to encode request')
    end
    return false
  end
  local sentOk, sentErr = pcall(function()
    protocol:sendExtendedOpcode(OPCODE, encoded)
  end)
  if not sentOk then
    if modules.game_textmessage then
      modules.game_textmessage.displayFailureMessage('Skills & Perks send failed: ' .. tostring(sentErr))
    end
    if g_logger then
      g_logger.error('[SkillPerks] sendExtendedOpcode failed: ' .. tostring(sentErr))
    end
    return false
  end
  return true
end

local function forceUiRefresh()
  -- Light no-op: avoid setWidth layout thrash on every opcode (FPS).
end

local function applyIconSlotStyle(widget, icon, framed)
  if not widget then return end
  if widget.setImageSource then
    widget:setImageSource(framed and '' or '/images/ui/item')
  end
  if not icon or not icon.setWidth then return end
  local slotSize = widget.getWidth and widget:getWidth() or 0
  if slotSize <= 0 then slotSize = FRAMED_ICON_SIZE end
  local size = framed and slotSize or math.max(16, slotSize - 10)
  icon:setWidth(size)
  icon:setHeight(size)
  if icon.setImageSmooth then
    icon:setImageSmooth(not framed)
  end
end

local function setItem(widget, itemId)
  if not widget then return end
  local item = widget.getChildById and widget:getChildById('item') or widget
  local icon = widget.getChildById and widget:getChildById('icon') or nil
  applyIconSlotStyle(widget, icon, false)
  if icon and icon.setVisible then
    icon:setVisible(false)
  end
  if item and item.setItemId then
    if item.setVisible then item:setVisible(true) end
    item:setItemId(itemId or 37110)
  end
end

local function setPerkIcon(widget, perk)
  if not widget then return end
  local item = widget.getChildById and widget:getChildById('item') or nil
  local icon = widget.getChildById and widget:getChildById('icon') or nil
  local perkId = perk and perk.id or nil
  local iconName = perkId and PERK_ICONS[perkId] or nil

  if iconName and icon and icon.setImageSource then
    applyIconSlotStyle(widget, icon, true)
    icon:setImageSource(ICON_DIR .. iconName)
    icon:setVisible(true)
    if item then
      item:setVisible(false)
      if item.setItemId then item:setItemId(0) end
    end
    return
  end

  applyIconSlotStyle(widget, icon, false)
  if icon then icon:setVisible(false) end
  if item and item.setItemId then
    item:setVisible(true)
    item:setItemId((perk and perk.itemId) or 37110)
  end
end

local function updateHeader(state)
  if not window or not state then return end
  local coresValue = window:recursiveGetChildById('coresValue')
  local costLabel = window:recursiveGetChildById('costLabel')
  local totalLabel = window:recursiveGetChildById('totalLabel')
  local coreSlot = window:recursiveGetChildById('coreSlot')

  if coresValue then
    coresValue:setText(tostring(state.cores or 0))
  end
  if costLabel then
    costLabel:setText(string.format('Cost: %d / level', state.upgradeCost or 10))
  end
  if totalLabel then
    totalLabel:setText(string.format('Total levels: %d', state.totalLevels or 0))
  end
  setItem(coreSlot, state.coreItemId or 37110)
end

local function updateDetails(perk)
  selectedPerk = perk
  if not window then return end

  local title = window:recursiveGetChildById('detailsTitle')
  local body = window:recursiveGetChildById('detailsBody')
  local bonusBig = window:recursiveGetChildById('bonusBig')
  local levelBar = window:recursiveGetChildById('levelBar')
  local upgradeButton = window:recursiveGetChildById('upgradeButton')
  local detailSlot = window:recursiveGetChildById('detailSlot')

  if not perk then
    if title then title:setText('Select a perk') end
    if bonusBig then bonusBig:setText('+0') end
    if body then body:setText('Select a perk to view bonus and upgrade with Exalted Cores.') end
    if levelBar then
      levelBar:setPercent(0)
      levelBar:setText('')
    end
    if upgradeButton then
      upgradeButton:setEnabled(false)
      upgradeButton:setText('Upgrade')
    end
    setPerkIcon(detailSlot, nil)
    return
  end

  if title then title:setText(perk.name or 'Perk') end
  setPerkIcon(detailSlot, perk)

  if bonusBig then
    bonusBig:setText(perk.bonus or '+0')
    if (perk.level or 0) > 0 then
      bonusBig:setColor('#7dff9fff')
    else
      bonusBig:setColor('#ffd76aff')
    end
  end

  local maxLevel = perk.maxLevel or 50
  local level = perk.level or 0
  local percent = 0
  if maxLevel > 0 then
    percent = math.min(100, math.floor((level / maxLevel) * 100))
  end
  if levelBar then
    if levelBar.setOn then levelBar:setOn(true) end
    levelBar:setPercent(percent)
    levelBar:setText(string.format('%d / %d', level, maxLevel))
  end

  local lines = {
    string.format('Level: %d / %d', level, maxLevel),
    string.format('Current bonus: %s', perk.bonus or '+0'),
    string.format('Next level: %s', perk.nextBonus or '-'),
  }
  if lastState then
    lines[#lines + 1] = string.format('Upgrade cost: %d Exalted Cores', lastState.upgradeCost or 10)
    lines[#lines + 1] = string.format('You have: %d cores', lastState.cores or 0)
  end
  if perk.kind == 'regen' then
    lines[#lines + 1] = 'Regen applies as permanent HP/MP tick gain.'
  elseif perk.kind == 'potion' then
    lines[#lines + 1] = 'Improves heal/mana restored by potions.'
  elseif perk.kind == 'money' then
    lines[#lines + 1] = 'Increases gold/platinum/crystal drop quantity only.'
  elseif perk.kind == 'absorb' then
    lines[#lines + 1] = 'Permanent elemental absorption bonus.'
  end
  if body then body:setText(table.concat(lines, '\n')) end

  if upgradeButton then
    local can = perk.canUpgrade
    upgradeButton:setEnabled(can and true or false)
    if level >= maxLevel then
      upgradeButton:setText('Maxed')
    elseif lastState and (lastState.cores or 0) < (lastState.upgradeCost or 10) then
      upgradeButton:setText(string.format('Need %d cores', lastState.upgradeCost or 10))
    else
      upgradeButton:setText(string.format('Upgrade (%d cores)', lastState and lastState.upgradeCost or 10))
    end
  end
end

local function fillPerks()
  if not window or not lastState then return end
  local list = window:recursiveGetChildById('perksList')
  local listTitle = window:recursiveGetChildById('listTitle')
  if not list then return end

  local filtered = {}
  for _, perk in ipairs(lastState.perks or {}) do
    local cat = perk.category or 'core'
    if currentTab == 'resist' then
      if cat == 'resist' then filtered[#filtered + 1] = perk end
    else
      if cat ~= 'resist' then filtered[#filtered + 1] = perk end
    end
  end

  local keyParts = { currentTab or 'core' }
  for _, perk in ipairs(filtered) do
    keyParts[#keyParts + 1] = string.format('%s:%s:%s',
      tostring(perk.id or ''),
      tostring(perk.level or 0),
      tostring(perk.maxLevel or 0))
  end
  local key = table.concat(keyParts, '|')
  local expectedCount = (#filtered > 0) and #filtered or 1
  if key == lastPerksKey and list:getChildCount() == expectedCount then
    return
  end
  lastPerksKey = key

  local prevId = selectedPerk and selectedPerk.id or nil
  list:destroyChildren()
  selectedPerk = nil

  if listTitle then
    if currentTab == 'resist' then
      listTitle:setText('Resistances')
    else
      listTitle:setText('Core Perks')
    end
  end

  if #filtered == 0 then
    local row = g_ui.createWidget('SkillPerkRow', list)
    local nameLabel = row:getChildById('nameLabel')
    local bonusLabel = row:getChildById('bonusLabel')
    local levelLabel = row:getChildById('levelLabel')
    local levelBar = row:getChildById('rowLevelBar')
    if nameLabel then nameLabel:setText('No perks in this category') end
    if bonusLabel then bonusLabel:setText('') end
    if levelLabel then levelLabel:setText('') end
    if levelBar then levelBar:setVisible(false) end
    row:setFocusable(false)
    updateDetails(nil)
    return
  end

  local focusChild = nil
  for _, perk in ipairs(filtered) do
    local row = g_ui.createWidget('SkillPerkRow', list)
    row.perkData = perk
    local nameLabel = row:getChildById('nameLabel')
    local bonusLabel = row:getChildById('bonusLabel')
    local levelLabel = row:getChildById('levelLabel')
    local levelBar = row:getChildById('rowLevelBar')
    local iconSlot = row:getChildById('iconSlot')
    setPerkIcon(iconSlot, perk)
    if nameLabel then
      nameLabel:setText(perk.name or '?')
      if (perk.level or 0) > 0 then
        nameLabel:setColor('#ffd76aff')
      else
        nameLabel:setColor('#e8e0c8ff')
      end
    end
    local level = tonumber(perk.level) or 0
    local maxLevel = tonumber(perk.maxLevel) or 50
    local percent = maxLevel > 0 and math.min(100, math.floor((level / maxLevel) * 100)) or 0
    if bonusLabel then
      bonusLabel:setText(perk.bonus or '+0')
      if perk.canUpgrade then
        bonusLabel:setColor('#7dff9fff')
      else
        bonusLabel:setColor('#c8c8c8ff')
      end
    end
    if levelLabel then
      levelLabel:setText(string.format('%d / %d', level, maxLevel))
      levelLabel:setColor(level >= maxLevel and '#7dff9fff' or '#9fd4ffff')
    end
    if levelBar then
      levelBar:setPercent(percent)
      levelBar:setVisible(true)
    end
    row:setTooltip(string.format('%s\n%s\nLevel %d of %d', perk.name or 'Perk', perk.bonus or '+0', level, maxLevel))
    if prevId and perk.id == prevId then
      focusChild = row
      selectedPerk = perk
    end
  end

  if focusChild then
    list:focusChild(focusChild)
    updateDetails(selectedPerk)
  else
    updateDetails(nil)
  end
end

local function applyState(state)
  if not state then return end
  cancelSyncTimeout()
  lastState = state
  updateHeader(state)
  fillPerks()
  forceUiRefresh()
end

function setTab(tab)
  currentTab = tab or 'core'
  if not window then return end
  local tabCore = window:recursiveGetChildById('tabCore')
  local tabResist = window:recursiveGetChildById('tabResist')
  local isCore = currentTab == 'core'
  if tabCore then tabCore:setEnabled(not isCore) end
  if tabResist then tabResist:setEnabled(isCore) end
  lastPerksKey = nil
  fillPerks()
end

function onPerkSelected()
  if not window then return end
  local list = window:recursiveGetChildById('perksList')
  if not list then return end
  local focused = list:getFocusedChild()
  if focused and focused.perkData then
    updateDetails(focused.perkData)
  end
end

function upgradeSelected()
  if not selectedPerk or not selectedPerk.id then return end
  if not send('upgrade', { perkId = selectedPerk.id }) then return end
  armSyncTimeout()
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
    if g_logger then
      g_logger.error('[SkillPerks] bad opcode payload: ' .. tostring(data))
    end
    return
  end

  if data.action == 'error' then
    if modules.game_textmessage then
      modules.game_textmessage.displayFailureMessage(data.message or 'Skills & Perks error')
    end
    send('sync')
    return
  end

  if data.state then
    applyState(data.state)
  end

  if data.action == 'upgraded' and data.message and modules.game_textmessage then
    modules.game_textmessage.displayStatusMessage(data.message)
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
  lastPerksKey = nil
  selectedPerk = nil
  selectedPerk = nil
  if ProtocolGame and ProtocolGame.unregisterExtendedOpcode then
    pcall(function() ProtocolGame.unregisterExtendedOpcode(OPCODE) end)
  end
end

function init()
  window = g_ui.displayUI('skill_perks')
  if window then
    window:hide()
  end
  connect(g_game, {
    onGameStart = online,
    onGameEnd = offline
  })
  if g_game.isOnline() then
    online()
  end
end

function terminate()
  cancelSyncTimeout()
  offline()
  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline
  })
  if window then
    window:destroy()
    window = nil
  end
end

function toggle()
  if not g_game.isOnline() then return end
  if window and window:isVisible() then
    hide()
  else
    show()
  end
end

function show()
  if not window then return end
  if not g_game.isOnline() then return end
  window:show()
  window:raise()
  window:focus()
  local crest = window:getChildById('crest')
  if crest then crest:raise() end
  setTab(currentTab or 'core')
  refresh()
end

function hide()
  cancelSyncTimeout()
  if window then
    window:hide()
  end
end
