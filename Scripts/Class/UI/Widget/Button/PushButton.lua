-- See TacoShell Copyright Notice in main folder of distribution

-- Imports --
local ButtonStyleRender = widgetops.ButtonStyleRender
local DrawString = widgetops.DrawString
local NoOp = funcops.NoOp
local SuperCons = class.SuperCons

-- Unique member keys --
local _action = {}
local _style = {}
local _sx = {}
local _sy = {}

-- Stock signals --
local Signals = {}

function Signals:drop ()
	if self:IsEntered() then
		(self[_action] or NoOp)(self)
	end
end

function Signals:render (x, y, w, h)
	ButtonStyleRender(self, x, y, w, h)

	-- Draw the button string.
	local style, sx, sy = self:GetTextSetup()

	DrawString(self, self:GetString(), style, "center", x + sx, y + sy, w - sx, h - sy)
end

-- PushButton class definition --
class.Define("PushButton", function(PushButton)
	-- Returns: Horizontal text style, offset coordinates
	------------------------------------------------------
	function PushButton:GetTextSetup ()
		return self[_style] or "center", self[_sx] or 0, self[_sy] or 0
	end

	-- action: Action to assign
	----------------------------
	function PushButton:SetAction (action)
		self[_action] = action
	end

	-- style: Horizontal text style to assign
	-- sx, sy: Offset coordinates
	------------------------------------------
	function PushButton:SetTextSetup (style, sx, sy)
		if style == "center" then
			sx = 0
			sy = 0
		end

		self[_style] = style
		self[_sx] = sx
		self[_sy] = sy
	end
end,

--- Class constructor.
-- @class function
-- @name Constructor
-- @param group Group handle.
function(P, group)
	SuperCons(P, "Widget", group)

	-- Signals --
	P:SetMultipleSignals(Signals)
end, { base = "Widget" })