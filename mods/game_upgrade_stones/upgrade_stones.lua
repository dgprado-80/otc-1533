-- Upgrade Stones client UI (craft runes + spell damage upgrades)
-- Protocol: ExtendedOpcode ExtendedIds.UpgradeStones (221) + JSON
-- Docs: https://bestserverot.com.br/?upgrade_stones

local OPCODE = (ExtendedIds and ExtendedIds.UpgradeStones) or 221

local DEFAULT_RUNES = {
  { id = 'attack', label = 'Attack', itemId = 54267, desc = 'Melee weapons', card = 'cardAttack' },
  { id = 'armor', label = 'Armor', itemId = 54268, desc = 'Armor, legs, helmet, boots', card = 'cardArmor' },
  { id = 'defense', label = 'Defense', itemId = 54269, desc = 'Shields', card = 'cardDefense' },
  { id = 'wand', label = 'Wand / Rod', itemId = 54270, desc = 'Magic weapons', card = 'cardWand' },
}

local window = nil
local currentTab = 'runes'
local lastState = nil
local selectedSpell = nil
local syncTimeoutEvent = nil
local runeCardsReady = false
local lastSpellsKey = nil

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
      modules.game_textmessage.displayFailureMessage('Upgrade Stones: server did not answer opcode 221')
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
      modules.game_textmessage.displayFailureMessage('Upgrade Stones: no game protocol')
    end
    return false
  end
  local payload = extra or {}
  payload.action = action
  local ok, encoded = pcall(function() return json.encode(payload) end)
  if not ok or type(encoded) ~= 'string' then
    if modules.game_textmessage then
      modules.game_textmessage.displayFailureMessage('Upgrade Stones: failed to encode request')
    end
    return false
  end
  local sentOk, sentErr = pcall(function()
    protocol:sendExtendedOpcode(OPCODE, encoded)
  end)
  if not sentOk then
    if modules.game_textmessage then
      modules.game_textmessage.displayFailureMessage('Upgrade Stones send failed: ' .. tostring(sentErr))
    end
    if g_logger then
      g_logger.error('[UpgradeStones] sendExtendedOpcode failed: ' .. tostring(sentErr))
    end
    return false
  end
  return true
end

local function forceUiRefresh()
  -- Light no-op: avoid setWidth layout thrash on every opcode (FPS).
end

local function getCardItem(card)
  if not card then return nil end
  return card:recursiveGetChildById('item')
end

local function applySpellIcon(widget, spellName, words)
  if not widget then return end
  local spell = nil
  if Spells and Spells.getSpellByName and spellName then
    local ok, result = pcall(function() return Spells.getSpellByName(spellName) end)
    if ok then spell = result end
  end
  if not spell and Spells and Spells.getSpellByWords and words and words ~= '' then
    local ok, result = pcall(function() return Spells.getSpellByWords(words) end)
    if ok then spell = result end
  end
  if not spell or not spell.icon or not SpellIcons or not SpellIcons[spell.icon] then
    widget:setImageSource('/images/game/cyclopedia/ui/icon-magicalarchive-runeinfo')
    if widget.setImageClip then widget:setImageClip('0 0 32 32') end
    return false
  end
  local clientId = SpellIcons[spell.icon][1]
  local source = (SpelllistSettings and SpelllistSettings['Default'] and SpelllistSettings['Default'].iconsFolder)
    or '/images/game/spells/spell-icons-32x32'
  local clip = '0 0 32 32'
  if Spells and Spells.getImageClipNormal then
    local ok, result = pcall(function() return Spells.getImageClipNormal(clientId, 'Default') end)
    if ok and result then clip = result end
  end
  widget:setImageSource(source)
  if widget.setImageClip then widget:setImageClip(clip) end
  return true
end

local function setupRuneCards()
  if not window or runeCardsReady then return end
  for _, rune in ipairs(DEFAULT_RUNES) do
    local card = window:recursiveGetChildById(rune.card)
    if card then
      local title = card:getChildById('title')
      local desc = card:getChildById('desc')
      local item = getCardItem(card)
      local btn = card:getChildById('craftButton')
      if title then title:setText(rune.label) end
      if desc then desc:setText(rune.desc) end
      if item and item.setItemId then
        item:setItemId(rune.itemId)
      end
      if btn then
        btn:setText('Craft')
        btn.onClick = function()
          craftRune(rune.id)
        end
      end
    end
  end
  runeCardsReady = true
end

