-- Level Rewards client UI
-- Protocol: ExtendedOpcode ExtendedIds.LevelReward (224) + JSON
-- Docs: https://bestserverot.com.br/?level_reward

local OPCODE = (ExtendedIds and ExtendedIds.LevelReward) or 224

local window = nil
local lastSync = nil
local selectedLevel = nil
local selectedChoiceId = nil
local opcodeRegistered = false
local statusColors = {
  available = '#7dff9aff',
  claimed = '#9fd4ffff',
  locked = '#c0a060ff',
  unavailable = '#889088ff',
}

local function send(action, extra)
  if not g_game or not g_game.isOnline or not g_game.isOnline() then
    return false
  end
  local protocol = g_game.getProtocolGame and g_game.getProtocolGame() or nil
  if not protocol or not protocol.sendExtendedOpcode then
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

local function statusText(status)
  if status == 'available' then return tr('Ready') end
  if status == 'claimed' then return tr('Claimed') end
  if status == 'locked' then return tr('Locked') end
  if status == 'unavailable' then return tr('N/A') end
  return tostring(status or '')
end

local function findReward(level)
  if not lastSync or not lastSync.rewards then return nil end
  for _, reward in ipairs(lastSync.rewards) do
    if reward.level == level then return reward end
  end
  return nil
end

local function clearPanelChildren(panel)
  if not panel then return end
  local children = panel:getChildren()
  for i = #children, 1, -1 do
    children[i]:destroy()
  end
end

local function addItemSlot(row, itemData, clickable, choiceIndex)
  if not row or not itemData then return end
  local slot = g_ui.createWidget('LevelRewardItemSlot', row)
  if not slot then return end
  local item = slot:recursiveGetChildById('item')
  local nameLabel = slot:recursiveGetChildById('nameLabel')
  if item and itemData.id then
    item:setItemId(itemData.id)
    if itemData.count and itemData.count > 1 and item.setItemCount then
      item:setItemCount(itemData.count)
    end
  end
  if nameLabel then
    nameLabel:setText(itemData.name or '')
  end
end

local function addChoiceRow(list, itemData, choiceIndex, selectable)
  if not list or not itemData then return end
  local row = g_ui.createWidget('LevelRewardChoiceRow', list)
  if not row then return end
  row.choiceIndex = choiceIndex
  local item = row:recursiveGetChildById('item')
  local nameLabel = row:recursiveGetChildById('nameLabel')
  if item and itemData.id then
    item:setItemId(itemData.id)
  end
  if nameLabel then
    nameLabel:setText(itemData.name or '')
  end
  if selectable then
    row.onClick = function(widget)
      selectedChoiceId = widget.choiceIndex
      list:focusChild(widget)
    end
  end
  return row
end

