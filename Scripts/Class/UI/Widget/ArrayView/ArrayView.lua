-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local insert = table.insert
local max = math.max
local min = math.min
local remove = table.remove
local unpack = unpack

-- Imports --
local CallOrGet = funcops.CallOrGet
local ClearRange = varops.ClearRange
local CollectArgsInto = varops.CollectArgsInto
local New = class.New
local NewArray = class.NewArray
local SuperCons = class.SuperCons

-- Unique member keys --
local _array = {}

-- Part class definition --
local u_PartName = widgetops.DefineOwnedWidget()

-- Entry cache --
local Cache = {}

-- Inserts items into the array
-- index: Insertion index
-- count: Count of items to insert
-- A: Array handle
-- ...: Entry members
local function Insert (index, count, A, ...)
	local array = A[_array]

	for i = index, index + count - 1 do
		local entry = remove(Cache) or { n = 0 }

		entry.n = CollectArgsInto(entry, ...)

		insert(array, i, entry)
	end
end

-- Removes items from the array
-- index: Removal index
-- count: Count of items to remove
-- A: Array handle
local function Remove (index, count, A)
	local array = A[_array]

	for i = index + count - 1, index, -1 do
		local entry = remove(array, i)

		ClearRange(entry, 1, entry.n)

		Cache[#Cache + 1] = entry
	end
end

-- entry: Entry
-- Returns: Entry members
local function GetEntry (entry)
	return CallOrGet(entry[1]), unpack(entry, 2, entry.n)
end

-- Array iterator
-- state: Iterator state: array, final index
-- index: Entry index
-- Returns: Index, entry members
local function Iter (state, index)
	if index + 1 < state[2] then
		local entry = state[1][index + 1]

		if entry then
			return index + 1, GetEntry(entry)
		end
	end
end

---
-- @class function
-- @name Signals:scroll
-- A: Array handle
-- how: Scroll behavior
-- frequency: Scroll frequency

local function Scroll (A, how, frequency)
	if how == "up" then
		A.offset:Set(max(A.offset:Get() - frequency, 1))
	elseif how == "down" then
		A.offset:Set(min(A.offset:Get() + frequency, #A[_array] - frequency + 1))
	end
end

-- Array class definition --
class.Define("ArrayView", function(ArrayView)
	-- Adds an entry
	-- index: Entry index
	-- ...: Entry members
	----------------------
	function ArrayView:AddEntry (index, ...)
		self.sequence:Insert(index, 1, self, ...)
	end

	-- Clears all entries
	----------------------
	function ArrayView:Clear ()
		self.sequence:Remove(1, #self[_array], self)
	end

	-- index: Entry index
	-- Returns: Entry members
	--------------------------
	function ArrayView:GetEntry (index)
		local entry = self[_array][index]

		if entry then
			return GetEntry(entry)
		end
	end

	-- Builds an iterator over the array
	-- start: Start index; if nil, set to 1
	-- count: Range count; if nil, set to entry count
	-- Returns: Iterator which returns index, entry members
	--------------------------------------------------------
	ArrayView.Iter = iterators.CachedCallback(function()
		local array, final

		-- Body --
		return function(_, i)
			return i + 1, GetEntry(array[i + 1])
		end,

		-- Done --
		function(_, i)
			return i + 1 >= final or i >= #array
		end,

		-- Setup --
		function(A, start, count)
			array = A[_array]
			start = start or 1
			count = count or #array
			final = start + count

			return nil, start - 1
		end,

		-- Reclaim --
		function()
			array = nil
		end
	end)

	-- Returns: Entry count
	------------------------
	function ArrayView:__len ()
		return #self[_array]
	end

	-- Removes an entry
	-- index: Entry index
	----------------------
	function ArrayView:RemoveEntry (index)
		self.sequence:Remove(index, 1, self)
	end

	-- Builds an iterator over the viewable items
	-- Returns: Iterator which returns index, entry members
	--------------------------------------------------------
	function ArrayView:View ()
		return self:Iter(self.offset:Get(), #self.view)
	end
end,

-- Class constructor.
-- @class function
-- @name Constructor.
-- @param group Group handle.
-- @param capacity Array capacity.
function(A, group, capacity)
	SuperCons(A, "Widget", group)

	-- Entry sequence --
	A.sequence = New("Sequence", function()
		return #A[_array]
	end, Insert, Remove)

	-- Position offset --
	A.offset = A.sequence:CreateSpot(false, true)

	-- Entry array --
	A[_array] = {}

	-- View array --
	A.view = NewArray(u_PartName, capacity, A)

	-- Signals --
	A:SetSignal("scroll", Scroll)
end, { base = "Widget" })