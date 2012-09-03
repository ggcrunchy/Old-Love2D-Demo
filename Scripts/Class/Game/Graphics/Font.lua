-- See TacoShell Copyright Notice in main folder of distribution

----------------------------
-- Standard library imports
----------------------------
local assert = assert
local floor = math.floor
local max = math.max
local sub = string.sub
local type = type

-----------
-- Imports
-----------
local draw = love.graphics.draw
local RestoreFont = graphics.RestoreFont
local setFont = love.graphics.setFont
local SuperCons = class.SuperCons
local TypeName = loveclasses.TypeName

----------------------
-- Unique member keys
----------------------
local _object = {}

-------------------------
-- Font class definition
-------------------------
class.Define("Font", function(MT)
	-- Lookups are no-ops --
	MT.SetLookupKey = funcops.NoOp

	-- String draw function
	------------------------
	local function Draw (_, str, x, y)
		draw(str, x, y)
	end

	-- str: String to draw
	-- x, y: String position
	-- props: Optional draw properties
	-----------------------------------
	function MT:__call (str, x, y, props)
		local font = self[_object]

		if font then
			setFont(font)

			self:WithProperties(props or _object, Draw, str, x, y + font:getHeight())

			RestoreFont()
		end
	end

	-- i, j: Start and end of range
	-- pos: Position to find
	-- Returns: Position within string
	-----------------------------------
	local function FindInRange (font, str, i, j, pos)
		-- If the range has been narrowed enough, just iterate to find the final result.
		if j - i <= 5 then
			local len = font:getWidth(sub(str, 1, i - 1))

			while len < pos do
				i, len = i + 1, len + font:getWidth(sub(str, i, i))
			end

			return max(i - 2, 0)
		end

		-- Otherwise, figure out which half of the range the position is in and continue
		-- the search in that half.
		local mid = floor((i + j) / 2)
		local midlen = font:getWidth(sub(str, 1, mid))

		if pos >= midlen then
			i = mid
		else
			j = mid - 1
		end

		return FindInRange(font, str, i, j, pos)
	end

	-- str: Reference string
	-- pos: Position relative to string edge
	-- Returns: Relative position within string
	--------------------------------------------
	function MT:GetIndexAtOffset (str, pos)
		assert(type(str) == "string", "Invalid string")
		assert(type(pos) == "number", "Invalid position")

		-- Clamp the position to 0 if to the left of the string.
		local font = self[_object]

		if pos < 0 or not font then
			return 0

		-- Otherwise, measure within the string. Clamp to the string length if the position
		-- is to the right of the string.
		else
			local len = font:getWidth(str)

			if pos > len then
				return #str
			end

			return FindInRange(font, str, 1, #str, pos)
		end
	end

	-- F: Font handle
	-- with_padding: If true, include line padding
	-- Returns: String's height with the font
	-----------------------------------------------
	local function GetHeight (F, str, with_padding)
		assert(type(str) == "string", "Invalid string")

		local font, h = F[_object], 0

		if font then
			h = font:getHeight()

			if with_padding then
				h = h * font:getLineHeight()
			end
		end

		return h
	end

	-- F: Font handle
	-- Returns: String's width with the font
	-----------------------------------------
	local function GetWidth (F, str)
		assert(type(str) == "string", "Invalid string")

		local font = F[_object]

		return font and font:getWidth(str) or 0
	end

	-- Dimensions --
	MT.GetHeight, MT.GetWidth = GetHeight, GetWidth

	-- Adjusts coordinate for alignment
	-- dim: Box dimension
	-- sdim: String dimension
	-- how: How to align in this dimension
	-- Returns: Coordinate delta
	---------------------------------------
	local function Align (dim, sdim, how)
		if how == "center" then
			return (dim - sdim) / 2
		elseif how then
			return dim - sdim
		else
			return 0
		end
	end

	-- Gets a string's alignment-based offsets
	-- str: String to align
	-- w, h: Extents of alignment box
	-- halign, valign: Alignment options
	-- Returns: Coordinate deltas
	-------------------------------------------
	function MT:GetAlignmentOffsets (str, w, h, halign, valign)
		local dx = Align(w, GetWidth(self, str), halign ~= "left" and halign)
		local dy = Align(h, GetHeight(self, str), valign ~= "top" and valign)

		return dx, dy
	end

	-- Sets the font's object
	--------------------------
	function MT:SetObject (object)
		assert(object == nil or TypeName(object) == "Font", "Unsupported object type")

		self[_object] = object
	end
end,

-- Constructor
-- object: Object to set
-------------------------
function(F, object)
	SuperCons(F, "GraphicBase")

	F:SetObject(object)
end, { base = "GraphicBase" })