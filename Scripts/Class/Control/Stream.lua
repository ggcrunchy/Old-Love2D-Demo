-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local insert = table.insert

-- Imports --
local CullingForEach = table_ex.CullingForEach
local MapArrayEx = table_ex.MapArrayEx
local Move = table_ex.Move
local WithBoundTable = table_ex.WithBoundTable
local WithResource = funcops.WithResource

-- Unique member keys --
local _fetch = {}
local _is_running = {}
local _tasks = {}

-- Stream class definition --
class.Define("Stream", function(Stream)
	-- Adds a new task
	-- task: Task to add
	---------------------
	function Stream:Add (task)
		insert(self[_fetch], task)
	end

	-- Stream visitor
	-- task: Task to invoke
	-- arg: Run argument
	-- Returns: If true, keep the task
	local function OnEach (task, arg)
		return task(arg) ~= nil
	end

	-- Resource usage
	-- S: Stream handle
	-- arg: Run argument
	local function Run (S, arg)
		S[_is_running] = true

		-- Fetch recently added tasks.
		WithBoundTable(S[_tasks], Move, S[_fetch], "append")

		-- Run the tasks; keep ones returning a valid result.
		CullingForEach(S[_tasks], OnEach, arg, true)
	end

	-- Resource release
	-- S: Stream handle
	local function Release (S)
		S[_is_running] = false
	end

	-- Performs pending tasks
	-- arg: Run argument
	--------------------------
	function Stream:__call (arg)
		assert(not self[_is_running], "Stream mapping or already running")

		WithResource(nil, Run, Release, self, arg)
	end

	-- Clears the stream
	---------------------
	function Stream:Clear ()
		assert(not self[_is_running], "Clear forbidden during map or run")

		self[_fetch] = {}
		self[_tasks] = {}
	end

	-- Returns: Task count
	-----------------------
	function Stream:__len ()
		return #self[_tasks] + #self[_fetch]
	end

	-- Resource usage
	-- S: Stream handle
	-- map: Mapping routine
	local function Mapping (S, map)
		local list = S[_is_running] == 1 and _tasks or _fetch

		-- Map the current list.
		S[list] = MapArrayEx(S[list], map)
	end

	-- Maps the stream elements
	-- map: Mapping routine
	-- do_fetch: If true, map the fetch list too
	---------------------------------------------
	function Stream:Map (map, do_fetch)
		assert(not self[_is_running], "Stream running or already mapping")

		-- Map each requested list.
		for i = 1, do_fetch and 2 or 1 do
			self[_is_running] = i

			WithResource(nil, Mapping, Release, self, map)
		end
	end
end,

--- Class constructor.
-- @class function
-- @name Constructor.
function(S)
	S:Clear()
end)