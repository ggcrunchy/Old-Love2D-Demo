-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local max = math.max

-- Export table --
local Export = ...

-- Unique spot class name --
local u_SpotName = {}

-- Unique member keys --
local _can_migrate = {}
local _index = {}
local _is_add_spot = {}
local _sequence = {}

-- S: Spot handle
-- Returns: If true, spot is valid
local function IsValid (S)
	return S[_sequence]:IsItemValid(S[_index], S[_is_add_spot])
end

-- Spot class definition --
class.Define(u_SpotName, function(Spot)
	--- Invalidates the spot.
	function Spot:Clear ()
		self[_index] = 0
	end

	--- Gets the position watched by the spot.
	-- @return The current position index, or <b>nil</b> if the spot is invalid.
	-- @see Spot:Set
	function Spot:Get ()
		if IsValid(self) then
			return self[_index]
		end
	end

	--- Assigns the spot a position in the sequence to watch.
	-- @param index Current position index.
	-- @see Spot:Get
	function Spot:Set (index)
		assert(self[_sequence]:IsItemValid(index, self[_is_add_spot]), "Invalid index")

		self[_index] = index
	end
end,

--- Class constructor.
-- @class function
-- @name Constructor
-- @param sequence Reference to owner sequence.
-- @param is_add_spot If true, this spot can occupy the position immediately after the
-- sequence.
-- @param can_migrate If true, this spot can migrate if the part of the sequence it
-- monitors is removed.
function(S, sequence, is_add_spot, can_migrate)
	-- Owner sequence --
	S[_sequence] = sequence

	-- Currently referenced sequence element --
	S[_index] = 1

	-- Flags --
	S[_is_add_spot] = not not is_add_spot
	S[_can_migrate] = not not can_migrate
end, { bHidden = true })

-- Updates the spot in response to a sequence insert
-- index: Index of insertion
-- count: Count of inserted items
function Export.SpotInsert (S, index, count)
	if IsValid(S) then
		-- Move the spot ahead if it follows the insertion.
		if S[_index] >= index then
			S[_index] = S[_index] + count
		end

		-- If the sequence was empty, the spot will follow it. Back up if this is illegal.
		if #S[_sequence] == 0 and not S[_is_add_spot] then
			S[_index] = S[_index] - 1
		end
	end
end

-- Updates the spot in response to a sequence insert
-- index: Index of first removed item
-- count: Count of removed items
function Export.SpotRemove (S, index, count)
	if IsValid(S) then
		-- If a spot follows the range, back up by the remove count.
		if S[_index] >= index + count then
			S[_index] = S[_index] - count

		-- Otherwise, handle removes within the range.
		elseif S[_index] >= index then
			if S[_can_migrate] then
				-- Migrate past the range.
				S[_index] = index

				-- If the range was at the end of the items, the spot will now be past the
				-- end. Back it up if this is illegal.
				if index + count == #S[_sequence] + 1 and not S[_is_add_spot] then
					S[_index] = max(index - 1, 1)
				end

			-- Clear non-migratory spots.
			else
				S:Clear()
			end
		end
	end
end

-- Export spot name.
Export.SpotName = u_SpotName