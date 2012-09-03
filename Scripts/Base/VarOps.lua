-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local format = string.format
local gsub = string.gsub
local ipairs = ipairs
local loadstring = loadstring
local rawget = rawget
local rep = string.rep
local select = select
local tonumber = tonumber
local type = type
local unpack = unpack

-- Collect count for code generator --
local CollectCount = ...

-- Pure Lua hacks --
local debug_getmetatable = debug.getmetatable

-- Cached routines --
local ClearRange_
local HasMeta_
local UnpackAndClear_

-- Export the varops namespace.
module "varops"

--- Information.
-- @param var Variable to test.
-- @param meta Metaproperty to lookup.
-- @return If true, variable supports the metaproperty.
function HasMeta (var, meta)
	local mt = debug_getmetatable(var)

	return (mt and rawget(mt, meta)) ~= nil
end

--- Information.
-- @param var Variable to test.
-- @return If true, variable is callable.
function IsCallable (var)
	return type(var) == "function" or HasMeta_(var, "__call")
end

--- Information.
-- @param var Variable to test.
-- @return If true, variable is an integer.
function IsInteger (var)
	local n = tonumber(var)

	return n ~= nil and n % 1 == 0
end

--- Information.
-- @param var Variable to test.
-- @return If true, variable is "not a number".
function IsNaN (var)
	return var ~= var
end

do
	-- Collect helper --
	local Collect

	-- Helper to accumulate arguments
	-- acc: Accumulator
	-- i: Index of last added item
	-- count: Total item count
	-- v(*), ...: Items to collect on this pass, remainder
	-- Returns: Argument count, filled accumulator when done; otherwise tail calls to next pass
	if CollectCount then
		assert(IsInteger(CollectCount) and CollectCount > 0, "Invalid collect count")
		assert(loadstring, "Code generator not present")

		-- Generate the Collect call for the per-pass collect count.
		local Form = format("_%s", rep(", _", CollectCount - 1))
		local Subs = {}

		for _, pat in ipairs{ "acc[i + %i]", "v%i" } do
			local index = 0

			Subs[#Subs + 1] = gsub(Form, "_", function()
				index = index + 1

				return format(pat, index)
			end)
		end

		Collect = loadstring(format([[
			local function Collect (acc, i, count, %s, ...)
				if i <= count then
					%s = %s

					return Collect(acc, i + %i, count, ...)
				end

				return count, acc
			end

			return Collect
		]], Subs[2], Subs[1], Subs[2], CollectCount))()

	-- This is a standard collect, specialized for five element loads at once. The above
	-- code was generated for several collect counts, and several combinations of nil and
	-- non-nil values in small and large doses were loaded into a table one million times
	-- each. The sweet spot seems to be somewhere around five loads per pass. 
	else
		function Collect (acc, i, count, v1, v2, v3, v4, v5, ...)
			if i <= count then
				acc[i + 1], acc[i + 2], acc[i + 3], acc[i + 4], acc[i + 5] = v1, v2, v3, v4, v5

				return Collect(acc, i + 5, count, ...)
			end

			return count, acc
		end
	end

	--- Collects arguments, including <b>nil</b>s, into an object.
	-- @param acc Accumulator object; if <b>nil</b>, a table is supplied.
	-- @param ... Arguments to collect.
	-- @return Argument count.
	-- @return Filled accumulator.
	function CollectArgsInto (acc, ...)
		local count = select("#", ...)

		if acc then
			return Collect(acc, 0, count, ...)
		else
			return count, { ... }
		end
	end
end

do
	--- Clears a range in an array.
	-- @param array Array to clear.
	-- @param first Index of first entry; by default, 1.
	-- @param last Index of last entry; by default, #<i>array</i>.
	-- @param wipe Value used to wipe cleared entries.
	-- @return Array.
	function ClearRange (array, first, last, wipe)
		for i = first or 1, last or #array do
			array[i] = wipe
		end

		return array
	end

	--- Clears an array and puts it into a cache.
	-- @param cache Cache of used arrays.
	-- @param array Array to clear.
	-- @param count Size of array; by default, #<i>array</i>.
	-- @param wipe Value used to wipe cleared entries.
	-- @return Array.
	function ClearAndRecache (cache, array, count, wipe)
		cache[#cache + 1] = array

		return ClearRange_(array, 1, count, wipe)
	end

	-- count: Value count
	-- ...: Array values
	local function AuxUnpackAndClear (array, count, wipe, ...)
		ClearRange_(array, 1, count, wipe)

		return ...
	end

	--- Clears an array, returning the cleared values.
	-- @param array Array to clear.
	-- @param count Size of array; by default, #<i>array</i>.
	-- @param wipe Value used to wipe cleared entries.
	-- @return Array values (number of return values = count).
	function UnpackAndClear (array, count, wipe)
		return AuxUnpackAndClear(array, count, wipe, unpack(array, 1, count))
	end

	--- Clears an array and puts it into a cache, returning the cleared values.
	-- @param cache Cache of used arrays.
	-- @param array Array to clear.
	-- @param count Size of array; by default, #<i>array</i>.
	-- @param wipe Value used to wipe cleared entries.
	-- @return Array values (number of return values = count).
	function UnpackClearAndRecache (cache, array, count, wipe)
		cache[#cache + 1] = array

		return UnpackAndClear_(array, count, wipe)
	end
end

-- Cache some routines.
ClearRange_ = ClearRange
HasMeta_ = HasMeta
UnpackAndClear_ = UnpackAndClear