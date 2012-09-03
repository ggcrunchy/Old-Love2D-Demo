-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local getmetatable = getmetatable
local ipairs = ipairs
local next = next
local pairs = pairs
local rawequal = rawequal
local rawget = rawget
local remove = table.remove
local setmetatable = setmetatable
local sort = table.sort
local type = type
local unpack = unpack

-- Imports --
local APairs = iterators.APairs
local ClearRange = varops.ClearRange
local CollectArgsInto = varops.CollectArgsInto
local Identity = funcops.Identity
local IsCallable = varops.IsCallable
local IsNaN = varops.IsNaN
local UnpackClearAndRecache = varops.UnpackClearAndRecache

-- Cached routines --
local Copy_
local DeepCopy_
local Map_
local WithBoundTable_

-- Routine used to consume tables --
local GetTable

-- Export the table_ex namespace.
module "table_ex"

--- Shallow-copies a table.
-- @param t Table to copy.
-- @param how Copy behavior, as per <b>Map</b>.
-- @param how_arg Copy behavior, as per <b>Map</b>.
-- @return Copy.
-- @see Map
-- @see WithBoundTable
function Copy (t, how, how_arg)
    return Map_(t, Identity, how, nil, how_arg)
end

--- Copies all values with the given keys into a second table with those keys.
-- @param t Table to copy.
-- @param keys Key array.
-- @return Copy.
-- @see WithBoundTable
function CopyK (t, keys)
    local dt = GetTable()

    for _, k in ipairs(keys) do
        dt[k] = t[k]
    end

    return dt
end

--- Visits each entry of an array in order, removing unwanted entries. Entries are moved
-- down to fill in gaps.
-- @param t Table to cull.
-- @param func Visitor function called as<br><br>
-- &nbsp&nbsp&nbsp<i><b>func(entry, arg)</b></i>,<br><br>
-- where <i>entry</i> is the current element and <i>arg</i> is the parameter.<br><br>
-- If the function returns a true result, this entry is kept. As a special case, if the
-- result is 0, all entries kept thus far are removed beforehand.
-- @param arg Argument to <i>func</i>.
-- @param clear_dead If true, clear trailing dead entries. This assumes the array does
-- not contain holes.<br><br>
-- Otherwise, a <b>nil</b> is inserted after the last live entry.
-- @return Size of table after culling.
function CullingForEach (t, func, arg, clear_dead)
	local kept = 0
	local count = #t

	for _, v in ipairs(t) do
		-- Put keepers back into the table. If desired, empty the table first.
		local result = func(v, arg)

		if result then
			kept = (result ~= 0 and kept or 0) + 1

			t[kept] = v
		end
	end

	-- Clear dead entries or place a sentinel nil.
	ClearRange(t, kept + 1, clear_dead and count or kept + 1)

	-- Report the new size.
	return kept
end

do
	-- Maps a table value during copies
	-- v: Table value
	-- Returns: Mapped value
	local function Mapping (v)
		return type(v) == "table" and DeepCopy_(v) or v
	end

	--- Deep-copies a table.<br><br>
	-- This will also copy metatables, and thus assumes these are accessible.
	-- @param t Table to copy.
	-- @return Copy.
	-- @see WithBoundTable
	function DeepCopy (t)
		return setmetatable(Map_(t, Mapping), getmetatable(t))
	end
end

do
	-- Equality helper
	local function AuxEqual (t1, t2)
		-- Iterate the tables in parallel. If equal, both tables will run out on the same
		-- iteration and the keys will then each be nil.
		local k1, k2, v1

		repeat
			-- The traversal order of next is unspecified, and thus at a given iteration
			-- the table values may not match. Thus, the value from the second table is
			-- discarded, and instead fetched with the first table's key.
			k2 = next(t2, k2)
			k1, v1 = next(t1, k1)

			local vtype = type(v1)
			local v2 = rawget(t2, k1)

			-- Proceed if the types match. As an exception, quit on nil, since matching
			-- nils means the table has been exhausted.
			local should_continue = vtype == type(v2) and k1 ~= nil

			if should_continue then
				-- Recurse on subtables.
				if vtype == "table" then
					should_continue = AuxEqual(v1, v2)

				-- For other values, do a basic compare, with special handling in the "not
				-- a number" case.
				else
					should_continue = v1 == v2 or (IsNaN(v1) and IsNaN(v2))
				end
			end
		until not should_continue

		return k1 == nil and k2 == nil
	end

	--- Compares two tables for equality, recursing into subtables. The comparison respects
	-- the <b>__eq</b> metamethod of non-table elements.
	-- TODO: Add cycles check
	-- @param t1 Table to compare.
	-- @param t2 Table to compare.
	-- @return If true, the tables are equal.
	function Equal (t1, t2)
		assert(type(t1) == "table", "t1 not a table")
		assert(type(t2) == "table", "t2 not a table")

		return AuxEqual(t1, t2)
	end
