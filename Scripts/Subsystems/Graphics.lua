-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local pairs = pairs
local remove = table.remove
local type = type
local unpack = unpack

-- Modules --
local love = love
local lg = love.graphics

-- Imports --
local APairs = iterators.APairs
local BoxIntersection = numericops.BoxIntersection
local ClearRange = varops.ClearRange
local getScissor = lg.getScissor
local New = class.New
local rectangle = lg.rectangle
local setScissor = lg.setScissor
local TypeName = loveclasses.TypeName

-- Cached routines --
local GetColorRGBA_

-- Export the graphics namespace.
module "graphics"

-- Colors --
do
	-- Registered colors --
	local Colors = {
		default = { 255, 255, 255, 255 }
	}

	-- Current color --
	local R, G, B, A = 255, 255, 255, 255

	-- Overload love.graphics.setColor.
	local old_setColor = lg.setColor

	function lg.setColor (...)
		old_setColor(...)

		local r_or_color, g, b, a = ...

		if g then
			R, G, B, A = r_or_color, g, b, a or 255
		else
			R = r_or_color:getRed()
			G = r_or_color:getGreen()
			B = r_or_color:getBlue()
			A = r_or_color:getAlpha()
		end
	end

	-- Gets a color's components
	-----------------------------
	function GetColorRGBA (name_or_color)
		assert(name_or_color ~= nil, "GetColorRGBA: name_or_color == nil")

		if name_or_color == "current" then
			return R, G, B, A
		elseif TypeName(name_or_color) == "Color" then
			return name_or_color:getRed(), name_or_color:getGreen(), name_or_color:getBlue(), name_or_color:getAlpha()
		else
			local color = assert(Colors[name_or_color], "Color not registered")

			return unpack(color)
		end
	end

	-- Linearly interpolates two colors
	-- t: Interpolation time
	-- color1, color2: Interpolated colors
	-- result: Color that receives interpolation
	---------------------------------------------
	function InterpolateColors (t, color1, color2, result)
		assert(TypeName(result) == "Color", "result cannot be interpolated")

		local r1, g1, b1, a1 = GetColorRGBA_(color1)
		local r2, g2, b2, a2 = GetColorRGBA_(color2)

		color:setRed(r1 + t * (r2 - r1))
		color:setGreen(g1 + t * (g2 - g1))
		color:setBlue(b1 + t * (b2 - b1))
		color:setAlpha(a1 + t * (a2 - a1))
	end

	-- Registers a color constant
	------------------------------
	function RegisterColor (name, r, g, b, a)
		assert(name ~= nil, "RegisterColor: name == nil")
		assert(name ~= "current", "Cannot register current color")
		assert(not Colors[name], "Color already registered")
		assert(TypeName(name) ~= "Color", "Cannot use color as name")

		Colors[name] = { r, g, b, a or 255 }
	end
end

-- Fonts --
do
	local PrevFont, ThisFont

	-- Overload love.graphics.setFont.
	local old_setFont = lg.setFont

	function lg.setFont (font, ...)
		old_setFont(font, ...)

		PrevFont = ThisFont
		ThisFont = font
	end

	-- Restores any previously set font
	------------------------------------
	function RestoreFont ()
		ThisFont = PrevFont
		PrevFont = nil

		if ThisFont then
			setFont(ThisFont)
		end
	end
end

-- Primitives --
do
	-- Helper object used to provide common property change functionality for primitives --
	local Base

	-- Rectangle draw helper
	local function Draw (_, type, x, y, w, h)
		rectangle(type, x, y, w, h)
	end

	-- Rectangle draw setup helper
	local function Rect (type, x, y, w, h, props)
		-- Build the base object the first time.
		Base = Base or New("GraphicBase")

		-- Draw the rectangle with proper state handling.
		Base:WithProperties(props, Draw, type, x, y, w, h)
	end
	
	-- Install rectangle draw functions.
	for k, draw in pairs{
		DrawFilledQuad = love.draw_fill,
		DrawOutlineQuad = love.draw_line
	} do
		_M[k] = function(x, y, w, h, props)
			Rect(draw, x, y, w, h, props)
		end
	end
end

-- Scissors --
do
	-- Cache of used scissor rects --
	local Cache = {}

	-- Stack of indices into scissor rect stack; new scissor rects are intersected against these rects --
	local Restrict = {}

	-- Stack of scissor rects in effect --
	local Stack = {}

	-- Applies the top scissor state
	---------------------------------
	function ApplyScissorState ()
		local top = Stack[#Stack]

		if top then
			setScissor(top.x, top.y, top.w, top.h)
		else
			setScissor()
		end
	end

	-- Clears all scissor state
	----------------------------
	function ClearScissorState ()
		for _ = 1, #Stack do
			Cache[#Cache + 1] = remove(Stack)
		end

		ClearRange(Restrict)

		setScissor()
	end

	-- Removes the last scissor rect, restoring the previous state
	---------------------------------------------------------------
	function PopScissorRect ()
		-- Remove the current rect and put it into the cache. If this rect imposed a
		-- restriction, remove that as well.
		Cache[#Cache + 1] = assert(remove(Stack), "Scissor stack is empty")

		if Restrict[#Restrict] == #Stack + 1 then
			Restrict[#Restrict] = nil
		end

		-- Apply the new scissor rect.
		local new_top = Stack[#Stack]

		if new_top then
			setScissor(new_top.x, new_top.y, new_top.w, new_top.h)
		else
			setScissor()
		end
	end

	-- Applies a scissor rect, saving the state
	-- x, y, w, h: Scissor rect
	-- restrict_after: If true, further rects will be intersected against this rect
	-- Returns: If true, scissor rect was applied
	--------------------------------------------------------------------------------
	function PushScissorRect (x, y, w, h, restrict_after)
		assert(type(x) == "number", "Invalid x")
		assert(type(y) == "number", "Invalid y")
		assert(type(w) == "number" and w > 0, "Invalid w")
		assert(type(h) == "number" and h > 0, "Invalid h")

		-- If restrictions are in force, restrict the rect to the most current one. If
		-- this yields an invalid rect, fail and quit.
		if #Restrict > 0 then
			local restrict = Stack[Restrict[#Restrict]]
			local is_valid

			is_valid, x, y, w, h = BoxIntersection(restrict.x, restrict.y, restrict.w, restrict.h, x, y, w, h)

			if not is_valid then
				return false
			end
		end

		-- Add the current rect.
		local rect = remove(Cache) or {}

		rect.x, rect.y, rect.w, rect.h = x, y, w, h

		Stack[#Stack + 1] = rect

		-- If a restriction is to be applied, associate it with this level.
		if restrict_after then
			Restrict[#Restrict + 1] = #Stack
		end

		-- Apply the scissor rect.
		setScissor(x, y, w, h)

		return true
	end
end

-- Add some stock colors.
for _, color in APairs(
	{ "black", 0, 0, 0 },
	{ "blue", 0, 0, 255 },
	{ "cyan", 0, 255, 255 },
	{ "gray", 128, 128, 128 },
	{ "green", 0, 255, 0 },
	{ "magenta", 255, 0, 255 },
	{ "red", 255, 0, 0 },
	{ "white", 255, 255, 255 },
	{ "yellow", 255, 255, 0 }
) do
	RegisterColor(unpack(color))
end

-- Cache some routines.
GetColorRGBA_ = GetColorRGBA