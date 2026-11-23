-- Best Tasks client UI (rooms, accept/claim/cancel, bonuses, token outfit shop)
-- Protocol: ExtendedOpcode ExtendedIds.BestTasks (220) + JSON

local OPCODE = (ExtendedIds and ExtendedIds.BestTasks) or 220

local window = nil
local currentTab = 'rooms'
local currentGroup = nil
local selectedTask = nil
local lastState = nil
local lastShop = nil
local lastBonuses = nil
local respecConfirmWindow = nil
local abandonConfirmWindow = nil
local searchEvent = nil
local syncTimeoutEvent = nil
local waitingLabelShown = false
local lastSearchQuery = nil

local function cancelSyncTimeout()
  removeEvent(syncTimeoutEvent)
  syncTimeoutEvent = nil
end

local function armSyncTimeout()
  cancelSyncTimeout()
  syncTimeoutEvent = scheduleEvent(function()
    syncTimeoutEvent = nil
    if not window or not window:isVisible() then return end
    if not waitingLabelShown then return end
    local list = window:recursiveGetChildById('roomsList')
    if list then
      list:destroyChildren()
      local label = g_ui.createWidget('BestTaskListLabel', list)
      label:setText('No response from server (reload Best Task scripts)')
      label:setColor('#a0a0a0ff')
      label:setFocusable(false)
    end
    if modules.game_textmessage then
      modules.game_textmessage.displayFailureMessage('Best Tasks: server did not answer opcode 220')
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
      modules.game_textmessage.displayFailureMessage('Best Tasks: no game protocol')
    end
    return false
  end
  local payload = extra or {}
  payload.action = action
  local ok, encoded = pcall(function() return json.encode(payload) end)
  if not ok or type(encoded) ~= 'string' then
    if modules.game_textmessage then
      modules.game_textmessage.displayFailureMessage('Best Tasks: failed to encode request')
    end
    return false
  end
  local sentOk, sentErr = pcall(function()
    protocol:sendExtendedOpcode(OPCODE, encoded)
  end)
  if not sentOk then
    if modules.game_textmessage then
      modules.game_textmessage.displayFailureMessage('Best Tasks send failed: ' .. tostring(sentErr))
    end
    if g_logger then
      g_logger.error('[BestTasks] sendExtendedOpcode failed: ' .. tostring(sentErr))
    end
    return false
  end
  return true
end

local function formatRewards(r)
  if not r then return '-' end
  local parts = {}
  if (r.exp or 0) > 0 then parts[#parts + 1] = string.format('%d exp', r.exp) end
  if (r.gold or 0) > 0 then parts[#parts + 1] = string.format('%d gold', r.gold) end
  if (r.taskCoins or 0) > 0 then parts[#parts + 1] = string.format('%d tokens', r.taskCoins) end
  if #parts == 0 then return 'none' end
  return table.concat(parts, ', ')
end

local function updateHeaderActions(state)
  if not window then return end
  local cancelBtn = window:recursiveGetChildById('headerCancelButton')
  local claimBtn = window:recursiveGetChildById('headerClaimButton')
  local hasActive = state and (state.activeTaskId or 0) > 0
  local pending = state and state.pendingReward
  if cancelBtn then
    cancelBtn:setVisible(hasActive and not pending)
    cancelBtn:setEnabled(hasActive and not pending)
  end
  if claimBtn then
    claimBtn:setVisible(hasActive and pending)
    claimBtn:setEnabled(hasActive and pending)
  end
end

local function updateHeader(state)
  if not window or not state then return end
  local activeTitle = window:recursiveGetChildById('activeTitle')
  local activeProgress = window:recursiveGetChildById('activeProgress')
  local activeProgressBar = window:recursiveGetChildById('activeProgressBar')
  local pointsLabel = window:recursiveGetChildById('pointsLabel')
  local tokensLabel = window:recursiveGetChildById('tokensLabel')
  local bonuses = state.bonuses or {}

  if pointsLabel then
    pointsLabel:setText(string.format('Unspent: %d', bonuses.unspent or bonuses.points or 0))
  end
  if tokensLabel then
    tokensLabel:setText(string.format('Tokens: %d', bonuses.tokens or 0))
  end

  local progress = state.progress or 0
  local amount = state.amount or 0
  local percent = 0
  if amount > 0 then
    percent = math.min(100, math.floor((progress / amount) * 100))
  end

  if (state.activeTaskId or 0) > 0 then
    local name = state.taskName or 'Task'
    if activeTitle then
      if state.pendingReward then
        activeTitle:setText(string.format('READY: %s', name))
        activeTitle:setColor('#7dff9fff')
      else
        activeTitle:setText(string.format('Active: %s', name))
        activeTitle:setColor('#ffd76aff')
      end
    end
    if activeProgress then
      activeProgress:setText(string.format('%s  |  %d / %d  (%d%%)', state.taskGroup or '', progress, amount, percent))
    end
    if activeProgressBar then
      if activeProgressBar.setOn then activeProgressBar:setOn(true) end
      activeProgressBar:setPercent(percent)
      activeProgressBar:setText(string.format('%d / %d', progress, amount))
      activeProgressBar:setVisible(true)
    end
  else
    if activeTitle then
      activeTitle:setText('No active task')
      activeTitle:setColor('#ffd76aff')
    end
    if activeProgress then
      activeProgress:setText('Choose a room and accept a hunt')
    end
    if activeProgressBar then
      activeProgressBar:setPercent(0)
      activeProgressBar:setText('')
    end
  end
  updateHeaderActions(state)
end

local function forceUiRefresh()
  -- Light no-op: avoid setWidth layout thrash on every opcode (FPS).
end

local function applyState(state)
  if not state then return end
  lastState = state
  updateHeader(state)
  forceUiRefresh()
end

local function findActiveTask(tasks)
  for _, task in ipairs(tasks or {}) do
    if task.active then
      return task
    end
  end
  return nil
end

local function focusTaskInList(task)
  if not window or not task then return end
  local list = window:recursiveGetChildById('tasksList')
  if not list then return end
  for i = 1, list:getChildCount() do
    local child = list:getChildByIndex(i)
    if child and child.taskData and child.taskData.id == task.id then
      list:focusChild(child)
      break
    end
  end
end

local function updateRewardIcons(task)
  if not window then return end
  local goldSlot = window:recursiveGetChildById('rewardGoldSlot')
  local tokenSlot = window:recursiveGetChildById('rewardTokenSlot')
  local goldLabel = window:recursiveGetChildById('rewardGoldLabel')
  local tokenLabel = window:recursiveGetChildById('rewardTokenLabel')
  local goldItem = goldSlot and goldSlot:getChildById('item') or nil
  local tokenItem = tokenSlot and tokenSlot:getChildById('item') or nil

  local rewards = task and (task.rewardsFirst or task.rewardsRepeat) or nil
  local gold = rewards and (rewards.gold or 0) or 0
  local tokens = rewards and (rewards.taskCoins or 0) or 0

  -- Currency icons: gold coin / crystal coin + best task token (22722)
  if goldItem and goldItem.setItemId then
    goldItem:setItemId(gold >= 10000 and 3043 or 3031)
  end
  if tokenItem and tokenItem.setItemId then
    tokenItem:setItemId(22722)
  end
  if goldLabel then
    goldLabel:setText(string.format('%d gold', gold))
  end
  if tokenLabel then
    tokenLabel:setText(string.format('%d tokens', tokens))
  end
end

local function updateDetails(task)
  selectedTask = task
  if not window then return end
  local body = window:recursiveGetChildById('detailsBody')
  local title = window:recursiveGetChildById('detailsTitle')
  local acceptButton = window:recursiveGetChildById('acceptButton')
  local abandonButton = window:recursiveGetChildById('abandonButton')
  local claimButton = window:recursiveGetChildById('claimButton')

  if not task then
    if title then title:setText('Details') end
    if body then body:setText('Select a task to view rewards and creatures.') end
    updateRewardIcons(nil)
    if acceptButton then acceptButton:setEnabled(false) end
    if abandonButton then
      local canAbandon = lastState and (lastState.activeTaskId or 0) > 0 and not lastState.pendingReward
      abandonButton:setEnabled(canAbandon and true or false)
    end
    if claimButton then
      local canClaim = lastState and (lastState.activeTaskId or 0) > 0 and lastState.pendingReward
      claimButton:setEnabled(canClaim and true or false)
    end
    return
  end

  if title then
    title:setText(task.name or 'Task')
  end

  local creatures = table.concat(task.creatures or {}, ', ')
  local lines = {
    string.format('Room: %s', task.group or currentGroup or '-'),
    string.format('Kills required: %d', task.amount or 0),
    string.format('Creatures: %s', creatures ~= '' and creatures or '-'),
    '',
    'First clear:',
    '  ' .. formatRewards(task.rewardsFirst),
    'Repeat:',
    '  ' .. formatRewards(task.rewardsRepeat),
    string.format('Best Points: +%d (first +%d / repeat +%d)',
      task.pointsReward or 0,
      task.pointsRewardFirst or task.pointsReward or 0,
      task.pointsRewardRepeat or task.pointsReward or 0),
    string.format('Completed: %dx', task.completedCount or 0)
  }
  if task.active then
    lines[#lines + 1] = ''
    lines[#lines + 1] = string.format('Progress: %d / %d', task.progress or 0, task.amount or 0)
    if task.pendingReward then
      lines[#lines + 1] = 'Status: REWARD READY'
    else
      lines[#lines + 1] = 'Status: IN PROGRESS'
    end
  end
  if body then body:setText(table.concat(lines, '\n')) end
  updateRewardIcons(task)

  local hasOtherActive = lastState and (lastState.activeTaskId or 0) > 0 and not task.active
  if acceptButton then
    acceptButton:setEnabled(not task.active and not (lastState and lastState.pendingReward) and not hasOtherActive)
  end
  if abandonButton then
    abandonButton:setEnabled(task.active and not task.pendingReward)
  end
  if claimButton then
    claimButton:setEnabled(task.active and task.pendingReward)
  end
end

local function clearList(list)
  if not list then return end
  list:destroyChildren()
end

local function showListPlaceholder(list, text)
  if not list then return end
  clearList(list)
  local label = g_ui.createWidget('BestTaskListLabel', list)
  label:setText(text)
  label:setColor('#a0a0a0ff')
  label:setFocusable(false)
  waitingLabelShown = true
end

local function addListLabel(list, text, data, color)
  local label = g_ui.createWidget('BestTaskListLabel', list)
  label:setText(text)
  if color then label:setColor(color) end
  label.taskData = data
  return label
end

local function fillRooms(groups)
  if not window then return end
  cancelSyncTimeout()
  local list = window:recursiveGetChildById('roomsList')
  clearList(list)
  waitingLabelShown = false
  groups = groups or {}
  if #groups == 0 then
    showListPlaceholder(list, 'No rooms received from server')
    return
  end
  for _, group in ipairs(groups) do
    local suffix = ''
    if group.hasActive then suffix = ' *' end
    local label = addListLabel(list, string.format('%s (%d)%s', group.name, group.count or 0, suffix), group,
      group.hasActive and '#7dff9fff' or '#e8e0c8ff')
    label.groupName = group.name
  end
end

local function fillTasks(tasks)
  if not window then return end
  local list = window:recursiveGetChildById('tasksList')
  local title = window:recursiveGetChildById('tasksTitle')
  clearList(list)
  if title then
    title:setText(currentGroup and ('Tasks - ' .. currentGroup) or 'Tasks')
  end
  tasks = tasks or {}
  if #tasks == 0 then
    showListPlaceholder(list, currentGroup and 'No tasks in this room' or 'Select a room')
    return
  end
  for _, task in ipairs(tasks) do
    local meta
    if task.active and task.pendingReward then
      meta = 'REWARD'
    elseif task.active then
      meta = string.format('%d/%d', task.progress or 0, task.amount or 0)
    else
      meta = tostring(task.amount or 0)
    end
    local color = '#e0e0e0ff'
    if task.active and task.pendingReward then color = '#7dff9fff'
    elseif task.active then color = '#ffd76aff'
    elseif (task.completedCount or 0) > 0 then color = '#a8c8ffff' end
    local label = addListLabel(list, string.format('%s   [%s]', task.name, meta), task, color)
    label.taskData = task
  end
end

local function applyTasksPayload(data)
  if data.groups then
    fillRooms(data.groups)
  end
  if data.group then
    currentGroup = data.group
  end
  if data.tasks then
    fillTasks(data.tasks)
    local active = findActiveTask(data.tasks)
    if active then
      focusTaskInList(active)
      updateDetails(active)
    elseif selectedTask then
      local refreshed = nil
      for _, task in ipairs(data.tasks or {}) do
        if selectedTask.id == task.id then
          refreshed = task
          break
        end
      end
      updateDetails(refreshed)
      if refreshed then focusTaskInList(refreshed) end
    else
      updateDetails(nil)
    end
  elseif data.action == 'abandoned' or data.action == 'claimed' then
    updateDetails(selectedTask)
  end
  forceUiRefresh()
end

local function fillBonuses(bonuses)
  if not window then return end
  bonuses = bonuses or {}
  lastBonuses = bonuses

  local summary = window:recursiveGetChildById('bonusesSummary')
  if summary then
    summary:setText(string.format('Unspent: %d  |  Invested: %d  |  Earned: %d  |  Premium Points: %d  |  Level: %d',
      bonuses.unspent or bonuses.points or 0,
      bonuses.invested or 0,
      bonuses.earned or 0,
      bonuses.premiumPoints or 0,
      bonuses.level or 0))
  end

  local respecBtn = window:recursiveGetChildById('respecButton')
  if respecBtn then
    local respecCost = bonuses.respecCost or 10
    respecBtn:setText(string.format('Respec (%d Premium Points)', respecCost))
    respecBtn:setTooltip(string.format(
      'Reset all invested Best Points bonuses.\nCosts %d Premium Points (you have %d).\nInvested Best Points are refunded as Unspent.',
      respecCost, bonuses.premiumPoints or 0))
    respecBtn:setEnabled(bonuses.canRespec and true or false)
  end

  local cardDefs = {
    { title = 'Capacity', field = 'capacity', image = 'capacity' },
    { title = 'Crit Chance', field = 'critChance', image = 'crit_chance' },
    { title = 'Crit Damage', field = 'extraDamage', image = 'crit_damage' },
    { title = 'Loot Chance', field = 'lootChance', image = 'loot_chance' },
    { title = 'Experience', field = 'xp', image = 'experience' },
  }

  local trackByType = {}
  for _, track in ipairs(bonuses.tracks or {}) do
    if track.type then
      trackByType[track.type] = track
    end
  end

  local cardsPanel = window:recursiveGetChildById('bonusesCards')
  if cardsPanel then
    cardsPanel:destroyChildren()
    local unspent = bonuses.unspent or bonuses.points or 0

    for _, cardInfo in ipairs(cardDefs) do
      local track = trackByType[cardInfo.field]
      local valueNum = (track and track.value) or bonuses[cardInfo.field] or 0
      local maxNum = (track and track.max) or 30
      local nextCost = track and track.nextCost or nil
      local canInvest = nextCost and unspent >= nextCost

      local card = g_ui.createWidget('BestTaskBonusCard', cardsPanel)
      card:setId('bonus_' .. cardInfo.field)

      local title = card:getChildById('title')
      local art = card:getChildById('art')
      local value = card:getChildById('value')
      local hint = card:getChildById('hint')
      local investButton = card:getChildById('investButton')

      if title then title:setText(cardInfo.title) end
      if art and art.setImageSource then
        art:setImageSource('/images/game/best_tasks/bonus_' .. cardInfo.image)
      end
      if value then
        value:setText(string.format('+%d%% / %d%%', valueNum, maxNum))
        value:setColor(valueNum > 0 and '#7dff9fff' or '#ffd76aff')
      end
      if hint then
        hint:setText(nextCost and string.format('Next: %d pts', nextCost) or 'MAX')
      end

      -- Ensure button exists even if style cache is stale.
      if not investButton then
        investButton = g_ui.createWidget('Button', card)
        investButton:setId('investButton')
        investButton:setWidth(116)
        investButton:setHeight(24)
        investButton:addAnchor(AnchorBottom, 'parent', AnchorBottom)
        investButton:addAnchor(AnchorHorizontalCenter, 'parent', AnchorHorizontalCenter)
        investButton:setMarginBottom(6)
      end
      if investButton.setFont then
        investButton:setFont('Verdana Bold-11px')
      end
      if investButton.setColor then
        investButton:setColor('#ffffffff')
      end

      if nextCost then
        investButton:setText(string.format('Invest +1%% (%d)', nextCost))
        investButton:setEnabled(canInvest and true or false)
      else
        investButton:setText('Maxed')
        investButton:setEnabled(false)
      end

      local function doInvest()
        send('invest', { bonusType = cardInfo.field, levels = 1 })
      end
      investButton.onClick = doInvest
      if canInvest then
        card.onClick = doInvest
      else
        card.onClick = nil
      end
    end
  end

  local body = window:recursiveGetChildById('bonusesBody')
  if body then
    local respecCost = bonuses.respecCost or 10
    body:setText(table.concat({
      'How to invest: click the Invest +1% button on a bonus card.',
      'Each click spends Unspent Best Points and raises that bonus by 1%.',
      string.format('Costs rise at higher ranks. Cap/Crit/Damage/Loot max 30%%, XP 45%%. Respec costs %d Premium Points and refunds invested Best Points.', respecCost)
    }, '\n'))
  end
end

function investBonus(bonusType)
  send('invest', { bonusType = bonusType, levels = 1 })
end

function respecBonuses()
  if not g_game or not g_game.isOnline or not g_game.isOnline() then
    return
  end

  local bonuses = lastBonuses or (lastState and lastState.bonuses) or {}
  local respecCost = bonuses.respecCost or 10
  local premiumPoints = bonuses.premiumPoints or 0
  local invested = bonuses.invested or 0

  if invested <= 0 and not bonuses.canRespec then
    if modules.game_textmessage then
      modules.game_textmessage.displayFailureMessage('Nothing to respec.')
    end
    return
  end

  if respecConfirmWindow then
    respecConfirmWindow:destroy()
    respecConfirmWindow = nil
  end

  local message = string.format(
    'Reset all Best Points bonuses?\n\nThis will cost %d Premium Points (you have %d).\nYou will receive %d Best Points back as Unspent.\n\nPremium Points are permanently spent.',
    respecCost, premiumPoints, invested)

  local function doRespec()
    if respecConfirmWindow then
      respecConfirmWindow:destroy()
      respecConfirmWindow = nil
    end
    send('respec')
  end

  local function cancelRespec()
    if respecConfirmWindow then
      respecConfirmWindow:destroy()
      respecConfirmWindow = nil
    end
  end

  respecConfirmWindow = displayGeneralBox(tr('Confirm Respec'), tr(message), {
    { text = tr('Confirm'), callback = doRespec },
    { text = tr('Cancel'), callback = cancelRespec },
  }, doRespec, cancelRespec)
end

local function fillShop(shop)
  lastShop = shop
  if not window then return end
  local scroll = window:recursiveGetChildById('outfitsScroll')
  local info = window:recursiveGetChildById('shopInfo')
  if info then
    info:setText(string.format('Spend Task Tokens on exclusive outfits  |  You have %d tokens', shop.tokens or 0))
  end
  if not scroll then return end
  scroll:destroyChildren()
  for _, outfit in ipairs(shop.outfits or {}) do
    local card = g_ui.createWidget('BestTaskOutfitCard', scroll)
    local nameLabel = card:getChildById('nameLabel')
    local preview = card:getChildById('preview')
    local buyBase = card:getChildById('buyBase')
    local buyAddon1 = card:getChildById('buyAddon1')
    local buyAddon2 = card:getChildById('buyAddon2')
    if nameLabel then nameLabel:setText(outfit.name) end
    if preview and outfit.lookType then
      preview:setOutfit({ type = outfit.lookType, head = 95, body = 113, legs = 39, feet = 115, addons = 0 })
    end
    if buyBase then
      buyBase:setText(outfit.hasBase and 'Base [Owned]' or string.format('Base (%d)', outfit.prices.outfit))
      buyBase:setEnabled(not outfit.hasBase)
      buyBase.onClick = function()
        send('buyOutfit', { outfitId = outfit.id, part = 'outfit' })
      end
    end
    if buyAddon1 then
      buyAddon1:setText(outfit.hasAddon1 and 'Addon 1 [Owned]' or string.format('Addon 1 (%d)', outfit.prices.addon1))
      buyAddon1:setEnabled(outfit.hasBase and not outfit.hasAddon1)
      buyAddon1.onClick = function()
        send('buyOutfit', { outfitId = outfit.id, part = 'addon1' })
      end
    end
    if buyAddon2 then
      buyAddon2:setText(outfit.hasAddon2 and 'Addon 2 [Owned]' or string.format('Addon 2 (%d)', outfit.prices.addon2))
      buyAddon2:setEnabled(outfit.hasBase and not outfit.hasAddon2)
      buyAddon2.onClick = function()
        send('buyOutfit', { outfitId = outfit.id, part = 'addon2' })
      end
    end
  end
end

function setTab(tab)
  currentTab = tab
  if not window then return end
  local roomsPanel = window:recursiveGetChildById('roomsPanel')
  local bonusesPanel = window:recursiveGetChildById('bonusesPanel')
  local shopPanel = window:recursiveGetChildById('shopPanel')
  if roomsPanel then roomsPanel:setVisible(tab == 'rooms') end
  if bonusesPanel then bonusesPanel:setVisible(tab == 'bonuses') end
  if shopPanel then shopPanel:setVisible(tab == 'shop') end

  if tab == 'bonuses' then
    send('bonuses')
  elseif tab == 'shop' then
    send('shop')
  elseif tab == 'rooms' then
    local list = window:recursiveGetChildById('roomsList')
    showListPlaceholder(list, 'Loading rooms...')
    armSyncTimeout()
    send('listGroups')
  end
end

function onRoomSelected()
  if not window then return end
  local list = window:recursiveGetChildById('roomsList')
  if not list then return end
  local focused = list:getFocusedChild()
  if not focused or not focused.groupName then return end
  currentGroup = focused.groupName
  local tasksList = window:recursiveGetChildById('tasksList')
  showListPlaceholder(tasksList, 'Loading tasks...')
  send('listTasks', { group = currentGroup })
end

function onTaskSelected()
  if not window then return end
  local list = window:recursiveGetChildById('tasksList')
  if not list then return end
  local focused = list:getFocusedChild()
  if not focused or not focused.taskData then
    updateDetails(nil)
    return
  end
  updateDetails(focused.taskData)
end

function acceptTask()
  if not selectedTask then return end
  local task = selectedTask
  -- Optimistic UI update (server confirms right after).
  applyState({
    activeTaskId = task.id,
    taskName = task.name,
    taskGroup = task.group or currentGroup or '',
    progress = 0,
    amount = task.amount or 0,
    pendingReward = false,
    bonuses = (lastState and lastState.bonuses) or { points = 0, tokens = 0 }
  })
  task.active = true
  task.progress = 0
  updateDetails(task)
  send('accept', { taskId = task.id })
end

function abandonTask()
  local hasActive = lastState and (tonumber(lastState.activeTaskId) or 0) > 0
  if not hasActive or (lastState and lastState.pendingReward) then
    return
  end

  if abandonConfirmWindow then
    abandonConfirmWindow:destroy()
    abandonConfirmWindow = nil
  end

  local taskName = (lastState and lastState.taskName) or ''
  if taskName == '' and selectedTask and selectedTask.name then
    taskName = selectedTask.name
  end

  local message = taskName ~= ''
    and string.format('Do you really want to cancel the task "%s"?\n\nYour progress will be lost.', taskName)
    or 'Do you really want to cancel the current task?\n\nYour progress will be lost.'

  local function doAbandon()
    if abandonConfirmWindow then
      abandonConfirmWindow:destroy()
      abandonConfirmWindow = nil
    end

    local prevGroup = (lastState and lastState.taskGroup) or currentGroup
    applyState({
      activeTaskId = 0,
      taskName = '',
      taskGroup = '',
      progress = 0,
      amount = 0,
      pendingReward = false,
      bonuses = (lastState and lastState.bonuses) or { points = 0, tokens = 0 }
    })
    if selectedTask then
      selectedTask.active = false
      selectedTask.pendingReward = false
      updateDetails(selectedTask)
    else
      updateDetails(nil)
    end
    send('abandon')
    if prevGroup and prevGroup ~= '' then
      scheduleEvent(function()
        send('listTasks', { group = prevGroup })
      end, 80)
    end
  end

  local function cancelAbandon()
    if abandonConfirmWindow then
      abandonConfirmWindow:destroy()
      abandonConfirmWindow = nil
    end
  end

  abandonConfirmWindow = displayGeneralBox(tr('Cancel Task'), tr(message), {
    { text = tr('Yes'), callback = doAbandon },
    { text = tr('No'), callback = cancelAbandon },
  }, doAbandon, cancelAbandon)
end

function claimReward()
  send('claim')
end

function doSearch()
  if not window then return end
  local edit = window:recursiveGetChildById('searchEdit')
  local query = edit and edit:getText() or ''
  if #query < 2 then return end
  if lastSearchQuery == query then return end
  lastSearchQuery = query
  setTab('rooms')
  currentGroup = 'Search'
  send('search', { query = query })
end

function onSearchChanged()
  removeEvent(searchEvent)
  searchEvent = scheduleEvent(function()
    doSearch()
  end, 550)
end

function openShopPreview()
  local url = (lastShop and lastShop.previewUrl) or 'https://bestserverot.com.br/?task_outfits'
  g_platform.openUrl(url)
end

local function onOpcode(protocol, opcode, buffer)
  if opcode ~= OPCODE then return end
  local ok, data = pcall(function() return json.decode(buffer) end)
  if not ok or type(data) ~= 'table' then
    if g_logger then
      g_logger.error('[BestTasks] bad opcode payload: ' .. tostring(data))
    end
    return
  end

  if data.state then
    applyState(data.state)
  elseif data.action == 'state' then
    applyState(data)
  end

  if data.action == 'error' then
    if modules.game_textmessage then
      modules.game_textmessage.displayFailureMessage(data.message or 'Best Tasks error')
    end
    -- Re-sync to undo optimistic UI if accept/cancel failed.
    send('sync')
    return
  end

  if data.action == 'accepted' or data.action == 'abandoned' or data.action == 'claimed' or data.action == 'refresh' then
    applyTasksPayload(data)
  elseif data.action == 'groups' then
    if data.groups then fillRooms(data.groups) end
    applyTasksPayload(data)
    if currentGroup and not data.tasks then
      send('listTasks', { group = currentGroup })
    end
  elseif data.action == 'tasks' then
    applyTasksPayload(data)
  elseif data.action == 'search' then
    currentGroup = 'Search: ' .. (data.query or '')
    fillTasks(data.tasks)
    updateDetails(nil)
    forceUiRefresh()
  elseif data.action == 'details' then
    if data.task then
      data.task.group = data.task.group or currentGroup
      updateDetails(data.task)
      forceUiRefresh()
    end
  elseif data.action == 'bonuses' then
    fillBonuses(data.bonuses or (data.state and data.state.bonuses))
  elseif data.action == 'shop' then
    fillShop(data)
  elseif data.action == 'state' or data.action == 'progress' then
    -- Prefer payload tasks/groups when present; otherwise request refresh.
    if data.tasks or data.groups then
      applyTasksPayload(data)
    elseif currentTab == 'rooms' and currentGroup and currentGroup ~= '' and not tostring(currentGroup):find('Search') then
      send('listTasks', { group = currentGroup })
    elseif currentTab == 'rooms' then
      send('listGroups')
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
  lastSearchQuery = nil
  if ProtocolGame and ProtocolGame.unregisterExtendedOpcode then
    pcall(function() ProtocolGame.unregisterExtendedOpcode(OPCODE) end)
  end
end

function init()
  window = g_ui.displayUI('best_tasks')
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
  removeEvent(searchEvent)
  cancelSyncTimeout()
  offline()
  disconnect(g_game, {
    onGameStart = online,
    onGameEnd = offline
  })
  if respecConfirmWindow then
    respecConfirmWindow:destroy()
    respecConfirmWindow = nil
  end
  if abandonConfirmWindow then
    abandonConfirmWindow:destroy()
    abandonConfirmWindow = nil
  end
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
  if not g_game.isOnline() then return end
  -- Recreate window so OTUI style changes (invest buttons) always apply.
  if window then
    window:destroy()
    window = nil
  end
  window = g_ui.displayUI('best_tasks')
  if not window then return end
  window:show()
  window:raise()
  window:focus()
  local crest = window:getChildById('crest')
  if crest then
    crest:raise()
  end
  setTab(currentTab or 'rooms')
  send('sync')
end

function hide()
  cancelSyncTimeout()
  if respecConfirmWindow then
    respecConfirmWindow:destroy()
    respecConfirmWindow = nil
  end
  if abandonConfirmWindow then
    abandonConfirmWindow:destroy()
    abandonConfirmWindow = nil
  end
  if window then
    window:hide()
  end
end