local function updateRuneCards(state)
  if not window or not state then return end
  setupRuneCards()

  local byId = {}
  for _, r in ipairs(state.runeTypes or {}) do
    byId[r.id] = r
  end

  local stones = state.stones or 0
  local cost = state.nextRuneCost or 10
  local canCraft = stones >= cost

  for _, rune in ipairs(DEFAULT_RUNES) do
    local card = window:recursiveGetChildById(rune.card)
    if card then
      local info = byId[rune.id]
      local item = getCardItem(card)
      local title = card:getChildById('title')
      local desc = card:getChildById('desc')
      local btn = card:getChildById('craftButton')
      if info then
        if title and info.label then title:setText(info.label) end
        if desc and info.desc then desc:setText(info.desc) end
        if item and info.itemId and item.setItemId then
          item:setItemId(info.itemId)
        end
      end
      if btn then
        btn:setEnabled(canCraft)
        if canCraft then
          btn:setText(string.format('Craft (%d)', cost))
        else
          btn:setText(string.format('Need %d', cost))
        end
      end
    end
  end
end

local function updateHeader(state)
  if not window or not state then return end

  local stonesValue = window:recursiveGetChildById('stonesValue')
  local runesCaption = window:recursiveGetChildById('runesCaption')
  local resonanceLabel = window:recursiveGetChildById('resonanceLabel')
  local dailyLabel = window:recursiveGetChildById('dailyLabel')
  local nextCostLabel = window:recursiveGetChildById('nextCostLabel')

  if stonesValue then
    stonesValue:setText(tostring(state.stones or 0))
  end
  if runesCaption then
    runesCaption:setText(string.format('Runes crafted: %d', state.runesCreated or 0))
  end
  if resonanceLabel then
    local unlocks = state.unlockSlots or 0
    local cap = state.spellCap or 25
    local hard = state.spellHardMax or 100
    resonanceLabel:setText(string.format('%d unlocks | Cap %d/%d', unlocks, cap, hard))
  end
  if dailyLabel then
    dailyLabel:setText(string.format('Daily spell upgrades: %d/%d', state.dailyUsed or 0, state.dailyLimit or 20))
  end
  if nextCostLabel then
    nextCostLabel:setText(string.format('Next rune: %d stones', state.nextRuneCost or 10))
  end

  updateRuneCards(state)
end

