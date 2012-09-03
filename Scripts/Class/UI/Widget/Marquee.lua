-- See TacoShell Copyright Notice in main folder of distribution

-- Imports --
local DrawString = widgetops.DrawString
local StringGetW = widgetops.StringGetW
local SuperCons = class.SuperCons

-- Unique member keys --
local _dx = {}
local _is_looping = {}
local _pos = {}
local _right_to_left = {}
local _speed = {}

-- Stock signals --
local Signals = {}

--- Draws the marquee background with picture <b>"main"</b> in (x, y, w, h).<br><br>
-- In the second phase, the enter logic passed to <b>UIGroup:Render</b> is first called.
-- If it returns a true value, the marquee text is drawn. <b>UIGroup:Render</b>'s leave
-- logic is called afterward.<br><br>
-- At the end, the <b>"frame"</b> picture is drawn with rect (x, y, w, h).
-- @param x Rect x-coordinate.
-- @param y Rect y-coordinate.
-- @param w Rect width.
-- @param h Rect height.
-- @param state Render state.
function Signals:render (x, y, w, h, state)
	self:DrawPicture("main", x, y, w, h)

	-- If the marquee is active, clip its border region and draw the offset string.
	if self:IsScrolling() then
		local bw, bh = self:GetBorder()

		if state("enter")(x + bw, y + bw, w - bw * 2, h - bh * 2) then
			local offset = self[_dx] + bw * 2
			local str = self:GetString()

			DrawString(self, str, nil, "center", x + (self[_right_to_left] and w - offset or offset - StringGetW(self, str)), y, w, h)

			state("leave")()
		end
	end

	-- Frame the marquee.
	self:DrawPicture("frame", x, y, w, h)
end

--- Updates scrolling.
-- @param dt Time lapse.
function Signals:update (dt)
	if self:IsScrolling() then
		self[_dx] = self[_pos]
		self[_pos] = self[_pos] + self[_speed] * dt

		-- If the string has left the marquee body, stop or loop it.
		local sum = self:GetW() - self:GetBorder() * 2 + StringGetW(self, self:GetString())

		if self[_dx] > sum then
			if self[_is_looping] then
				self[_dx] = self[_dx] % sum
				self[_pos] = self[_pos] % sum
			else
				self[_speed] = nil
			end
		end
	end
end

-- Marquee class definition --
class.Define("Marquee", function(Marquee)
	--- Status.
	-- @return If true, the marquee is scrolling.
	function Marquee:IsScrolling ()
		return self[_speed] ~= nil
	end

	--- Plays the marquee.
	-- @param speed Scroll speed.
	-- @param is_looping If true, the marquee will loop.
	function Marquee:Play (speed, is_looping)
		self[_is_looping] = not not is_looping
		self[_dx] = 0
		self[_pos] = 0
		self[_speed] = speed
	end

	--- Stops the marquee.
	function Marquee:Stop ()
		self[_speed] = nil
	end
end,

--- Class constructor.
-- @class function
-- @name Constructor
-- @param group Group handle.
-- @param right_to_left If true, the marquee scrolls right-to-left.
function(M, group, right_to_left)
	SuperCons(M, "Widget", group)

	-- Scroll direction --
	M[_right_to_left] = not not right_to_left

	-- Signals --
	M:SetMultipleSignals(Signals)
end, { base = "Widget" })