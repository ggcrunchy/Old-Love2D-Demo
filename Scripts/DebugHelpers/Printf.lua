-- See TacoShell Copyright Notice in main folder of distribution

-- Base library imports --
local assert = assert
local ceil = math.ceil
local format = string.format
local max = math.max
local tonumber = tonumber
local type = type

-- Imports --
local draw = love.graphics.draw
local IsInteger = varops.IsInteger
local setFont = love.graphics.setFont

-- String ring buffer --
local Strings = {}

-- Serialized version of ring buffer --
local Serial = {}

-- Beginning of ring buffer --
local Index = 1

-- Display count --
local Count

------------------------------------
-- Prints formatted output strings.
-- @class function
-- @name printf
-- @param str Format string.
-- @param ... Format parameters.
-- @see printf:Output
printf = setmetatable({}, {
	__call = function(_, str, ...)
		local pos = Index

		if #Strings == Count then
			Index = (Index < Count and Index or 0) + 1
		else
			pos = #Strings + 1
		end

		Strings[pos] = format(str, ...)
	end,
	__metatable = true
})

------------------------------------------------
-- Clears the list of recently-printed strings.
function printf:Clear ()
	Strings = {}
end

-- Display count --
Count = 25

----------------------------------------------------
-- @return Number of strings that may be displayed.
-- @see printf:SetCount
function printf:GetCount ()
	return Count
end

----------------------------------------------------------------------------------------
-- @param count Number, which must be an integer greater than 0, of strings to display
-- at one time. If this is fewer than the amount currently displayed, the first entries
-- will be removed to satisfy the new count.
function printf:SetCount (count)
	assert(IsInteger(count) and count > 0, "Count not a positive integer")

	count = tonumber(count)

	if Count ~= count and #Strings ~= 0 then
		-- If the count has been reduced, any excess strings are trimmed off the start of
		-- the list. This is done by rotating the index ahead by the excess amount, so
		-- that these are ignored during the serialization step that follows.
		local index1 = Index + max(Count - count, 0)
		local index2 = 1 + max(index1 - #Strings, 0)

		-- Serialize the ring buffer.
		for i = index1, #Strings do
			Serial[#Serial + 1] = Strings[i]
		end

		for i = index2, Index - 1 do
			Serial[#Serial + 1] = Strings[i]
		end

		Index = 1

		-- Swap the serial and ring buffers, clearing the latter afterward.
		Strings, Serial = Serial, Strings

		for i = 1, #Serial do
			Serial[i] = nil
		end
	end

	Count = count
end

-- Font --
local Font = love.graphics.newFont(love.default_font)

-----------------------------------------
-- @return Font used to display strings.
-- @see printf:SetFont
function printf:GetFont ()
	return Font
end

---------------------------------------------
-- @param font Font used to display strings.
-- @see printf:GetFont
function printf:SetFont (font)
	Font = font
end

-- Start position --
local X, Y = 25, 25

-------------------------------------------------------
-- Gets the corner position where print output starts.
-- @return Corner x-coordinate.
-- @return Corner y-coordinate.
function printf:GetXY ()
	return X, Y
end

----------------------------------------------------
-- Sets the corner position where print output starts.
-- @param x Corner x-coordinate.
-- @param y Corner y-coordinate.
function printf:SetXY (x, y)
	assert(type(x) == "number", "x not a number")
	assert(type(y) == "number", "y not a number")

	X, Y = x, y
end

-------------------------------------------------------------------------------------
-- Performs the actual drawing, showing the recently-printed strings. This should be
-- called somewhere each frame.<br><br>
-- Note that this will leave the font set.
-- @see printf
function printf:Output ()
	setFont(Font)

	local advance = ceil(Font:getHeight() * Font:getLineHeight())
	local y = Y

	for i = Index, #Strings do
		draw(Strings[i], X, y)

		y = y + advance
	end

	for i = 1, Index - 1 do
		draw(Strings[i], X, y)

		y = y + advance
	end
end