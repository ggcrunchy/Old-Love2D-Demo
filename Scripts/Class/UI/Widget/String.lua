-- See TacoShell Copyright Notice in main folder of distribution

-- Imports --
local DrawString = widgetops.DrawString
local StringGetH = widgetops.StringGetH
local StringGetW = widgetops.StringGetW
local StringSize = widgetops.StringSize
local SuperCons = class.SuperCons

--- Draws the string at (x, y).
-- @class function
-- @name Signals:render
-- @param x String x-coordinate.
-- @param y String y-coordinate.

--
local function Render (S, x, y, w, h)
	DrawString(S, S:GetString(), nil, nil, x, y, w, h)
end

-- String class definition --
class.Define("String", function(String)
	-- Dimension getters --
	for what, func in pairs{
		--- Accessor, override of <b>Widget:GetH</b>.<br><br>
		-- The string widget will report its height based on its current string and font.
		-- @class function
		-- @name String:GetH
		-- @return Height.
		GetH = StringGetH,

		--- Accessor.
		-- @class function
		-- @name String:GetSize
		-- @return Width.
		-- @return Height.
		GetSize = StringSize,

		--- Accessor, override of <b>Widget:GetW</b>.<br><br>
		-- The string widget will report its width based on its current string and font.
		-- @name String:GetW
		-- @class function
		-- @return Width.
		GetW = StringGetW
	} do
		String[what] = function(S)
			return func(S, S:GetString())
		end
	end
end,

--- Class constructor.
-- @class function
-- @name Constructor
-- @param group Group handle.
function(S, group)
	SuperCons(S, "Widget", group)

	-- Signals --
	S:SetSignal("render", Render)
end, { base = "Widget" })