end

--- Finds a match for a value in the table. The <b>__eq</b> metamethod is respected by
-- the search.
-- @param t Table to search.
-- @param value Value to find.
-- @param is_array If true, search only the array part, up to a <b>nil</b>, in order.
-- @return Key belonging to a match, or <b>nil</b> if the value was not found.
function Find (t, value, is_array)
	for k, v in (is_array and ipairs or pairs)(t) do
		if v == value then
			return k
		end
	end
end

--- Array variant of <b>Find</b>, which searches each entry up to the first <b>nil</b>,
-- quitting if the index exceeds <i>n</i>.
-- @param t Table to search.
-- @param value Value to find.
-- @param n Limiting size.
-- @return Index of first match, or <b>nil</b> if the value was not found in the range.
-- @see Find
function Find_N (t, value, n)
	for i, v in ipairs(t) do
		if i > n then
			return
		elseif v == value then
			return i
		end
	end
end

--- Finds a non-match for a value in the table. The <b>__eq</b> metamethod is respected
-- by the search.
-- @param t Table to search.
-- @param value_not Value to reject.
-- @param is_array If true, search only the array part, up to a <b>nil</b>, in order.
-- @return Key belonging to a non-match, or <b>nil</b> if only matches were found.
-- @see Find
function FindNot (t, value_not, is_array)
	for k, v in (is_array and ipairs or pairs)(t) do
		if v ~= value_not then
			return k
		end
	end
end

--- Performs an action on each item of the table.
-- @param t Table to iterate.
-- @param func Visitor function, called as<br><br>
-- &nbsp&nbsp&nbsp<i><b>func(v, arg)</b></i>,<br><br>
-- where <i>v</i> is the current value and <i>arg</i> is the parameter. If the return value
-- is not <b>nil</b>, iteration is interrupted and quits.
-- @param is_array If true, traverse only the array part, up to a <b>nil</b>, in order.
-- @param arg Argument to <i>func</i>.
-- @return Interruption result, or <b>nil</b> if the iteration completed.
function ForEach (t, func, is_array, arg)
	for _, v in (is_array and ipairs or pairs)(t) do
		local result = func(v, arg)

		if result ~= nil then
			return result
		end
	end
end

--- Key-value variant of <b>ForEach</b>.
-- @param t Table to iterate.
-- @param func Visitor function, called as<br><br>
-- &nbsp&nbsp&nbsp<i><b>func(k, v, arg)</b></i>,<br><br>
-- where <i>k</i> is the current key, <i>v</i> is the current value, and <i>arg</i> is the
-- parameter. If the return value is not <b>nil</b>, iteration is interrupted and quits.
-- @param is_array If true, traverse only the array part, up to a <b>nil</b>, in order.
-- @param arg Argument to <i>func</i>.
-- @return Interruption result, or <b>nil</b> if the iteration completed.
-- @see ForEach
function ForEachKV (t, func, is_array, arg)
	for k, v in (is_array and ipairs or pairs)(t) do
		local result = func(k, v, arg)

		if result ~= nil then
			return result
		end
	end
end

