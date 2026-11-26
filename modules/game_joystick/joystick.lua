-- chunkname: @/game_joystick/joystick.lua

local overlay, keypad, dragHandle, joystickShortcut, keypadUpdateEvent
local keypadMousePos = {
	x = 0.5,
	y = 0.5
}
local firstStep = true
local pressStartedAt = 0
local moveListener
local draggingKeypad = false
local dragOffset = {
	x = 0,
	y = 0
}
local HOLD_BEFORE_REPEAT_MS = 280
local JOYSTICK_CHROME_HEIGHT = 22
local JOYSTICK_SETTINGS = "joystickLayout"

function init()
	if not g_platform.isMobile() then
		return
	end

	overlay = g_ui.displayUI("joystick")
	keypad = overlay.keypad
	dragHandle = overlay.dragHandle

	connect(keypad, {
		onMousePress = onKeypadTouchPress,
		onMouseRelease = onKeypadTouchRelease,
		onMouseMove = onKeypadTouchMove,
		onGeometryChange = placeJoystickChrome
	})
	connect(dragHandle, {
		onMousePress = onDragHandlePress,
		onMouseRelease = onDragHandleRelease,
		onMouseMove = onDragHandleMove
	})
	ensureJoystickShortcut()
	connect(g_game, {
		onGameStart = onGameStart,
		onGameEnd = onGameEnd
	})
end

function terminate()
	if not g_platform.isMobile() then
		return
	end

	removeEvent(keypadUpdateEvent)
	disconnect(keypad, {
		onMousePress = onKeypadTouchPress,
		onMouseRelease = onKeypadTouchRelease,
		onMouseMove = onKeypadTouchMove,
		onGeometryChange = placeJoystickChrome
	})
	disconnect(dragHandle, {
		onMousePress = onDragHandlePress,
		onMouseRelease = onDragHandleRelease,
		onMouseMove = onDragHandleMove
	})
	disconnect(g_game, {
		onGameStart = onGameStart,
		onGameEnd = onGameEnd
	})
	overlay:destroy()

	overlay = nil
	keypadUpdateEvent = nil
end

function hide()
	overlay:hide()
end

function show()
	overlay:show()
end

function onGameStart()
	addEvent(function()
		if not keypad or keypad:isDestroyed() then
			return
		end

		ensureJoystickShortcut()
		restoreJoystickLayout()
		keypad:raise()
		dragHandle:raise()
		scheduleEvent(ensureJoystickShortcut, 300)
	end)
end

function onGameEnd()
	keypad:hide()
	dragHandle:hide()
end

local function keypadLocalPosition()
	local origin = overlay:getPosition()
	local pos = keypad:getPosition()

	return pos.x - origin.x, pos.y - origin.y
end

function moveJoystickTo(localX, localY)
	if not overlay or overlay:getHeight() < 100 or overlay:getWidth() < 100 then
		return
	end

	local origin = overlay:getPosition()
	local maxX = math.max(0, overlay:getWidth() - keypad:getWidth())
	local maxY = math.max(JOYSTICK_CHROME_HEIGHT, overlay:getHeight() - keypad:getHeight())

	localX = math.max(0, math.min(maxX, localX))
	localY = math.max(JOYSTICK_CHROME_HEIGHT, math.min(maxY, localY))
	keypad:breakAnchors()
	keypad:setPosition({
		x = origin.x + localX,
		y = origin.y + localY
	})
	placeJoystickChrome()
end

function placeJoystickChrome()
	if not keypad or not dragHandle then
		return
	end

	local pos = keypad:getPosition()

	dragHandle:setPosition({
		x = pos.x + math.floor((keypad:getWidth() - dragHandle:getWidth()) / 2),
		y = pos.y - dragHandle:getHeight()
	})
	dragHandle:setVisible(keypad:isVisible())

	if joystickShortcut and not joystickShortcut:isDestroyed() then
		joystickShortcut:setOn(keypad:isVisible())
	end
end

function saveJoystickLayout()
	local localX, localY = keypadLocalPosition()

	g_settings.setNode(JOYSTICK_SETTINGS, {
		x = localX,
		y = localY,
		visible = keypad:isVisible() and 1 or 0
	})
	syncJoystickClearance()
end

function restoreJoystickLayout()
	local node = g_settings.getNode(JOYSTICK_SETTINGS)
	local visible = true

	if type(node) == "table" then
		local savedX = tonumber(node.x)
		local savedY = tonumber(node.y)

		if savedX and savedY then
			moveJoystickTo(savedX, savedY)
		end

		if tonumber(node.visible) == 0 then
			visible = false
		end
	end

	setJoystickVisible(visible, true)
end

function syncJoystickClearance()
	local leftPanel = modules.game_interface and modules.game_interface.getLeftPanel and modules.game_interface.getLeftPanel()

	if not leftPanel or leftPanel:isDestroyed() or not keypad or not overlay then
		return
	end

	local localX, localY = keypadLocalPosition()
	local gapBelow = overlay:getHeight() - localY - keypad:getHeight()
	local coversBottomLeft = keypad:isVisible() and localX < 30 and gapBelow < 30

	leftPanel:setMarginBottom(coversBottomLeft and keypad:getHeight() or 0)
end

function setJoystickVisible(visible, skipSave)
	keypad:setVisible(visible)
	placeJoystickChrome()

	if not skipSave then
		saveJoystickLayout()
	else
		syncJoystickClearance()
	end
