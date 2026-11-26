-- chunkname: @/game_shortcuts/shortcuts.lua

local shortcutsWindow, shortcuts, shortcutIcons, actionShortcut
local ACTION_SETTINGS = "mobileActionButtonsVisible"

function init()
	if not g_platform.isMobile() then
		return
	end

	shortcutsWindow = g_ui.displayUI("shortcuts")
	shortcuts = shortcutsWindow.shortcuts
	shortcutIcons = shortcuts.shortcutIcons

	connect(g_game, {
		onGameStart = onGameStart,
		onGameEnd = onGameEnd
	})
	setupShortcuts()
	ensureActionShortcut()
end

function terminate()
	if not g_platform.isMobile() then
		return
	end

	disconnect(g_game, {
		onGameStart = onGameStart,
		onGameEnd = onGameEnd
	})
	shortcutsWindow:destroy()

	shortcutsWindow = nil
end

function onGameStart()
	addEvent(function()
		if not shortcuts or shortcuts:isDestroyed() then
			return
		end

		ensureActionShortcut()
		setActionsVisible(readActionsVisible(), true)
		scheduleEvent(ensureActionShortcut, 300)
	end)
end

function onGameEnd()
	shortcuts:hide()
end

function readActionsVisible()
	local node = g_settings.getNode(ACTION_SETTINGS)

	if type(node) == "table" and tonumber(node.visible) == 0 then
		return false
	end

	return true
end

function syncActionsClearance()
	local rightPanel = modules.game_interface and modules.game_interface.getRightPanel and modules.game_interface.getRightPanel()

	if not rightPanel or rightPanel:isDestroyed() or not shortcuts then
		return
	end

	rightPanel:setMarginBottom(shortcuts:isVisible() and shortcuts:getHeight() or 0)
end

function setActionsVisible(visible, skipSave)
	shortcuts:setVisible(visible)

	if actionShortcut and not actionShortcut:isDestroyed() then
		actionShortcut:setOn(visible)
		actionShortcut:setVisible(true)
	end

	if not skipSave then
		g_settings.setNode(ACTION_SETTINGS, {
			visible = visible and 1 or 0
		})
	end

	syncActionsClearance()
end

function toggleActions()
	setActionsVisible(not shortcuts:isVisible())
end

function ensureActionShortcut()
	if actionShortcut and not actionShortcut:isDestroyed() then
		actionShortcut:setVisible(true)
		actionShortcut:setOn(shortcuts and shortcuts:isVisible())

		return
	end

	if not modules.game_mainpanel or not modules.game_mainpanel.addToggleButton then
		return
	end

	actionShortcut = modules.game_mainpanel.addToggleButton("actionButtons", tr("Show or hide attack, follow, look and use"), "/images/game/mobile/actions_toggle", toggleActions, false, 1)

	if not actionShortcut then
		return
	end

	actionShortcut:setVisible(true)
	actionShortcut:setOn(shortcuts and shortcuts:isVisible())

	if modules.game_mainpanel.setMainPanelButtonVisible then
		modules.game_mainpanel.setMainPanelButtonVisible("actionButtons", true)
	end
end

function hide()
	shortcutsWindow:hide()
end

function show()
	shortcutsWindow:show()
end

function setupShortcuts()
	if not g_platform.isMobile() then
		return
	end

	for _, widget in ipairs(shortcutIcons:getChildren()) do
		widget.image:setChecked(false)

		widget.lastClicked = 0

		function widget.onClick()
			if widget.image:isChecked() then
				widget.image:setChecked(false)

				return
			end

			resetShortcuts()
			widget.image:setChecked(true)

			widget.lastClicked = g_clock.millis()
		end
	end
end

function resetShortcuts()
	for _, widget in ipairs(shortcutIcons:getChildren()) do
		widget.image:setChecked(false)

		widget.lastClicked = 0
	end
end

function getShortcut()
	for _, widget in ipairs(shortcutIcons:getChildren()) do
		if widget.image:isChecked() then
			return widget:getId()
		end
	end

	return ""
end

function getPanel()
	return shortcuts
end