--- Array variant of <b>ForEach</b>, allowing sections of the iteration to be conditionally
-- ignored.<br><br>
-- Iteration begins in the active state.<br><br>
-- If a value matches the "check value", iteration continues over the next value, which must
-- either be of type <b>"boolean"</b> or a callable value. If the former, the active state
-- is set to active for <b>true</b> or inactive for <b>false</b>. If instead the value is
-- callable, it is called as<br><br>
-- &nbsp&nbsp&nbsp<i><b>v(active, arg)</b></i>,<br><br>
-- where <i>active</i> is <b>true</b> or <b>false</b> according to the state and <i>arg</i>
-- is the parameter. The state will be set to active or inactive according to whether this
-- returns a true result or not, respectively.<br><br>
-- When the state is active, the current value is visited as per <b>ForEach</b>. Otherwise,
-- the value is ignored and iteration continues.
-- @param t Table to iterate.
-- @param check_value Value indicating that the subsequent value is a condition.
-- @param func Visitor function, called as<br><br>
-- &nbsp&nbsp&nbsp<i><b>func(v, arg)</b></i>,<br><br>
-- where <i>v</i> is the current value and <i>arg</i> is the parameter. If the return value
-- is not <b>nil</b>, iteration is interrupted and quits.
-- @param arg Argument to <i>func</i> and callable values.
-- @return Interruption result, or <b>nil</b> if the iteration completed.
function ForEachI_Cond (t, check_value, func, arg)
	local active = true
	local check = false

	for _, v in ipairs(t) do
		-- In the checking
		if check then
			assert(type(v) == "boolean" or IsCallable(v), "Invalid check active condition")

			if type(v) == "boolean" then
				active = v
			else
				active = not not v(active, arg)
			end

			check = false

		-- Otherwise, if this is the check value, enter the checking state.
		elseif rawequal(v, check_value) then
			check = true

		-- Otherwise, visit or ignore the current value.
		elseif active then
			local result = func(v, arg)

			if result ~= nil then
				return result
			end
		end
	end

	assert(not check, "Dangling check value")
end

do
	-- Field array cache --
	local Cache = {}

	-- Gets multiple table fields
	-- ...: Fields to get
	-- Returns: Values, in order
	------------------------------
	function GetFields (t, ...)
		local count, keys = CollectArgsInto(remove(Cache) or {}, ...)

		for i = 1, count do
			local key = keys[i]

			assert(key ~= nil, "Nil table key")

			keys[i] = t[key]
		end

		return UnpackClearAndRecache(Cache, keys, count)
	end
end