end

function toggleJoystick()
	setJoystickVisible(not keypad:isVisible())
end

function ensureJoystickShortcut()
	if joystickShortcut and not joystickShortcut:isDestroyed() then
		joystickShortcut:setVisible(true)
		joystickShortcut:setOn(keypad and keypad:isVisible())

		return
	end

	if not modules.game_mainpanel or not modules.game_mainpanel.addToggleButton then
		return
	end

	joystickShortcut = modules.game_mainpanel.addToggleButton("joystickButton", tr("Show or hide the joystick"), "/images/game/mobile/joystick_toggle", toggleJoystick, false, 0)

	if not joystickShortcut then
		return
	end

	joystickShortcut:setVisible(true)
	joystickShortcut:setOn(keypad and keypad:isVisible())

	if modules.game_mainpanel.setMainPanelButtonVisible then
		modules.game_mainpanel.setMainPanelButtonVisible("joystickButton", true)
	end
end

function onDragHandlePress(widget, pos, button)
	if button ~= MouseLeftButton then
		return false
	end

	local keypadPos = keypad:getPosition()

	draggingKeypad = true
	dragOffset.x = pos.x - keypadPos.x
	dragOffset.y = pos.y - keypadPos.y
	widget:grabMouse()

	return true
end

function onDragHandleMove(widget, pos)
	if not draggingKeypad then
		return false
	end

	local origin = overlay:getPosition()

	moveJoystickTo(pos.x - dragOffset.x - origin.x, pos.y - dragOffset.y - origin.y)

	return true
end

function onDragHandleRelease(widget, pos, button)
	if button ~= MouseLeftButton then
		return false
	end

	draggingKeypad = false

	if widget.ungrabMouse then
		widget:ungrabMouse()
	end

	saveJoystickLayout()

	return true
end

function addOnJoystickMoveListener(callback)
	moveListener = callback
end

function onKeypadTouchPress(widget, pos, button)
	if button ~= MouseLeftButton then
		return false
	end

	keypadMousePos = {
		x = (pos.x - widget:getPosition().x) / widget:getWidth(),
		y = (pos.y - widget:getPosition().y) / widget:getHeight()
	}
	firstStep = true
	pressStartedAt = g_clock.millis()

	executeWalk()

	return true
end

function onKeypadTouchMove(widget, pos, offset)
	keypadMousePos = {
		x = (pos.x - widget:getPosition().x) / widget:getWidth(),
		y = (pos.y - widget:getPosition().y) / widget:getHeight()
	}

	return true
end

function onKeypadTouchRelease(widget, pos, button)
	if button ~= MouseLeftButton then
		return false
	end

	removeEvent(keypadUpdateEvent)

	keypadUpdateEvent = nil
	firstStep = true
	keypad.pointer:setMarginTop(0)
	keypad.pointer:setMarginLeft(0)

	return true
end

function executeWalk()
	removeEvent(keypadUpdateEvent)

	keypadUpdateEvent = nil

	if not g_mouse.isPressed(MouseLeftButton) then
		keypad.pointer:setMarginTop(0)
		keypad.pointer:setMarginLeft(0)

		return
	end

	keypadUpdateEvent = scheduleEvent(executeWalk, 20)
	keypadMousePos.x = math.min(1, math.max(0, keypadMousePos.x))
	keypadMousePos.y = math.min(1, math.max(0, keypadMousePos.y))

	local angle = math.atan2(keypadMousePos.x - 0.5, keypadMousePos.y - 0.5)
	local maxTop = math.abs(math.cos(angle)) * 75
	local marginTop = math.max(-maxTop, math.min(maxTop, (keypadMousePos.y - 0.5) * 150))
	local maxLeft = math.abs(math.sin(angle)) * 75
	local marginLeft = math.max(-maxLeft, math.min(maxLeft, (keypadMousePos.x - 0.5) * 150))

	keypad.pointer:setMarginTop(marginTop)
	keypad.pointer:setMarginLeft(marginLeft)

	local dir

	if keypadMousePos.y < 0.3 and keypadMousePos.x < 0.3 then
		dir = Directions.NorthWest
	elseif keypadMousePos.y < 0.3 and keypadMousePos.x > 0.7 then
		dir = Directions.NorthEast
	elseif keypadMousePos.y > 0.7 and keypadMousePos.x < 0.3 then
		dir = Directions.SouthWest
	elseif keypadMousePos.y > 0.7 and keypadMousePos.x > 0.7 then
		dir = Directions.SouthEast
	end

	if not dir and (math.abs(keypadMousePos.y - 0.5) > 0.1 or math.abs(keypadMousePos.x - 0.5) > 0.1) then
		if math.abs(keypadMousePos.y - 0.5) > math.abs(keypadMousePos.x - 0.5) then
			if keypadMousePos.y < 0.5 then
				dir = Directions.North
			else
				dir = Directions.South
			end
		elseif keypadMousePos.x < 0.5 then
			dir = Directions.West
		else
			dir = Directions.East
		end
	end

	local held = g_clock.millis() - pressStartedAt

	if dir and moveListener and (firstStep or held >= HOLD_BEFORE_REPEAT_MS) then
		moveListener(dir, firstStep)

		firstStep = false
	end
end

function getPanel()
	return keypad
end