local function updateSpellDetails(spell)
  selectedSpell = spell
  if not window then return end
  local body = window:recursiveGetChildById('spellDetailsBody')
  local btn = window:recursiveGetChildById('upgradeSpellButton')
  local title = window:recursiveGetChildById('spellDetailsTitle')
  local bonusBig = window:recursiveGetChildById('spellBonusBig')
  local detailIcon = window:recursiveGetChildById('spellDetailIcon')

  if not spell then
    if title then title:setText('Spell Details') end
    if bonusBig then bonusBig:setText('+0%') end
    if body then body:setText('Select a spell to upgrade damage (+1% per level).') end
    if detailIcon then
      detailIcon:setImageSource('/images/game/cyclopedia/ui/icon-magicalarchive-runeinfo')
      if detailIcon.setImageClip then detailIcon:setImageClip('0 0 32 32') end
    end
    if btn then
      btn:setEnabled(false)
      btn:setText('Upgrade Spell')
    end
    return
  end

  if title then
    title:setText(spell.name or 'Spell')
  end
  applySpellIcon(detailIcon, spell.name, spell.words)
  if bonusBig then
    if spell.unlocked then
      bonusBig:setText(string.format('+%d%%', spell.bonusPercent or 0))
      bonusBig:setColor('#7dff9fff')
    else
      bonusBig:setText('LOCKED')
      bonusBig:setColor('#c08080ff')
    end
  end

  local lines = {}
  lines[#lines + 1] = string.format('Words: %s', spell.words or '-')
  lines[#lines + 1] = string.format('Required level: %d', spell.levelReq or 0)
  if not spell.unlocked then
    local nextAt = lastState and lastState.nextUnlockAt
    if nextAt then
      lines[#lines + 1] = string.format('Craft more runes to unlock (next unlock at %d total runes).', nextAt)
    else
      lines[#lines + 1] = 'Craft more runes in the Craft Runes tab to unlock this spell.'
    end
  else
    lines[#lines + 1] = string.format('Level: %d / %d', spell.upgradeLevel or 0, spell.maxLevel or 0)
    lines[#lines + 1] = string.format('Next cost: %d stones', spell.nextCost or 0)
    if lastState then
      lines[#lines + 1] = string.format('Daily upgrades left: %d', lastState.dailyLeft or 0)
    end
  end
  if body then
    body:setText(table.concat(lines, '\n'))
  end

  if btn then
    local can = spell.unlocked and spell.canUpgrade
    btn:setEnabled(can and true or false)
    if not spell.unlocked then
      btn:setText('Locked')
    elseif (spell.upgradeLevel or 0) >= (spell.maxLevel or 0) then
      btn:setText('Maxed')
    else
      btn:setText(string.format('Upgrade (%d stones)', spell.nextCost or 0))
    end
  end
end

local function fillSpells(spells)
  if not window then return end
  local list = window:recursiveGetChildById('spellsList')
  if not list then return end

  local keyParts = {}
  for _, spell in ipairs(spells or {}) do
    keyParts[#keyParts + 1] = string.format('%s:%s:%s:%s',
      tostring(spell.name or ''),
      tostring(spell.upgradeLevel or 0),
      spell.unlocked and '1' or '0',
      tostring(spell.bonusPercent or 0))
  end
  local key = table.concat(keyParts, '|')
  local expectedCount = (spells and #spells > 0) and #spells or 1
  if key == lastSpellsKey and list:getChildCount() == expectedCount then
    return
  end
  lastSpellsKey = key

  local prevName = selectedSpell and selectedSpell.name or nil
  list:destroyChildren()
  selectedSpell = nil

  if not spells or #spells == 0 then
    local row = g_ui.createWidget('UpgradeSpellRow', list)
    local nameLabel = row:getChildById('nameLabel')
    if nameLabel then
      nameLabel:setText('No spells for this vocation')
      nameLabel:setColor('#a0a0a0ff')
    end
    row:setFocusable(false)
    updateSpellDetails(nil)
    return
  end

  local focusChild = nil
  for _, spell in ipairs(spells) do
    local row = g_ui.createWidget('UpgradeSpellRow', list)
    row.spellData = spell
    local icon = row:getChildById('icon')
    local nameLabel = row:getChildById('nameLabel')
    applySpellIcon(icon, spell.name, spell.words)

    local status
    if not spell.unlocked then
      status = 'LOCKED'
      if nameLabel then nameLabel:setColor('#a09090ff') end
      if icon then pcall(function() icon:setOpacity(0.45) end) end
    else
      status = string.format('+%d%%', spell.bonusPercent or 0)
      if nameLabel then
        if spell.canUpgrade then
          nameLabel:setColor('#e8e0c8ff')
        else
          nameLabel:setColor('#c0c0c0ff')
        end
      end
      if icon then pcall(function() icon:setOpacity(1.0) end) end
    end
    if nameLabel then
      nameLabel:setText(string.format('%s   %s   %d/%d', spell.name or '?', status, spell.upgradeLevel or 0, spell.maxLevel or 0))
    end
    if prevName and spell.name == prevName then
      focusChild = row
      selectedSpell = spell
    end
  end

  if focusChild then
    list:focusChild(focusChild)
    updateSpellDetails(selectedSpell)
  else
    updateSpellDetails(nil)
  end
end

local function applyState(state)
  if not state then return end
  cancelSyncTimeout()
  lastState = state
  updateHeader(state)
  fillSpells(state.spells)
  forceUiRefresh()
end

function setTab(tab)
  currentTab = tab or 'runes'
  if not window then return end
  local runesPanel = window:recursiveGetChildById('runesPanel')
  local spellsPanel = window:recursiveGetChildById('spellsPanel')
  local tabRunes = window:recursiveGetChildById('tabRunes')
  local tabSpells = window:recursiveGetChildById('tabSpells')

  local isRunes = currentTab == 'runes'
  if runesPanel then runesPanel:setVisible(isRunes) end
  if spellsPanel then spellsPanel:setVisible(not isRunes) end
  if tabRunes then tabRunes:setEnabled(not isRunes) end
  if tabSpells then tabSpells:setEnabled(isRunes) end
end

function onSpellSelected()
  if not window then return end
  local list = window:recursiveGetChildById('spellsList')
  if not list then return end
  local focused = list:getFocusedChild()
  if focused and focused.spellData then
    updateSpellDetails(focused.spellData)
  end
end

function craftRune(runeType)
  if not send('craftRune', { runeType = runeType }) then return end
  armSyncTimeout()
end

function upgradeSelectedSpell()
  if not selectedSpell or not selectedSpell.name then return end
  if not send('upgradeSpell', { spellName = selectedSpell.name }) then return end
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
      g_logger.error('[UpgradeStones] bad opcode payload: ' .. tostring(data))
    end
    return
  end

  if data.action == 'error' then
    if modules.game_textmessage then
      modules.game_textmessage.displayFailureMessage(data.message or 'Upgrade Stones error')
    end
    send('sync')
    return
  end

  if data.state then
    applyState(data.state)
  end

  if data.action == 'crafted' or data.action == 'upgraded' then
    if data.message and modules.game_textmessage then
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
  lastSpellsKey = nil
  selectedSpell = nil
  if ProtocolGame and ProtocolGame.unregisterExtendedOpcode then
    pcall(function() ProtocolGame.unregisterExtendedOpcode(OPCODE) end)
  end
end

function init()
  window = g_ui.displayUI('upgrade_stones')
  if window then
    window:hide()
    runeCardsReady = false
    setupRuneCards()
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
  if crest then
    crest:raise()
  end
  setTab(currentTab or 'runes')
  refresh()
end

function hide()
  cancelSyncTimeout()
  if window then
    window:hide()
  end
end
