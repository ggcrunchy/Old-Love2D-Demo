-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local pairs = pairs
local setmetatable = setmetatable
local unpack = unpack

-- Imports --
local CallOrGet = funcops.CallOrGet
local CollectArgsInto = varops.CollectArgsInto
local Execute = windows.Execute
local FocusChain = windows.FocusChain
local GetLanguage = settings.GetLanguage
local GetSize = windows.GetSize
local IsCallable = varops.IsCallable
local New = class.New
local NoOp = funcops.NoOp
local PurgeAttachList = widgetops.PurgeAttachList
local Render = windows.Render
local SectionGroup = windows.SectionGroup
local UIGroup = windows.UIGroup

-- Cached routines --
local CleanupEventStreams_
local GetEventStream_
local GetLookup_
local SetLookupTable_

-- Event streams --
local Streams = {}

for _, when in iterators.APairs("enter_render", "leave_render", "enter_trap", "leave_trap", "enter_update", "leave_update", "between_frames") do
	Streams[when] = {}
end

-- Export section namespace.
module "section"

-- Section lookup tables --
local Lookups = {}

do
	-- Cleanup argument --
	local Arg

	-- Cleanup descriptor --
	local How

	-- Default function for unmarked tasks --
	local DefFunc

	-- Task marks --
	local Marks = setmetatable({}, {
		__index = function()
			return DefFunc
		end,
		__mode = "k"
	})

	-- Stream cleanup helper
	-- task: Stream task
	-- Returns: Task, or nil
	local function Cleanup (task)
		return Marks[task](task, How, Arg)
	end

	-- streams: Stream set
	-- all_groups: If true, get streams in all section groups
	-- Returns: Cleanup iterator
	local function GetIterator (streams, all_groups)
		if all_groups then
			return pairs(streams)

		else
			local stream = streams[SectionGroup()]

			return stream and One or NoOp, stream
		end
	end

	-- Cleans up event streams before major switches
	-- how: Event cleanup descriptor
	-- all_groups: If true, cleanup streams in all section groups
	-- def_func: Optional function to call on unmarked tasks
	-- omit: Optional stream to ignore during cleanup
	-- arg: Cleanup argument
	--------------------------------------------------------------
	function CleanupEventStreams (how, all_groups, def_func, omit, arg)
		assert(def_func == nil or IsCallable(def_func), "Invalid default function")

		Arg = arg
		How = how
		DefFunc = def_func ~= nil and def_func or NoOp

		for name, streams in pairs(Streams) do
			if name ~= omit then
				for _, stream in GetIterator(streams, all_groups) do
					stream:Map(Cleanup, true)
				end
			end
		end
	end

	-- Marks a task with a function to call on cleanup
	-- task: Task to mark
	-- cleanup: Cleanup function
	---------------------------------------------------
	function MarkTask (task, cleanup)
		assert(IsCallable(task), "Uncallable task")
		assert(IsCallable(cleanup), "Uncallable cleanup function")

		Marks[task] = cleanup
	end
end

-- Builds a section close routine
-- name: Section name
-- ...: Arguments to section close
-- Returns: Closure to close section
-------------------------------------
function Closer (name, ...)
	local stream = GetEventStream_("between_frames")
	local count, args = CollectArgsInto(nil, ...)

	return function()
		stream:Add(function()
			SectionGroup():Close(CallOrGet(name), unpack(args, 1, count))
		end)
	end
end

-- Gets a section group's event stream
-- event: Event name
-- index: Optional group index
-- Returns: Stream handle
---------------------------------------
function GetEventStream (event, index)
	local sg = SectionGroup(index)
	local set = assert(Streams[event or 0], "Invalid event stream")

	set[sg] = set[sg] or New("Stream")

	return set[sg]
end

-- Gets a section's lookup set
-- data: Section data
-- Returns: Lookup set in the current language
-----------------------------------------------
function GetLookup (data)
	local table = Lookups[data]

	return table and table[GetLanguage()] or nil
end

-- Loads a section, handling common functionality
-- name: Section name
-- proc: Section procedure
-- lookup: Optional lookup table
-- ...: Load arguments
--------------------------------------------------
function Load (name, proc, lookup, ...)
	local sg = SectionGroup()
	local uig = UIGroup()
	local data = {}

	-- Wrap the procedure in a routine that handles common logic. Load the section.
	sg:Load(name, function(state, arg1, ...)
		-- On close, detach the pane.
		if state == "close" then
			if data.pane then
				PurgeAttachList(data.pane)

				data.pane:Detach()
			end

			-- Remove current focus items.
			local chain = FocusChain(data, true)

			if chain then
				chain:Clear()
			end

			-- Sift out section-specific messages.
			CleanupEventStreams_("close_section", false, nil, "between_frames", name)

		-- On load, register any lookup table.
		elseif state == "load" then
			SetLookupTable_(data, lookup)

		-- On render, draw the UI.
		elseif state == "render" then
			(Streams.enter_render[sg] or NoOp)(data)

			Render(uig);

			(Streams.leave_render[sg] or NoOp)(data)

		-- On trap, direct input to the UI.
		elseif state == "trap" then
			(Streams.enter_trap[sg] or NoOp)(data)

			if not data.blocked then
				Execute(uig, data)
			end

			(Streams.leave_trap[sg] or NoOp)(data)

		-- On update, update the UI. (arg1: time lapse)
		elseif state == "update" then
			(Streams.enter_update[sg] or NoOp)(data)

			uig:Update(arg1);

			(Streams.leave_update[sg] or NoOp)(data)
		end

		-- Do section-specific logic.
		return proc(state, data, arg1, ...)
	end, ...)
end

-- Builds a section dialog open routine
-- name: Section name
-- ...: Arguments to section enter
-- Returns: Closure to open dialog
----------------------------------------
function OpenDialog (name, ...)
	local stream = GetEventStream_("between_frames")
	local count, args = CollectArgsInto(nil, ...)

	return function()
		stream:Add(function()
			UIGroup():Clear()

			SectionGroup():Open(CallOrGet(name), unpack(args, 1, count))
		end)
	end
end

-- Builds a section screen open routine
-- name: Section name
-- ...: Arguments to section enter
-- Returns: Closure to open screen
----------------------------------------
function OpenScreen (name, ...)
	local stream = GetEventStream_("between_frames")
	local count, args = CollectArgsInto(nil, ...)

	return function()
		stream:Add(function()
			UIGroup():Clear()
			SectionGroup():Clear()

			SectionGroup():Open(CallOrGet(name), unpack(args, 1, count))
		end)
	end
end

-- Opens a single-level section; closes other sections
-- name: Section name
-- ...: Arguments to section enter
-------------------------------------------------------
function Screen (name, ...)
	local count, args = CollectArgsInto(nil, ...)

	GetEventStream_("between_frames"):Add(function()
		UIGroup():Clear()
		SectionGroup():Clear()

		SectionGroup():Open(name, unpack(args, 1, count))
	end)
end

-- Sets the section's lookup table
-- data: Section data
-- lookup: Lookup table
-----------------------------------
function SetLookupTable (data, lookup)
	Lookups[data] = lookup
end

-- Does standard setup for screen sections
-- data: Section data
-- Returns: Lookup set in the current language
-----------------------------------------------
function SetupScreen (data)
	UIGroup():GetRoot():Attach(data.pane, 0, 0, GetSize())

	return GetLookup_(data)
end

-- Cache some routines.
CleanupEventStreams_ = CleanupEventStreams
GetEventStream_ = GetEventStream
GetLookup_ = GetLookup
SetLookupTable_ = SetLookupTable