-- See TacoShell Copyright Notice in main folder of distribution

-- Imports --
local StateSwitch = widgetops.StateSwitch
local SuperCons = class.SuperCons

-- Unique member keys --
local _is_checked = {}

-- C: Checkbox handle
local function Toggle (C)
	C[_is_checked] = not C[_is_checked]
end

-- Stock signals --
local Signals = {}

---
-- @class function
-- @name Signals:grab
Signals.grab = Toggle

--- The <b>"checked"</b> or <b>"unchecked"</b> picture is drawn with rect (x, y, w, h), based
-- on the current state. The <b>"frame"</b> picture is then drawn in the same area.
-- @param x Rect x-coordinate.
-- @param y Rect y-coordinate.
-- @param w Rect width.
-- @param h Rect height.
function Signals:render (x, y, w, h)
	self:DrawPicture(self[_is_checked] and "checked" or "unchecked", x, y, w, h)

	-- Frame the checkbox.
	self:DrawPicture("frame", x, y, w, h)
end

-- Checkbox class definition --
class.Define("Checkbox", function(Checkbox)
	--- Status.
	-- @return If true, the box is checked.
	function Checkbox:IsChecked ()
		return self[_is_checked] == true
	end

	--- Sets the current check state. Toggles will send signals as<br><br>
	-- &nbsp&nbsp&nbsp<b><i>signal(C, "toggle")</i></b>,<br><br>
	-- where <i>signal</i> will be <b>switch_from</b> or <b>switch_to</b>, and <i>C</i>
	-- refers to this checkbox.
	-- @param check Check state to assign.
	-- @param always_refresh If true, receive <b>"switch_to"</b> signals even when the
	-- check state does not toggle.
	function Checkbox:SetCheck (check, always_refresh)
		StateSwitch(self, not check ~= not self[_is_checked], always_refresh, Toggle, "toggle")
	end
end,

--- Class constructor.
-- @class function
-- @name Constructor
-- @param group Group handle.
function(C, group)
	SuperCons(C, "Widget", group)

	-- Signals --
	C:SetMultipleSignals(Signals)
end, { base = "Widget" })