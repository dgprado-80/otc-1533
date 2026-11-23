-- Registers BestServer custom system icons on the main side panel.

isHiddenMenuActive = false

local streamerShopEnabled = false
local refundButtonVisible = false

local function invoke(moduleName, fnName)
  local mod = modules[moduleName]
  if mod and mod[fnName] then
    mod[fnName]()
  end
end

local ICON_BUTTONS = {
  { id = 'bestTasksDialog', tooltip = tr('Best Tasks'), icon = 'bestTasksDialog', index = 50,
    callback = function() invoke('game_best_tasks', 'toggle') end },
  { id = 'upgradeStonesDialog', tooltip = tr('Upgrade Stones'), icon = 'upgradeStonesDialog', index = 51,
    callback = function() invoke('game_upgrade_stones', 'toggle') end },
  { id = 'skillPerksDialog', tooltip = tr('Skill Perks'), icon = 'skillPerksDialog', index = 52,
    callback = function() invoke('game_skill_perks', 'toggle') end },
  { id = 'bestPassportDialog', tooltip = tr('Best Partner Passport'), icon = 'bestPassportDialog', index = 53,
    callback = function() invoke('game_best_passport', 'toggle') end },
  { id = 'levelRewardDialog', tooltip = tr('Level Reward'), icon = 'levelRewardDialog', index = 54,
    callback = function() invoke('game_level_reward', 'toggle') end },
  { id = 'systemsGuideDialog', tooltip = tr('BestServerOt Systems Guide'), icon = 'compendiumDialog', index = 55,
    callback = function() invoke('game_systems_guide', 'toggle') end },
  { id = 'bugReportDialog', tooltip = tr('Bug Report (Ctrl+Z)'), icon = 'bugReportDialog', index = 57,
    callback = function() invoke('game_bugreport', 'show') end },
}

local OPTIONAL_BUTTONS = {
  { id = 'streamerShopDialog', tooltip = tr('Streamer Shop'), icon = 'twitch', index = 58,
    callback = function() invoke('game_streamershop', 'toggle') end },
  { id = 'refundDialog', tooltip = tr('Season Refund'), icon = 'bestPassportDialog', index = 59,
    callback = function() invoke('game_refund', 'show') end },
}

local function reloadPanel()
  if modules.game_mainpanel and modules.game_mainpanel.reloadMainPanelSizes then
    modules.game_mainpanel.reloadMainPanelSizes()
  end
end

local function setButtonVisible(id, visible)
  if not modules.game_mainpanel then
    return
  end
  local btn = modules.game_mainpanel.getButton(id)
  if btn then
    btn:setVisible(visible)
    reloadPanel()
  end
end

function setStreamerShopEnabled(enabled)
  enabled = enabled == true
  if streamerShopEnabled == enabled then
    return
  end
  streamerShopEnabled = enabled
  if isHiddenMenuActive then
    return
  end
  setButtonVisible('streamerShopDialog', enabled)
end

function setRefundButtonVisible(visible)
  refundButtonVisible = visible and true or false
  if isHiddenMenuActive then
    return
  end
  setButtonVisible('refundDialog', refundButtonVisible)
end

local function registerButtons()
  if not modules.game_mainpanel or not modules.game_mainpanel.addToggleButton then
    return
  end

  for _, cfg in ipairs(ICON_BUTTONS) do
    local image = string.format('/images/topbuttons/%s.png', cfg.icon)
    modules.game_mainpanel.addToggleButton(cfg.id, cfg.tooltip, image, cfg.callback, false, cfg.index)
  end

  for _, cfg in ipairs(OPTIONAL_BUTTONS) do
    local image = string.format('/images/topbuttons/%s.png', cfg.icon)
    local btn = modules.game_mainpanel.addToggleButton(cfg.id, cfg.tooltip, image, cfg.callback, false, cfg.index)
    if btn then
      btn:setVisible(false)
    end
  end

  setStreamerShopEnabled(streamerShopEnabled)
  setRefundButtonVisible(refundButtonVisible)
  reloadPanel()
end

local function onGameStart()
  scheduleEvent(registerButtons, 150)
end

function init()
  connect(g_game, { onGameStart = onGameStart })
  if g_game.isOnline() then
    onGameStart()
  end
end

function terminate()
  disconnect(g_game, { onGameStart = onGameStart })
end
