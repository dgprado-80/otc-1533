-- chunkname: @/corelib/ui/uiwindow.lua

UIWindow = extends(UIWidget, "UIWindow")

function UIWindow.create()
	local window = UIWindow.internalCreate()

	window:setTextAlign(AlignTopCenter)
	window:setDraggable(true)
	window:setAutoFocusPolicy(AutoFocusFirst)

	window.hotkeyBlock = false

	return window
end

function UIWindow:onKeyPress(keyCode, keyboardModifiers)
	if keyboardModifiers == KeyboardNoModifier then
		if g_keyboard.isEnterKey(keyCode) then
			signalcall(self.onEnter, self)
		elseif keyCode == KeyEscape then
			signalcall(self.onEscape, self)
		end
	end
end

function UIWindow:onFocusChange(focused)
	if focused then
		self:raise()
	end
end

function UIWindow:onDragEnter(mousePos)
	self:breakAnchors()

	self.movingReference = {
		x = mousePos.x - self:getX(),
		y = mousePos.y - self:getY()
	}

	return true
end

function UIWindow:onDragLeave(droppedWidget, mousePos)
	return
end

function UIWindow:onDragMove(mousePos, mouseMoved)
	local pos = {
		x = mousePos.x - self.movingReference.x,
		y = mousePos.y - self.movingReference.y
	}

	self:setPosition(pos)
	self:bindRectToParent()
end

function UIWindow:fitOnScreen()
	if not g_platform.isMobile() or self._fittingOnScreen or self:isDestroyed() then
		return
	end

	local parent = self:getParent()
	local root = g_ui.getRootWidget()

	if not parent or parent:isDestroyed() or not root or root:isDestroyed() then
		return
	end

	local maxWidth = root:getWidth() - 12
	local maxHeight = root:getHeight() - 12

	if maxWidth < 120 or maxHeight < 120 then
		return
	end

	local width = self:getWidth()
	local height = self:getHeight()

	if width <= maxWidth and height <= maxHeight then
		return
	end

	local fittedWidth = math.min(width, maxWidth)
	local fittedHeight = math.min(height, maxHeight)
	local docked = parent:getClassName() == "UIMiniWindowContainer"

	self._fittingOnScreen = true
	self:setSize({
		width = fittedWidth,
		height = fittedHeight
	})

	if not docked then
		self:breakAnchors()
		self:setPosition({
			x = parent:getX() + math.max(0, math.floor((parent:getWidth() - fittedWidth) / 2)),
			y = parent:getY() + math.max(0, math.floor((parent:getHeight() - fittedHeight) / 2))
		})
	end

	self._fittingOnScreen = false
end

function UIWindow:onGeometryChange()
	self:fitOnScreen()
end

function UIWindow:onVisibilityChange(visible)
	if visible then
		self:fitOnScreen()
	end
end

function UIWindow:onDestroy()
	if self.hotkeyBlock then
		self.hotkeyBlock.release()

		self.hotkeyBlock = false
	end
end