local function updateDetail()
  if not window then return end
  local detail = window:recursiveGetChildById('detailPanel')
  if not detail then return end

  local emptyDetail = detail:recursiveGetChildById('emptyDetail')
  local detailLevel = detail:recursiveGetChildById('detailLevel')
  local detailStatus = detail:recursiveGetChildById('detailStatus')
  local detailTitle = detail:recursiveGetChildById('detailTitle')
  local detailBlurb = detail:recursiveGetChildById('detailBlurb')
  local itemsHeadline = detail:recursiveGetChildById('itemsHeadline')
  local itemsRow = detail:recursiveGetChildById('itemsRow')
  local choiceHeadline = detail:recursiveGetChildById('choiceHeadline')
  local choiceRow = detail:recursiveGetChildById('choiceRow')
  local choiceScroll = detail:recursiveGetChildById('choiceScroll')
  local claimButton = detail:recursiveGetChildById('claimButton')

  local reward = findReward(selectedLevel)
  if not reward then
    if emptyDetail then emptyDetail:setVisible(true) end
    if claimButton then claimButton:setEnabled(false) end
    clearPanelChildren(itemsRow)
    clearPanelChildren(choiceRow)
    if choiceHeadline then choiceHeadline:setVisible(false) end
    if choiceRow then choiceRow:setVisible(false) end
    if choiceScroll then choiceScroll:setVisible(false) end
    if itemsRow then itemsRow:setHeight(0) end
    if itemsHeadline then itemsHeadline:setVisible(false) end
    return
  end

  if emptyDetail then emptyDetail:setVisible(false) end
  if detailLevel then detailLevel:setText(string.format('Level %d', reward.level)) end
  if detailStatus then
    detailStatus:setText(statusText(reward.status))
    detailStatus:setColor(statusColors[reward.status] or '#ffffff')
  end
  if detailTitle then detailTitle:setText(reward.title or '') end
  if detailBlurb then detailBlurb:setText(reward.blurb or '') end

  clearPanelChildren(itemsRow)
  local fixed = reward.items or {}
  local hasFixed = #fixed > 0
  if itemsHeadline then
    itemsHeadline:setVisible(hasFixed)
    itemsHeadline:setText(tr('Your rewards'))
  end
  if itemsRow then
    itemsRow:setHeight(hasFixed and 114 or 0)
    itemsRow:setVisible(hasFixed)
  end
  for _, itemData in ipairs(fixed) do
    addItemSlot(itemsRow, itemData)
  end

  local choices = reward.choice or {}
  local showChoice = reward.needsChoice and #choices > 0
  local canSelect = reward.status == 'available'
  if choiceHeadline then
    choiceHeadline:setVisible(showChoice)
    if showChoice then
      choiceHeadline:setText(canSelect and tr('Choose one weapon') or tr('Weapon options'))
    end
  end
  if choiceRow then
    choiceRow:setVisible(showChoice)
    if choiceScroll then choiceScroll:setVisible(showChoice) end
    clearPanelChildren(choiceRow)
    if showChoice then
      selectedChoiceId = canSelect and (selectedChoiceId or 1) or nil
      local focusRow = nil
      for i, itemData in ipairs(choices) do
        local row = addChoiceRow(choiceRow, itemData, i, canSelect)
        if canSelect and i == selectedChoiceId then
          focusRow = row
        end
      end
      if focusRow then
        choiceRow:focusChild(focusRow)
      end
    end
  end

  if claimButton then
    local canClaim = reward.status == 'available'
    claimButton:setEnabled(canClaim)
    if reward.status == 'claimed' then
      claimButton:setText(tr('Already Claimed'))
    elseif reward.status == 'locked' then
      claimButton:setText(string.format('Reach Level %d', reward.level))
    elseif reward.status == 'unavailable' then
      claimButton:setText(tr('Not for vocation'))
    else
      claimButton:setText(tr('Claim Reward'))
    end
  end
end

local function rebuildList()
  if not window or not lastSync then return end
  local list = window:recursiveGetChildById('rewardsList')
  if not list then return end

  local previous = selectedLevel
  list:destroyChildren()

  local firstAvailable = nil
  local firstAny = nil
  for _, reward in ipairs(lastSync.rewards or {}) do
    if reward.status ~= 'unavailable' then
      local row = g_ui.createWidget('LevelRewardRow', list)
      if row then
        row.rewardLevel = reward.level
        local badge = row:recursiveGetChildById('levelBadge')
        local title = row:recursiveGetChildById('titleLabel')
        local status = row:recursiveGetChildById('statusLabel')
        if badge then badge:setText(tostring(reward.level)) end
        if title then title:setText(reward.title or ('Level ' .. reward.level)) end
        if status then
          status:setText(statusText(reward.status))
          status:setColor(statusColors[reward.status] or '#ffffff')
        end
        row.onClick = function(widget)
          selectedLevel = widget.rewardLevel
          selectedChoiceId = nil
          list:focusChild(widget)
          updateDetail()
        end
        if not firstAny then firstAny = reward.level end
        if not firstAvailable and reward.status == 'available' then
          firstAvailable = reward.level
        end
      end
    end
  end

  selectedLevel = previous or firstAvailable or firstAny
  if selectedLevel then
    for _, child in ipairs(list:getChildren()) do
      if child.rewardLevel == selectedLevel then
        list:focusChild(child)
        break
      end
    end
  end
  updateDetail()
