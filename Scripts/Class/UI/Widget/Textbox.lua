-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local ipairs = ipairs
local gmatch = string.gmatch
local yield = coroutine.yield

-- Imports --
local ClearRange = varops.ClearRange
local Create = coroutine_ex.Create
local DrawString = widgetops.DrawString
local New = class.New
local NoOp = funcops.NoOp
local Reset = coroutine_ex.Reset
local StringGetH = widgetops.StringGetH
local StringGetW = widgetops.StringGetW
local SuperCons = class.SuperCons
local SwapIf = numericops.SwapIf

-- Cached methods --
local SetString = class.GetMember("Widget", "SetString")

-- Unique member keys --
local _emit_rate = {}
local _idle = {}
local _iter = {}
local _lines = {}
local _timer = {}

-- Iterator body
-- T: Textbox handle
local function Body (T)
	-- Run the character emit timer.
	T[_timer]:Start(T[_emit_rate])

	-- Lay out the description text line by line.
	local lines = T[_lines]
	local count = 0
	local w = T:GetW()

	for word in gmatch(T:GetString() or "", "[%w%p]+%s*") do
		-- If no lines have yet been added or the current line will run off the border,
		-- start a new line.
		if #lines == 0 or StringGetW(T, lines[#lines] .. word) >= w then
			lines[#lines + 1] = ""
		end

		-- Add each character from the word to the current line. Wait for characters
		-- whenever the count runs out.
		for char in gmatch(word, ".") do		
			-- TODO: Reorganize this slightly to allow for run-to-counter
			while count == 0 do
				count = T[_timer]:Check("continue")

				yield()
			end

			lines[#lines] = lines[#lines] .. char

			count = count - 1
		end
	end

	-- Go idle.
	T[_idle], T[_iter] = T[_iter], T[_idle]
end

-- Reset logic
-- T: Textbox handle
local function OnReset (T)
	ClearRange(T[_lines])
end

-- Stock signals --
local Signals = {}

--- The <b>"main"</b> picture is drawn with rect (x, y, w, h). All of the current text is
-- then drawn. Finally, the <b>"frame"</b> picture is drawn with rect (x, y, w, h).
-- @param x Rect x-coordinate.
-- @param y Rect y-coordinate.
-- @param w Rect width.
-- @param h Rect height.
function Signals:render (x, y, w, h)
	self:DrawPicture("main", x, y, w, h)

	-- Draw the substrings.
	for _, line in ipairs(self[_lines]) do
		DrawString(self, line, "left", "top", x, y)

		y = y + StringGetH(self, line, true)
	end

	-- Frame the textbox.
	self:DrawPicture("frame", x, y, w, h)
end

--- Updates character emissions.
-- @param dt Time lapse.
function Signals:update (dt)
	self[_iter](self)

	self[_timer]:Update(dt)
end

-- Textbox class definition --
class.Define("Textbox", function(Textbox)
	--- Indicates whether the textbox is still emitting text or is now idle.
	-- @return If true, the box is active.
	function Textbox:IsActive ()
		return self[_iter] ~= NoOp
	end

	-- TODO: SetFont override -> Cache counter, re-emit up to it

	--- Override of <b>Widget:SetString</b>. Resets emission with the new string.
	-- @param str String to assign.
	function Textbox:SetString (str)
		SetString(self, str)

		self[_idle], self[_iter] = SwapIf(self[_iter] == NoOp, self[_idle], self[_iter])

		Reset(self[_iter], self)
	end
end,

--- Class constructor.
-- @class function
-- @name Constructor
-- @param group Group handle.
-- @param emit_rate Delay, in seconds, between character emissions.
function(T, group, emit_rate)
	SuperCons(T, "Widget", group)

	-- Character emit delay --
	T[_emit_rate] = emit_rate

	-- Idle behavior --
	T[_idle] = NoOp

	-- Active behavior --
	T[_iter] = Create(Body, OnReset)

	-- Current text --
	T[_lines] = {}

	-- Emit timer --
	T[_timer] = New("Timer")

	-- Signals --
	T:SetMultipleSignals(Signals)
end, { base = "Widget" })