--- Collects all keys, arbitrarily ordered, into an array.
-- @param t Table from which to read keys.
-- @return Key array
-- @see WithBoundTable
function GetKeys (t)
    local dt = GetTable()

	for k in pairs(t) do
		dt[#dt + 1] = k
	end

	return dt
end

--- Makes a set, i.e. a table where each element has value <b>true</b>. For each value in
-- <i>t</i>, an element is added to the set, with the value instead as the key.
-- @param t Key array.
-- @return Set constructed from array.
-- @see WithBoundTable
function MakeSet (t)
	local dt = GetTable()

	for _, v in ipairs(t) do
		dt[v] = true
	end

	return dt
end

-- how: Table operation behavior
-- Returns: Offset pertinent to the behavior
local function GetOffset (t, how)
	return (how == "append" and #t or 0) + 1
end

-- Resolves a table operation
-- how: Table operation behavior
-- offset: Offset reached by operation
-- how_arg: Argument specific to behavior
local function Resolve (t, how, offset, how_arg)
	if how == "overwrite_trim" then
		ClearRange(t, offset, how_arg)
	end
end

-- Maps input items to output items
-- map: Mapping function
-- how: Mapping behavior
-- arg: Mapping argument
-- how_arg: Argument specific to mapping behavior
-- Returns: Mapped table
--------------------------------------------------
function Map (t, map, how, arg, how_arg)
	local dt = GetTable()

	if how then
		local offset = GetOffset(dt, how)

		for _, v in ipairs(t) do
			dt[offset] = map(v, arg)

			offset = offset + 1
		end

		Resolve(dt, how, offset, how_arg)

	else
		for k, v in pairs(t) do
			dt[k] = map(v, arg)
		end
	end

	return dt
end

-- Array Map variant allowing multiple result mappings
-- map: Mapping function
-- arg: Mapping argument
-- Returns: Mapped table
-------------------------------------------------------
function MapArrayEx (t, map, arg)
    local dt = GetTable()

    for _, v in ipairs(t) do
        for _, item in APairs(map(v, arg)) do
            dt[#dt + 1] = item
        end
    end

    return dt
end

-- Key array Map variant
-- ka: Key array
-- map: Mapping function
-- arg: Mapping argument
-- Returns: Mapped table
-------------------------
function MapK (ka, map, arg)
	local dt = GetTable()

	for _, k in ipairs(ka) do
		dt[k] = map(k, arg)
	end

	return dt
end

-- Key-value Map variant
-- map: Mapping function
-- how: Mapping behavior
-- arg: Mapping argument
-- how_arg: Argument specific to mapping behavior
-- Returns: Mapped table
--------------------------------------------------
function MapKV (t, map, how, arg, how_arg)
	local dt = GetTable()

	if how then
		local offset = GetOffset(dt, how)

		for i, v in ipairs(t) do
			dt[offset] = map(i, v, arg)

			offset = offset + 1
		end

		Resolve(dt, how, offset, how_arg)

	else
		for k, v in pairs(t) do
			dt[k] = map(k, v, arg)
		end
	end

	return dt
end

-- Moves items into a second table
-- how, how_arg: Move behavior, argument
-- Returns: Destination table
-----------------------------------------
function Move (t, how, how_arg)
	local dt = GetTable()

	if t ~= dt then
		if how then
			local offset = GetOffset(dt, how)

			for i, v in ipairs(t) do
				dt[offset], offset, t[i] = v, offset + 1
			end

			Resolve(dt, how, offset, how_arg)

		else
			for k, v in pairs(t) do
				dt[k], t[k] = v
			end
		end
	end

	return dt
end

do
	-- Weak table choices --
	local Choices = {
		k = { __metatable = true, __mode = "k" },
		v = { __metatable = true, __mode = "v" },
		kv = { __metatable = true, __mode = "kv" }
	}

	-- Helper metatable to build weak on-demand subtables --
	local Options = setmetatable({}, Choices.k)

	-- On-demand metatable --
	local OnDemand = {
		__metatable = true,
		__index = function(t, k)
			t[k] = setmetatable({}, Options[t])

			return t[k]
		end
	}

	--- Builds a new table. If one of the table's keys is missing, it will be filled in
	-- automatically with a subtable when indexed.<br><br>
	-- Note that this effect is not propagated to the subtables.<br><br>
	-- The table's metatable is fixed.
	-- @param choice If <b>nil</b>, subtables will be normal tables.<br><br>
	-- Otherwise, the weak option, as per <b>Weak</b>, to assign a new subtable.
	-- @return Table.
	-- @see Weak
	function SubTablesOnDemand (choice)
		local mt = Choices[choice or 0]

		assert(choice == nil or mt, "Invalid choice")

		local t = setmetatable({}, OnDemand)

		Options[t] = mt

		return t
	end

	--- Builds a new weak table.<br><br>
	-- The table's metatable is fixed.
	-- @param choice Weak option, which is one of <b>"k"</b>, <b>"v"</b>, or <b>"kv"</b>,
	-- and will assign that behavior to the <b>"__mode"</b> key of the table's metatable.
	-- @return Table.
	function Weak (choice)
		return setmetatable({}, assert(Choices[choice or 0], "Invalid weak option"))
	end
end

do
	-- Intermediate destination table --
    local DT

    -- Consumes and supplies a bound table
    -- Returns: Bound or new table
    function GetTable ()
        local t = DT

        DT = nil

        return t or {}
    end

	-- Valid consumers --
	local Consumers = MakeSet{ Copy, CopyK, DeepCopy, GetKeys, MakeSet, Map, MapArrayEx, MapK, MapKV, Move }

    --- Allows certain table operations to be called (those in the <b>"See also"</b> list)
	-- with user-provided tables as the destination.
    -- @param dt Destination table to bind.
    -- @param func Table operation to call.
    -- @param ... Arguments to <i>func</i>.
    -- @return Call results of <i>func</i>.
    -- @see Copy
    -- @see CopyK
    -- @see DeepCopy
    -- @see GetKeys
    -- @see MakeSet
    -- @see Map
    -- @see MapArrayEx
    -- @see MapK
    -- @see MapKV
    -- @see Move
    function WithBoundTable (dt, func, ...)
        assert(type(dt) == "table", "Non-table destination")
        assert(func ~= nil and Consumers[func], "Invalid consumer function")

        DT = dt

        return func(...)
    end
end

-- Cache some routines.
Copy_ = Copy
DeepCopy_ = DeepCopy
Map_ = Map
WithBoundTable_ = WithBoundTable