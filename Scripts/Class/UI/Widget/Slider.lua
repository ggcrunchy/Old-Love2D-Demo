-- See TacoShell Copyright Notice in main folder of distribution

-- Imports --
local ButtonStyleRender = widgetops.ButtonStyleRender
local ClampIn = numericops.ClampIn
local New = class.New
local PointInBox = numericops.PointInBox
local StateSwitch = widgetops.StateSwitch
local SuperCons = class.SuperCons
local SwapIf = numericops.SwapIf

-- Unique member keys --
local _dist1 = {}
local _dist2 = {}
local _fixed = {}
local _is_vertical = {}
local _off_center = {}
local _offset = {}
local _th = {}
local _thumb = {}
local _tw = {}

-- S: Slider handle
-- factor: Offset factor
-- state: Execution state
-- Returns: Computed relative offset
local function CursorOffset (S, factor, state)
	local cx, cy = state("cursor")
	local x, y = S:GetRect(true)

	if S[_is_vertical] then
		return (cy - y - factor) / (S:GetH() - S[_dist2] - S[_dist1])
	else
		return (cx - x - factor) / (S:GetW() - S[_dist2] - S[_dist1])
	end
end

-- S: Slider handle
-- Returns: Thumb offset
local function ThumbOffset (S)
	local dim = S[_is_vertical] and S:GetH() or S:GetW()

	return S[_dist1] + S:GetOffset() * (dim - S[_dist2] - S[_dist1])
end

-- Stock thumb signals --
local ThumbSignals = {}

---
-- @param state Execution state.
function ThumbSignals:grab (state)
	local slider = self:GetOwner()

	self[_off_center] = CursorOffset(slider, ThumbOffset(slider), state)
end

---
-- @param state Execution state.
function ThumbSignals:leave_upkeep (state)
	local slider = self:GetOwner()

	if self:IsGrabbed() then
		slider:SetOffset(CursorOffset(slider, slider[_dist1], state) - self[_off_center])
	end
end

-- Thumb class definition --
local u_ThumbName = widgetops.DefineOwnedWidget(nil, function(T)
	T:SetMultipleSignals(ThumbSignals)
end)

-- S: Slider handle
-- x, y: Slider coordiantes
-- Returns: Thumb coordinates, dimensions
local function ThumbBox (S, x, y)
	local tx, ty = SwapIf(S[_is_vertical], ThumbOffset(S), S[_fixed])

	return x + tx, y + ty, S[_tw], S[_th]
end

-- Stock signals --
local Signals = {}

---
-- @param state Execution state.
function Signals:grab (state)
	self:SetOffset(CursorOffset(self, self[_dist1], state))
end

--- Draws the slider background with picture <b>"main"</b> in (x, y, w, h).<br><br>
-- The slider is then drawn at its current offset with the picture matching its cursor state:
-- <b>"main"</b>, <b>"entered"</b>, or <b>"grabbed"</b>. Note that these widgets belong to
-- the thumb widget and not the slider.
-- @param x Rect x-coordinate.
-- @param y Rect y-coordinate.
-- @param w Rect width.
-- @param h Rect height.
function Signals:render (x, y, w, h)
	self:DrawPicture("main", x, y, w, h)

	-- Draw the thumb.
	ButtonStyleRender(self[_thumb], ThumbBox(self, x, y))
end

--- Succeeds if (cx, cy) is inside (x, y, w, h) or the thumb box, inside this rect.
-- @param cx Cursor x-coordinate.
-- @param cy Cursor y-coordinate.
-- @param x Bounding rect x-coordinate.
-- @param y Bounding rect y-coordinate.
-- @param w Bounding rect width.
-- @param h Bounding rect height.
-- @return On a successful test, returns the slider or thumb.
function Signals:test (cx, cy, x, y, w, h)
	if PointInBox(cx, cy, x, y, w, h) then
		return PointInBox(cx, cy, ThumbBox(self, x, y)) and self[_thumb] or self
	end
end

-- Slider class definition --
class.Define("Slider", function(Slider)
	--- Gets the current offset, which begins as 0.
	-- @return Slider offset, in [0, 1].
	-- @see Slider:SetOffset
	function Slider:GetOffset ()
		return self[_offset] or 0
	end

	--- Accessor.
	-- @return Thumb widget.
	function Slider:GetThumb ()
		return self[_thumb]
	end

	-- S: Slider handle
	-- offset: Offset to assign, in [0, 1]
	local function SetOffset (S, offset)
		S[_offset] = offset
	end

	--- Sets the current offset.<br><br>
	-- Offset changes will send signals as<br><br>
	-- &nbsp&nbsp&nbsp<b><i>signal(S, "set_offset")</i></b>,<br><br>
	-- where <i>signal</i> will be <b>switch_from</b> or <b>switch_to</b>, and <i>S</i>
	-- refers to this slider.
	-- @param offset Offset to assign.
	-- @param always_refresh If true, send the <b>"switch_to"</b> signal even when the offset
	-- does not change.
	-- @see Slider:GetOffset
	function Slider:SetOffset (offset, always_refresh)
		offset = ClampIn(offset, 0, 1)

		StateSwitch(self, offset ~= self:GetOffset(), always_refresh, SetOffset, "set_offset", offset)
	end
end,

--- Class constructor.
-- @class function
-- @name Constructor
-- @param group Group handle.
-- @param dist1 Thumb distance to left or top edge.
-- @param dist2 Thumb distance to right or bottom edge.
-- @param fixed Fixed distance in other coordinate.
-- @param tw Thumb width.
-- @param th Thumb height.
-- @param is_vertical If true, this is a vertical slider.
function(S, group, dist1, dist2, fixed, tw, th, is_vertical)
	SuperCons(S, "Widget", group)

	-- Distances between slide range and attach box edges --
	S[_dist1] = dist1
	S[_dist2] = dist2

	-- Distance between thumb and attach box edges perpendicular to slider bar --
	S[_fixed] = fixed

	-- Thumb dimensions --
	S[_tw] = tw
	S[_th] = th

	-- Slider orientation flag --
	S[_is_vertical] = not not is_vertical

	-- Thumb widget --
	S[_thumb] = New(u_ThumbName, S)

	-- Signals --
	S:SetMultipleSignals(Signals)
end, { base = "Widget" })