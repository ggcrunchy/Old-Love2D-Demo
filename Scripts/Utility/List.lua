-- See TacoShell Copyright Notice in main folder of distribution

-- Cached routines --
local _AddAfter
local _Back
local _RemoveFrom

-- List keys --
local _back = {}
local _next = {}
local _prev = {}

-- Export list namespace.
module "list"

-- Adds an entry after another in a list
-- head: List head
-- prev: List entry after which to append
-- entry: Entry to add
-- Returns: List head after addition
------------------------------------------
function AddAfter (head, prev, entry)
	-- Remove the entry if it is already in the list.
	head = _RemoveFrom(head, entry)

	-- Bind surrounding entries. If no previous entry was specified, prepend the entry.
	local next

	if prev then
		next = prev[_next]
		prev[_next] = entry
	else
		next = head
	end

	if next then
		next[_prev] = entry
	end

	entry[_prev] = prev
	entry[_next] = next

	-- If the entry was appended, the entry becomes the back.
	if head and head[_back] == prev then
		head[_back] = entry
	end

	-- If the entry was prepended or the list was empty, the entry becomes the head, and the
	-- back of the list is moved or assigned. Return the head.
	if head == next then
		if next then
			entry[_back] = next[_back]
			next[_back] = nil
		else
			entry[_back] = entry
		end
	end

	return head == next and entry or head
end

-- Adds an entry to the end of a list
-- head: List head
-- entry: Entry to add
-- Returns: List head after addition
--------------------------------------
function Append (head, entry)
	return _AddAfter(head, _Back(head), entry)
end

-- Gets the back entry of a list
-- head: List head
-- Returns: Back entry
---------------------------------
function Back (head)
	if head then
		return head[_back]
	end
end

-- Gets the next entry
-- entry: Entry
-- Returns: Next entry
---------------------------
function Next (entry)
	return entry[_next]
end

-- Gets the size of a list
-- head: List head
-- Returns: List size
---------------------------
function GetSize (head)
	local count = 0

	while head do
		head = head[_next]
		count = count + 1
	end

	return count
end

-- Gets the previous entry
-- entry: Entry
-- Returns: Previous entry
---------------------------
function Prev (entry)
	return entry[_prev]
end

-- Removes an entry from a list
-- head: List head
-- entry: Entry to remove
-- Returns: List head after removal
------------------------------------
function RemoveFrom (head, entry)
	if head then
		-- Remove references to and from the entry.
		local prev = entry[_prev]
		local next = entry[_next]

		if prev then
			prev[_next] = next
			entry[_prev] = nil
		end

		if next then
			next[_prev] = prev
			entry[_next] = nil
		end

		-- If the entry is the back of the list, the previous entry becomes the back.
		if entry == head[_back] then
			head[_back] = prev
		end

		-- If the head was removed, the next entry becomes the head. Return the head.
		if entry == head then
			if next then
				next[_back] = head[_back]
			end

			head[_back] = nil

			head = next
		end
	end

	return head
end

do
	-- Body for back-to-front iterator
	-- head: List head
	-- entry: List entry
	-- Returns: List entry
	local function BackToFront (head, entry)
		if entry then
			return entry[_prev]
		end

		return _Back(head)
	end

	-- Builds a back-to-front iterator over a list
	-- head: List head
	-- Returns: Iterator which supplies list entry
	-----------------------------------------------
	function BackToFrontIter (head)
		return BackToFront, head
	end
end

do
	-- Body for front-to-back iterator
	-- head: List head
	-- entry: List entry
	-- Returns: List entry
	local function FrontToBack (head, entry)
		if entry then
			return entry[_next]
		end

		return head
	end

	-- Builds a front-to-back iterator over a list
	-- head: List head
	-- Returns: Iterator which supplies list entry
	-----------------------------------------------
	function FrontToBackIter (head)
		return FrontToBack, head
	end
end

-- Cache some routines.
_AddAfter, _Back, _RemoveFrom = AddAfter, Back, RemoveFrom