end

local function applySync(data)
  lastSync = data
  if not window then return end

  local pending = window:recursiveGetChildById('pendingLabel')
  if pending then
    pending:setText(tr('Pending: %d', data.pendingCount or 0))
    if (data.pendingCount or 0) > 0 then
      pending:setColor('#7dff9aff')
    else
      pending:setColor('#9fd4ffff')
    end
  end

  local notice = window:recursiveGetChildById('noticeLabel')
  if notice and data.notice then
    notice:setText(data.notice)
  end

  local headerSub = window:recursiveGetChildById('headerSub')
  if headerSub then
    headerSub:setText(string.format('Your level: %d - rewards for your vocation only', data.playerLevel or 0))
  end

  rebuildList()
end

local function showNotifyBanner(data)
  local title = data.title or tr('Level Reward Unlocked!')
  local desc = data.message or tr('Open Level Rewards to claim your prize.')
  local icon = '/game_notifications/assets/images/nodo/icon-infobanner-levelup'
  if modules.game_notifications and modules.game_notifications.infobanner and modules.game_notifications.infobanner.show then
    modules.game_notifications.infobanner.show(title, desc, icon)
  elseif modules.game_textmessage then
    modules.game_textmessage.displayStatusMessage(title .. ' ' .. desc)
  end
end

local function onOpcode(protocol, opcode, buffer)
  if opcode ~= OPCODE then return end
  local ok, data = pcall(function() return json.decode(buffer) end)
  if not ok or type(data) ~= 'table' then return end

  local action = data.action
  if action == 'sync' or not action then
    applySync(data)
    if data.open then
      show()
    end
  elseif action == 'notify' then
    showNotifyBanner(data)
  elseif action == 'claimed' then
    if modules.game_textmessage then
      modules.game_textmessage.displayStatusMessage(data.message or tr('Reward claimed!'))
    end
  elseif action == 'error' then
    if modules.game_textmessage then
      modules.game_textmessage.displayFailureMessage(data.message or tr('Level Rewards error'))
    end
  end
end

local function online()
  if opcodeRegistered or not ProtocolGame or not ProtocolGame.registerExtendedOpcode then
    return
  end
  -- Clear stale registration (e.g. hot-reload) without throwing.
  pcall(ProtocolGame.unregisterExtendedOpcode, OPCODE)
  ProtocolGame.registerExtendedOpcode(OPCODE, onOpcode)
  opcodeRegistered = true
end

local function offline()
  hide()
  if opcodeRegistered and ProtocolGame and ProtocolGame.unregisterExtendedOpcode then
    pcall(ProtocolGame.unregisterExtendedOpcode, OPCODE)
    opcodeRegistered = false
  end
  lastSync = nil
  selectedLevel = nil
  selectedChoiceId = nil
end

function init()
  window = g_ui.displayUI('level_reward')
  if window then
    window:hide()
  end
  connect(g_game, { onGameStart = online, onGameEnd = offline })
  if g_game.isOnline() then
    online()
  end
end

function terminate()
  disconnect(g_game, { onGameStart = online, onGameEnd = offline })
  offline()
  if window then
    window:destroy()
    window = nil
  end
end

function show()
  if not window then return end
  window:show()
  window:raise()
  window:focus()
  send('sync')
end

function hide()
  if window then
    window:hide()
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

function refresh()
  send('sync')
end

function claimSelected()
  if not selectedLevel then return end
  local reward = findReward(selectedLevel)
  if not reward or reward.status ~= 'available' then return end

  local payload = { level = selectedLevel }
  if reward.needsChoice then
    if not selectedChoiceId then
      if modules.game_textmessage then
        modules.game_textmessage.displayFailureMessage(tr('Select a weapon first.'))
      end
      return
    end
    payload.choiceId = selectedChoiceId
  end
  send('claim', payload)
end
