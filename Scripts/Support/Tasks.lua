-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local huge = math.huge
local insert = table.insert
local ipairs = ipairs
local min = math.min
local type = type

-- Imports --
local APairs = iterators.APairs
local ClearRange = varops.ClearRange
local GetEventStream = section.GetEventStream
local GetTimeLapseFunc = funcops.GetTimeLapseFunc
local IsCallable = varops.IsCallable
local New = class.New
local NoOp = funcops.NoOp

-- Cached routines --
local Sequence_

-- Export the tasks namespace.
module "tasks"

-- Adding of tasks --
do
	local Events

	-- Validates the event arguments
	-- events: If available, add events during validation
	-- first, ...: Stream names / events to add in sequence
	local function Validate (events, first, ...)
		local op = events and insert or NoOp

		-- The first item must be an event stream name, as will be any other strings.
		-- All events must be callable.
		GetEventStream(first)

		for _, event in APairs(...) do
			if type(event) ~= "string" then
				assert(IsCallable(event), "Uncallable event")

				op(events, event)

			else
				GetEventStream(event)
			end
		end
	end

	-- ...: Stream names / events to add
	-------------------------------------
	function AddEventBatch (...)
		-- Validate the arguments.
		Validate(nil, ...)

		-- Stream the events.
		local index, stream = 1

		for _, event in APairs(...) do
			if type(event) ~= "string" then
				stream:Add(event)

			else
				stream = GetEventStream()
			end
		end
	end

	-- ...: Stream names / events to add in sequence
	-------------------------------------------------
	function AddEventSequence (...)
		-- Grab the empty events list if available, setting it up otherwise. Unbind it
		-- in case of verification errors.
		local events = Events or {}

		Events = nil

		-- Validate the arguments and collect events.
		Validate(events, ...)

		-- Make the events into a sequence.
		Sequence(events, events)

		-- Stream the events.
		local index = 1
		local stream

		for _, event in APairs(...) do
			if type(event) ~= "string" then
				stream:Add(events[index])

				index = index + 1

			else
				stream = GetEventStream()
			end
		end

		-- Clear and restore the events list.
		ClearRange(events)

		Events = events
	end
end

-- Builds a task that persists until interruption
-- update: Update routine
-- quit: Optional quit routine
-- Returns: Task function
--------------------------------------------------
function PersistUntil (update, quit)
	assert(IsCallable(update), "Uncallable update function")
	assert(quit == nil or IsCallable(quit), "Uncallable quit function")

	local age = 0
	local diff = GetTimeLapseFunc("tasks")

	-- Build a persistent task.
	return function(arg)
		if not update(age, arg) then
			age = age + diff()

			return true
		end

		(quit or NoOp)(age, arg)
	end
end

-- Builds a group of tasks to be executed in sequence
-- t: Ordered group of tasks
-- out: Optional output table
-- Returns: Ordered group of dependent tasks
------------------------------------------------------
function Sequence (t, out)
	out = out or {}

	local cur = 1

	for i, task in ipairs(t) do
		assert(IsCallable(task), "Uncallable task")

		local this = i

		out[i] = function(arg)
			if this > cur or task(arg) ~= nil then
				return true

			else
				cur = cur + 1
			end
		end
	end

	return out
end

-- Builds an interpolating task
-- interpolator: Interpolator handle
-- prep: Optional preparation function
-- quit: Optional function called on quit
-- Returns: Task function
------------------------------------------
function WithInterpolator (interpolator, prep, quit)
	assert(prep == nil or IsCallable(prep), "Uncallable preparation function")
	assert(quit == nil or IsCallable(quit), "Uncallable quit function")

 	prep = prep or NoOp

	local diff = GetTimeLapseFunc("tasks")

	return function(arg)
		local lapse = diff()

		prep(interpolator, lapse, arg)

		if interpolator:GetMode() ~= "suspended" then
			interpolator(lapse)

			return true
		end

		(quit or NoOp)(arg)
	end
end

-- Configures a timer according to type
-- timer: Timer handle or task duration
-- Returns: Time lapse routine, timer
local function SetupTimer (timer)
	local diff

	if type(timer) == "number" then
		local duration = timer

		diff = GetTimeLapseFunc("tasks")
		timer = New("Timer")

		timer:Start(duration)
	end

	return diff, timer
end

-- Builds a task that triggers periodically
-- timer: Timer handle or task duration
-- func: Function called on timeout
-- quit: Optional function called on quit
-- just_once: If true, limit timeouts to one per run
-- Returns: Task function
-----------------------------------------------------
function WithPeriod (timer, func, quit, just_once)
	assert(IsCallable(func), "Uncallable function")
	assert(quit == nil or IsCallable(quit), "Uncallable quit function")

	local diff, timer = SetupTimer(timer)

	return function(arg)
		local duration = timer:GetDuration()

		if duration then
			for _ = 1, min(just_once and 1 or huge, timer:Check("continue")) do
				if func(timer:GetCounter(), duration, arg) then
					(quit or NoOp)(arg)

					return
				end
			end

			if diff then
				timer:Update(diff())
			end

			return true
		end
	end
end

-- Builds a task that persists until a time is passed
-- timeline: Optional timeline handle
-- func: Task function
-- quit: Optional function called when time is passed
-- time: Time value
-- is_absolute: If true, time is absolute
-- Returns: Task function
------------------------------------------------------
function WithTimeline (timeline, func, quit, time, is_absolute)
	assert(IsCallable(func), "Uncallable function")
	assert(quit == nil or IsCallable(quit), "Uncallable quit function")

	local diff

	-- Build a fresh timeline if one was not provided.
	if not timeline then
		diff = GetTimeLapseFunc("tasks")
		timeline = New("Timeline")
	end

	-- Adjust relative times.
	if not is_absolute then
		time = time + timeline:GetTime()
	end

	return function(arg)
		local when = timeline:GetTime()

		if when < time then
			func(timeline, when, time, arg)

			if diff then
				timeline(diff(), arg)
			end

			return true
		end

		(quit or NoOp)(arg)
	end
end

-- Builds a task that persists while a timer runs
-- timer: Timer handle or task duration
-- func: Task function
-- quit: Optional function called after timeout
-- Returns: Task function
--------------------------------------------------
function WithTimer (timer, func, quit)
	assert(IsCallable(func), "Uncallable function")
	assert(quit == nil or IsCallable(quit), "Uncallable quit function")

	local diff, timer = SetupTimer(timer)

	return function(arg)
		local duration = timer:GetDuration()

		if duration and timer:Check() == 0 then
			func(timer:GetCounter(), duration, arg)

			if diff then
				timer:Update(diff())
			end

			return true
		end

		(quit or NoOp)(arg)
	end
end

-- Cache some routines.
Sequence_ = Sequence