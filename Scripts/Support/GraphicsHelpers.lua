----------------------------
-- Standard library imports
----------------------------
local ipairs = ipairs
local pairs = pairs
local type = type

-----------
-- Imports
-----------
local New = class.New
local newImage = love.graphics.newImage
local newFont = love.graphics.newFont

-------------------
-- Cached routines
-------------------
local Picture_
local Texture_

-- Export graphics helpers namespace.
module "graphicshelpers"

-- Helper to load fonts
-- id: Font ID
-- size: Optional font size
-- Returns: Font handle
----------------------------
function Font (id, size)
	return New("Font", size and newFont(id, size) or newFont(id))
end

-- Helper to load multipictures
-- input: Texture name / handle table
-- mode: Multipicture mode
-- thresholds: Threshold values
-- props: Optional external property set
-- Returns: Multipicture handle
-----------------------------------------
function MultiPicture (input, mode, thresholds, props)
	local multi = New("MultiPicture", mode, props)

	for k, v in pairs(thresholds) do
		multi:SetThreshold(k, v)
	end

	for i, entry in ipairs(input) do
		multi:SetPicture(i, Picture_(entry))
	end

	return multi
end

-- Helper to build a picture
-- texture: Texture name / handle
-- props: Optional external property set
-- Returns: Picture handle
-----------------------------------------
function Picture (texture, props)
	return New("Picture", Texture_(texture), props)
end

-- Helper to load picture textures
-- input: Texture name / handle
-- Returns: Texture handle
-----------------------------------
function Texture (input)
	return type(input) == "string" and New("GraphicElement", newImage(input), true) or input
end

-- Cache some routines.
Picture_ = Picture
Texture_ = Texture