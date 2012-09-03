-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local max = math.max
local min = math.min

-- Imports --
local RangeOverlap = numericops.RangeOverlap

-- Export table --
local Export = ...

-- Unique interval class name --
local u_IntervalName = {}

-- Unique member keys --
local _count = {}
local _index = {}
local _sequence = {}
local _start = {}

-- Interval class definition --
class.Define(u_IntervalName, function(Interval)
	--- Clears the selection.
	function Interval:Clear ()
		self[_count] = 0
	end

	--- Gets the starting position of the interval.
	-- @return Current start index, or <b>nil</b> if empty.
	function Interval:GetStart ()
		return self[_count] > 0 and self[_start] or nil
	end

	--- Metamethod.
	-- @return Size of selected interval.
	function Interval:__len ()
		return self[_count]
	end

	--- Selects a range. The selection count is clamped against the sequence size.
	-- @param start Current index of start position.
	-- @param count Current size of range to select.
	function Interval:Set (start, count)
		self[_start] = start
		self[_count] = RangeOverlap(start, count, #self[_sequence])
	end
end,

--- Class constructor.
-- @class function
-- @name Constructor
-- @param sequence Reference to owner sequence.
function(I, sequence)
	-- Owner sequence --
	I[_sequence] = sequence

	-- Selection count --
	I[_count] = 0
end, { bHidden = true })

-- Updates the interval in response to a sequence insert
-- index: Index of insertion
-- count: Count of inserted items
function Export.IntervalInsert (I, index, count)
	if I[_count] > 0 then
		-- If an interval follows the insertion, move ahead by the insert count.
		if index < I[_start] then
			I[_start] = I[_start] + count

		-- If inserting into the interval, augment it by the insert count.
		elseif index < I[_start] + I[_count] then
			I[_count] = I[_count] + count
		end
	end
end

-- Updates the interval in response to a sequence remove
-- index: Index of first removed item
-- count: Count of removed items
function Export.IntervalRemove (I, index, count)
	if I[_count] > 0 then
		-- Reduce the interval count by its overlap with the removal.
		local endr = index + count
		local endi = I[_start] + I[_count]

		if endr > I[_start] and index < endi then
			I[_count] = I[_count] - min(endr, endi) + max(index, I[_start])
		end

		-- If the interval follows the point of removal, it must be moved back. Reduce its
		-- index by the lesser of the count and the point of removal/start distance.
		if I[_start] > index then
			I[_start] = max(I[_start] - count, index)
		end
	end
end

-- Export interval name.
Export.IntervalName = u_IntervalName