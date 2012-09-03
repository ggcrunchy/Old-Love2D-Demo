-- See TacoShell Copyright Notice in main folder of distribution

-- Base library imports --
local assert = assert
local format = string.format
local type = type

-- Current array --
local Array = {}

-------------------------------------------------
-- Appends formatted output strings to an array.
-- @class function
-- @name aprintf
-- @param str Format string.
-- @param ... Format parameters.
aprintf = setmetatable({}, {
	__call = function(_, str, ...)
		Array[#Array + 1] = format(str, ...)
	end,
	__metatable = true
})

-- Current array --

------------------------------------------
-- @return Current array used by aprintf.
-- @see aprintf
-- @see aprintf:SetArray
function aprintf:GetArray ()
	return Array
end

--------------------------------------------------
-- Sets the current array used by aprintf.
-- @param array Table to assign as current array.
-- @see aprintf
-- @see aprintf:GetArray
function aprintf:SetArray (array)
	assert(type(array) == "table", "SetArray: invalid array")

	Array = array
end