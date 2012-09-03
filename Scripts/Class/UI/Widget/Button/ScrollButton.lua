-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local type = type

-- Imports --
local IsType = class.IsType
local New = class.New
local SuperCons = class.SuperCons

-- Unique member keys --
local _frequency = {}
local _how = {}
local _target = {}
local _timeout = {}
local _timer = {}

-- S: Scroll button handle
-- count: Step count
local function Step (S, count)
	local frequency = S:GetFrequency()
	local target, how = S:GetTarget()

	for _ = 1, target and count or 0 do
		target:Signal("scroll", how, frequency)
	end
end

-- Stock signals --
local Signals = {}

---
function Signals:drop ()
	self[_timer]:Stop()
end

---
function Signals:grab ()
	self[_timer]:Start(self[_timeout])

	Step(self, 1)
end

---
Signals.render = widgetops.ButtonStyleRender

---
function Signals:update (dt)
	Step(self, self[_timer]:Check("continue"))

	self[_timer]:Update(dt)
end

-- ScrollButton class definition --
class.Define("ScrollButton", function(ScrollButton)
	-- Returns: Scroll frequency
	-----------------------------
	function ScrollButton:GetFrequency ()
		return self[_frequency] or 1
	end

	-- Returns: Target, scroll behavior
	------------------------------------
	function ScrollButton:GetTarget ()
		return self[_target], self[_how]
	end

	-- frequency: Scroll frequency to assign
	-----------------------------------------
	function ScrollButton:SetFrequency (frequency)
		self[_frequency] = frequency
	end

	-- target: Target handle to bind
	-- how: Scroll behavior
	---------------------------------
	function ScrollButton:SetTarget (target, how)
		assert(IsType(target, "Signalable"), "Unsignalable scroll target")

		if self[_target] then
			self[_target]:Signal("unbind_as_scroll_target", self, self[_how])
		end

		self[_target] = target
		self[_how] = how

		if target then
			target:Signal("bind_as_scroll_target", self, how)
		end
	end

	-- timeout: Timeout value to assign
	------------------------------------
	function ScrollButton:SetTimeout (timeout)
		assert(timeout == nil or (type(timeout) == "number" and timeout > 0), "Invalid timeout")

		self[_timeout] = timeout
	end
end,

--- Class constructor.
-- @class function
-- @name Constructor.
-- @param group Group handle.
function(S, group)
	SuperCons(S, "Widget", group)

	-- Scroll timer --
	S[_timer] = New("Timer")

	-- Signals --
	S:SetMultipleSignals(Signals)
end, { base = "Widget" })