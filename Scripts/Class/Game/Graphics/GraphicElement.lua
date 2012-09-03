-- See TacoShell Copyright Notice in main folder of distribution

----------------------------
-- Standard library imports
----------------------------
local assert = assert

-----------
-- Imports
-----------
local draw = love.graphics.draw
local draws = love.graphics.draws
local SuperCons = class.SuperCons
local TypeName = loveclasses.TypeName

----------------------
-- Unique member keys
----------------------
local _correct_center = {}
local _object = {}

-----------------------------------
-- GraphicElement class definition
-----------------------------------
class.Define("GraphicElement", function(MT)
	--------------------------
	-- Element draw functions
	--------------------------
	local Draw = {}

	-- Animation draw function
	---------------------------
	function Draw.Animation (props, A, x, y, w, h)
		local aw, ah = A:getWidth(), A:getHeight()
		local sx, sy = w / aw, h / ah

		draw(A, x, y, props.angle or 0, props.is_flipped_x and -sx or sx, props.is_flipped_y and -sy or sy)
	end

	-- Image draw function
	-----------------------
	function Draw.Image (props, I, x, y, w, h)
		local angle = props.angle or 0
		local iw, ih = I:getWidth(), I:getHeight()

		-- For subsprites, compute the extents; if relative, find their absolute form.
		local rect = props.rect

		if rect then
			local x1, y1, x2, y2

			if rect.is_relative then
				x1, x2 = (rect.x1 or 0) * iw, (rect.x2 or 1) * iw
				y1, y2 = (rect.y1 or 0) * ih, (rect.y2 or 1) * ih
			else
				x1, x2 = rect.x1 or 0, rect.x2 or iw
				y1, y2 = rect.y1 or 0, rect.y2 or ih
			end

			-- Determine the rectangle to be drawn. Use a different center if requested,
			-- supplying reasonable defaults for missing values. Draw the subsprite.
			local cw, ch = x2 - x1, y2 - y1

			if props.ox or props.oy then
				draws(I, x, y, x1, y1, cw, ch, angle, w / cw, h / ch, props.ox or I:getWidth() / 2, props.oy or I:getHeight() / 2)
			else
				draws(I, x, y, x1, y1, cw, ch, angle, w / cw, h / ch)
			end

		-- Otherwise, draw full sprite with all transformations.
		else
			-- (N.B. Flipping doesn't work on sub-sprites :( )
			w, h = props.is_flipped_x and -w or w, props.is_flipped_y and -h or h

			draw(I, x, y, angle, w / iw, h / ih)
		end
	end

	-- x, y: Element position
	-- w, h: Element dimensions
	-- props: Optional draw properties
	-----------------------------------
	function MT:__call (x, y, w, h, props)
		local object = self[_object]

		props = props or Draw

		if object then
			-- If desired, correct for the automatic centering of coordinates.
			if self[_correct_center] then
				x, y = x + w / 2, y + h / 2
			end

			-- Draw the object.
			self:WithProperties(props, Draw[TypeName(object)], object, x, y, w, h)
		end
	end

	-- Gets the element's height
	-----------------------------
	function MT:GetHeight ()
		local object = self[_object]

		return object and object:getHeight() or 0
	end

	-- Gets the element's width
	----------------------------
	function MT:GetWidth ()
		local object = self[_object]

		return object and object:getWidth() or 0
	end

	-- Assigns correction setting for centered elements
	-- correct: If true, apply correction
	----------------------------------------------------
	function MT:SetCenterCorrection (correct)
		self[_correct_center] = not not correct
	end

	-- Sets the element's object
	-----------------------------
	function MT:SetObject (object)
		assert(object == nil or Draw[TypeName(object) or 0], "Unsupported object type")

		self[_object] = object
	end
end,

-- Constructor
-- object: Object to set
-- correct: If true, apply center correction
---------------------------------------------
function(E, object, correct)
	SuperCons(E, "GraphicBase")

	E:SetObject(object)
	E:SetCenterCorrection(correct)
end, { base = "GraphicBase" })