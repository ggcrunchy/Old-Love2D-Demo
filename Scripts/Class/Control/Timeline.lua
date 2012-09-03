-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local insert = table.insert
local ipairs = ipairs
local sort = table.sort
local type = type

-- Imports --
local IsCallable = varops.IsCallable
local Move = table_ex.Move
local WithBoundTable = table_ex.WithBoundTable
local WithResource = funcops.WithResource

-- Unique member keys --
local _events = {}
local _fetch = {}
local _is_updating = {}
local _queue = {}
local _time = {}

-- Timeline class definition --
class.Define("Timeline", function(Timeline)
	--- Adds an event to the timeline.<br><br>
	-- Events are placed in a fetch list, and thus will not take effect during an update.
	-- @param when Time when event occurs.
	-- @param event Event function, which is called as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>event(when, arg)</b></i>,<br><br>
	-- where <i>when</i> matches the event time and <i>arg</i> is the argument to <b>
	-- Timeline:__call</b>.
	-- @see Timeline:__call
	function Timeline:Add (when, event)
		assert(type(when) == "number" and when >= 0, "Invalid time")
		assert(IsCallable(event), "Uncallable event")

		insert(self[_fetch], { when, event })
	end

	-- event1, event2: Events to compare
	-- Returns: If true, event1 is later than event2
	local function EventCompare (event1, event2)
		return event1[1] > event2[1]
	end

	-- Enqueues future events
	-- T: Timeline handle
	local function BuildQueue (T)
		local begin = T[_time]
		local queue = {}

		for i, event in ipairs(T[_events]) do
			if event[1] < begin then
				break
			end

			queue[i] = event
		end

		T[_queue] = queue
	end

	-- Resource usage
	-- T: Timeline handle
	-- step: Time step
	-- arg: Update argument
	local function Use (T, step, arg)
		T[_is_updating] = true

		-- Merge in any new events.
		if #T[_fetch] > 0 then
			sort(WithBoundTable(T[_events], Move, T[_fetch], "append"), EventCompare)

			-- Rebuild the queue with the new events.
			BuildQueue(T)
		end

		-- Issue all events, in order. The queue is reacquired on each pass, since events
		-- may rebuild it via gotos.
		while true do
			local after = T[_time] + step
			local queue = T[_queue]

			-- Acquire the next event. If there is none or it comes too late, quit.
			local event = queue[#queue]

			if not event or event[1] >= after then
				break
			end

			local when = event[1]

			-- Advance the time to the event and diminish the time step.
			T[_time] = when

			step = after - when

			-- Issue the event and move on to the next one.
			event[2](when, arg)

			queue[#queue] = nil
		end

		-- Issue the final time advancement.
		T[_time] = T[_time] + step
	end

	-- Resource release
	-- T: Timeline handle
	local function Release (T)
		T[_is_updating] = false
	end

	--- Metamethod.<br><br>
	-- Updates the timeline, issuing in order any events scheduled during the step.<br><br>
	-- Before the update, any events in the fetch list are first merged into the event
	-- list.<br><br>
	-- If an event calls <b>Timeline:GoTo</b> on this timeline, updating will resume
	-- at the new time and 
	-- @param step Time step.
	-- @param arg Argument to event functions.
	-- @see Timeline:GoTo
	function Timeline:__call (step, arg)
		assert(not self[_is_updating], "Timeline already updating")

		WithResource(nil, Use, Release, self, step, arg)
	end

	--- Clears the timeline's fetch and event lists.<br><br>
	-- It is an error to call this during an update.
	function Timeline:Clear ()
		assert(not self[_is_updating], "Clear forbidden during update")

		self[_events] = {}
		self[_fetch] = {}
		self[_queue] = {}
	end

	--- Accessor.
	-- @return Current time.
	function Timeline:GetTime ()
		return self[_time]
	end

	--- Sets the timeline to a given time.
	-- @param when Time to assign.
	-- @see Timeline:GetTime
	function Timeline:GoTo (when)
		assert(type(when) == "number" and when >= 0, "Invalid time")

		self[_time] = when

		BuildQueue(self)
	end

	--- Metamethod.
	-- @return Event count.
	function Timeline:__len ()
		return #self[_events] + #self[_fetch]
	end
end,

--- Class constructor.
-- @class function
-- @name Constructor
function (T)
	T[_time] = 0

	T:Clear()
end)