-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local pairs = pairs
local remove = table.remove

-- Imports --
local Find = table_ex.Find
local New = class.New

-- Unique member keys --
local _sections = {}
local _stack = {}

-- Internal proc states --
local Internal = table_ex.MakeSet{
	"load", "unload",
	"move",
	"open", "close",
	"resume", "suspend"
}

-- SectionGroup class definition --
class.Define("SectionGroup", function(MT)
	-- Calls a section proc
	-- section: Section
	-- state: Proc state
	-- ...: Proc arguments
	-- Returns: Call results
	local function Proc (section, state, ...)
		if section then
			return section(state, ...)
		end
	end

	-- Calls the current section proc
	-- state: Proc state
	-- ...: Proc arguments
	----------------------------------
	function MT:__call (state, ...)
		assert(state ~= nil, "state == nil")
		assert(not Internal[state], "Cannot call proc with internal state")

		local stack = self[_stack]

		Proc(stack[#stack], state, ...)
	end

	-- Removes a section from the stack
	-- G: Section group handle
	-- where: Stack position
	-- type: Removal type
	-- ...: Remove arguments
	local function Remove (G, where, type, ...)
		Proc(remove(G[_stack], where), type, ...)
	end

	-- Clears the group
	--------------------
	function MT:Clear ()
		local stack = self[_stack]

		while #stack > 0 do
			Remove(self, nil, "close", true)
		end
	end

	-- G: Section group handle
	-- name: Section name
	-- Returns: Named section
	local function GetSection (G, name)
		return assert(G[_sections][name], "Section does not exist")
	end

	-- Closes an active section
	-- name: Section name; nil for current section
	-- ...: Close arguments
	-----------------------------------------------
	function MT:Close (name, ...)
		local stack = self[_stack]

		-- Close the section if it was loaded.
		local where = name == nil and #stack or Find(stack, GetSection(self, name), true)

		if where and where > 0 then
			Remove(self, where, "close", false, ...)

			-- If the section was topmost, resume the lower section, if it exists.
			if where == #stack + 1 then
				Proc(stack[#stack], "resume")
			end
		end
	end

	-- Returns: Current section name
	---------------------------------
	function MT:Current ()
		local stack = self[_stack]

		return Find(self[_sections], stack[#stack])
	end

	-- name: Section name
	-- Returns: If true, section is open
	-------------------------------------
	function MT:IsOpen (name)
		assert(name ~= nil)

		return not not Find(self[_stack], self[_sections][name], true)
	end

	-- name: Section name
	-- proc: Section procedure
	-- ...: Load arguments
	---------------------------
	function MT:Load (name, proc, ...)
		assert(name ~= nil)

		-- Unload any section already loaded under the given name.
		Proc(self[_sections][name], "unload")

		-- Install the section.
		self[_sections][name] = proc

		-- Load the section.
		proc("load", ...)
	end

	-- Opens a section
	-- name: Section name
	-- ...: Open arguments
	-----------------------
	function MT:Open (name, ...)
		assert(name ~= nil)

		local stack = self[_stack]
		local section = GetSection(self, name)

		-- Proceed if the section is not already topmost, suspending any current section.
		local top = stack[#stack]

		if top ~= section then
			Proc(top, "suspend")

			-- If the section is already loaded, report the move.
			local where = Find(stack, section, true)

			if where then
				Remove(self, where, "move")
			end

			-- Push the section onto the stack.
			stack[#stack + 1] = section

			-- Open the section.
			section("open", ...)
		end
	end

	-- Sends a message to a section
	-- name: Section name
	-- what: Message
	-- ...: Payload
	-- Returns: Section response
	--------------------------------
	function MT:Send (name, what, ...)
		assert(name ~= nil)
		assert(what ~= nil)

		return GetSection(self, name)(what, ...)
	end

	-- Unloads all registered sections
	-- ...: Unload arguments
	-----------------------------------
	function MT:Unload (...)
		self[_stack] = {}

		for name, section in pairs(self[_sections]) do
			self[_sections][name] = nil

			section("unload", ...)
		end
	end
end, 

-- Constructor
---------------
function(G)
	G[_sections] = {}
	G[_stack] = {}
end)