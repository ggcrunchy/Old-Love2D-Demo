-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local pairs = pairs

-- Imports --
local IntervalInsert = (...).IntervalInsert
local IntervalRemove = (...).IntervalRemove
local New = class.New
local RangeOverlap = numericops.RangeOverlap
local SpotInsert = (...).SpotInsert
local SpotRemove = (...).SpotRemove
local Weak = table_ex.Weak

-- Private class names --
local IntervalName = (...).IntervalName
local SpotName = (...).SpotName

-- Unique member keys --
local _insert = {}
local _intervals = {}
local _remove = {}
local _size = {}
local _spots = {}

-- Sequence class definition --
class.Define("Sequence", function(Sequence)
	-- Creates an interval on the sequence
	-- Returns: Interval handle
	---------------------------------------
	function Sequence:CreateInterval ()
		local interval = New(IntervalName, self)

		self[_intervals][interval] = true

		return interval
	end

	-- Creates a spot on the sequence
	-- is_add_spot: If true, spot can be immediately after the sequence
	-- can_migrate: If true, spot can migrate on removal
	-- Returns: Spot handle
	--------------------------------------------------------------------
	function Sequence:CreateSpot (is_add_spot, can_migrate)
		local spot = New(SpotName, self, is_add_spot, can_migrate)

		self[_spots][spot] = true

		return spot
	end

	-- Inserts new items
	-- index: Insertion index
	-- count: Count of items to add
	-- ...: Insertion arguments
	--------------------------------
	function Sequence:Insert (index, count, ...)
		assert(self:IsItemValid(index, true) and count > 0)

		-- Update the intervals and spots to reflect the change.
		for interval in pairs(self[_intervals]) do
			IntervalInsert(interval, index, count)
		end

		for spot in pairs(self[_spots]) do
			SpotInsert(spot, index, count)
		end

		-- Perform the insertion.
		self[_insert](index, count, ...)
	end

	-- index: Index of item in sequence
	-- is_addable: If true, the end of the sequence is valid
	-- Returns: If true, the item is valid
	---------------------------------------------------------
	function Sequence:IsItemValid (index, is_addable)
		return index > 0 and index <= self[_size]() + (is_addable and 1 or 0)
	end

	-- Returns: Item count
	-----------------------
	function Sequence:__len ()
		return self[_size]()
	end

	-- Removes a series of items
	-- index: Removal index
	-- count: Count of items to remove
	-- ...: Removal arguments
	-- Returns: Count of items removed
	-----------------------------------
	function Sequence:Remove (index, count, ...)
		count = RangeOverlap(index, count, self[_size]())

		-- Update the intervals and spots to reflect the change.
		if count > 0 then
			for interval in pairs(self[_intervals]) do
				IntervalRemove(interval, index, count)
			end

			for spot in pairs(self[_spots]) do
				SpotRemove(spot, index, count)
			end

			-- Perform the removal.
			self[_remove](index, count, ...)
		end

		return count
	end
end,

--- Class constructor.
-- @class function
-- @name Constructor.
-- @param size Size routine.
-- @param insert Insert routine.
-- @param remove Remove routine.
function(S, size, insert, remove)
	-- Sequence operations --
	S[_insert] = insert
	S[_remove] = remove
	S[_size] = size

	-- Owned intervals --
	S[_intervals] = Weak("k")

	-- Owned spots --
	S[_spots] = Weak("k")
end)