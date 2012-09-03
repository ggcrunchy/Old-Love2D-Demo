-- Standard library imports --
local assert = assert
local pairs = pairs
local type = type

-- Imports --
local APairs = iterators.APairs
local CallOrGet = funcops.CallOrGet
local default_font = love.default_font
local Define = class.Define
local DrawFilledQuad = graphics.DrawFilledQuad
local DrawOutlineQuad = graphics.DrawOutlineQuad
local Find = table_ex.Find
local Font = graphicshelpers.Font
local GetEventStream = section.GetEventStream
local InterpolateColors = graphics.InterpolateColors
local Map = table_ex.Map
local MultiPicture = graphicshelpers.MultiPicture
local New = class.New
local newColor = love.graphics.newColor
local NoOp = funcops.NoOp
local Picture = graphicshelpers.Picture
local Texture = graphicshelpers.Texture
local UIGroup = windows.UIGroup
local Weak = table_ex.Weak
local WithInterpolator = tasks.WithInterpolator

-- Cached routines --
local Backdrop_
local ContextColorInterp_
local Image_
local String_

-- Export the ui namespace.
module "ui"

-- GUI font --
local GUIFont = Font(default_font)

-- Dropdowns, editboxes --
do
	-- Dropdown pictures --
	local Frame = Picture(DrawOutlineQuad)
	local Heading = Picture(DrawFilledQuad, { color = "magenta" })

	-- Dropdown setup helper
	-- capacity: Dropdown capacity
	-- Returns: Dropdown handle
	-------------------------------
	function Dropdown (capacity)
		local D = New("Dropdown", UIGroup(), capacity)

		D:SetFont(GUIFont)
		D:SetPicture("backdrop", Frame)
		D:SetPicture("heading", Heading)
		D:SetPicture("highlight", Highlight)

		return D
	end

	-- Editbox pictures --
	local Cursor = Picture(DrawFilledQuad)
	local Highlight = Picture(DrawFilledQuad, { color = "blue" })

	-- Editbox setup helper
	-- Returns: Editbox handle
	---------------------------
	function Editbox ()
		local E = New("Editbox", UIGroup())

		E:SetFont(GUIFont)
		E:SetPicture("main", Frame)
		E:SetPicture("cursor", Cursor)
		E:SetPicture("highlight", Highlight)
		E:SetTimeout(.6)

		return E
	end
end

-- Push buttons --
do
	local LeftOn, RightOn = Texture("Images/GUI/Button/Left_On.png"), Texture("Images/GUI/Button/Right_On.png")
	local On = MultiPicture({
		LeftOn, Texture("Images/GUI/Button/Middle_On.png"), RightOn
	}, "hline", {
		left = LeftOn:GetWidth(), right = RightOn:GetWidth()
	})

	local LeftOff, RightOff = Texture("Images/GUI/Button/Left_Off.png"), Texture("Images/GUI/Button/Right_Off.png")
	local Off = MultiPicture({
		LeftOff, Texture("Images/GUI/Button/Middle_Off.png"), RightOff
	}, "hline", {
		left = LeftOff:GetWidth(), right = RightOff:GetWidth()
	})

	-- Push button setup helper
	-- action: Push button action
	-- Returns: PushButton handle
	------------------------------
	function PushButton (action)
		local P = New("PushButton", UIGroup())

		P:SetAction(action)

		-- Bind the font and set text properties.
		P:SetFont(GUIFont)
		P:SetPicture("main", Off)
		P:SetPicture("entered", On)
		P:SetPicture("grabbed", On)
		P:SetTextSetup("left", 10, 0)

		return P
	end
end

do
	local Choice = Picture("Images/GUI/Radio/Chosen.png")
	local Option = Picture("Images/GUI/Radio/Option.png")

	-- Radio setup helper
	-- optionw, optionh: Option dimensions
	---------------------------------------
	function Radio (optionw, optionh)
		local R = New("Radio", UIGroup(), optionw, optionh)

		R:SetPicture("choice", Choice)
		R:SetPicture("option", Option)

		return R
	end
end

-- Sliders, horizontal --
do
	local LeftBack, RightBack, ThumbTex = Texture("Images/GUI/Slider/Left_Back.png"), Texture("Images/GUI/Slider/Right_Back.png"), Texture("Images/GUI/Slider/Thumb.png")
	local Back = MultiPicture({
		LeftBack, Texture("Images/GUI/Slider/Middle_Back.png"), RightBack
	}, "hline", {
		left = LeftBack:GetWidth(), right = RightBack:GetWidth()
	})

	local Thumb = Picture(ThumbTex)

	-- Horizontal slider setup helper
	-- Returns: Horizontal slider handle
	-------------------------------------
	function SliderHorz ()
		local S = New("Slider", UIGroup(), 0, ThumbTex:GetWidth(), 3, ThumbTex:GetWidth(), ThumbTex:GetHeight(), false)

		-- Bind the slider picture.
		S:SetPicture("main", Back)

		-- Bind the thumb pictures.
		local thumb = S:GetThumb()

		thumb:SetPicture("main", Thumb)
		thumb:SetPicture("entered", Thumb)
		thumb:SetPicture("grabbed", Thumb)

		return S
	end
end

-- String groups --
do
	-- Stock colors --
	local ChosenColor = "red"
	local OffColor = "gray"
	local OnColor = "white"

	-- Active colors --
	local Chosen = Weak("k")
	local NotChosen = Weak("k")

	-- Stock signals --
	local Signals = {}
	
	function Signals:gain_focus ()
		self:SetColor("string", Chosen[self] or ChosenColor)
	end

	function Signals:lose_focus ()
		self:SetColor("string", NotChosen[self])
	end

	-- Builds a group of grayable strings
	-- count: Count of strings
	-- active: Activity test routine
	-- func: Optional callback routine
	-- on_color, off_color: Optional string colors
	-- Returns: String table
	-----------------------------------------------
	function StringGroup_Gray (count, active, func, on_color, off_color)
		func = func or NoOp
		on_color = on_color or OnColor
		off_color = off_color or OffColor

		--
		local function color ()
			return active() and on_color or off_color
		end

		--
		local t = {}

		for i = 1, count do
			t[i] = String_()

			t[i]:SetColor("string", color)

			func(i, t[i])
		end

		return t
	end

	-- Builds a group of highlightable strings
	-- count: Count of strings
	-- func: Optional callback routine
	-- chosen, not_chosen: Optional string colors
	-- Returns: String table
	---------------------------------------------
	function StringGroup_Highlight (count, func, chosen, not_chosen)
		func = func or NoOp

		--
		local t = {}

		for i = 1, count do
			local str = String_()

			str:SetMultipleSignals(Signals)
			str:SetColor("string", not_chosen)

			Chosen[str] = chosen
			NotChosen[str] = not_chosen

			t[i] = str

			func(i, str)
		end

		return t
	end
end

-- Configures a widget picture
-- picture: Picture name or handle
-- Returns: Picture handle
-----------------------------------
local function PicSetup (picture)
	return type(picture) == "string" and Picture(picture) or picture
end

-- Backdrop setup helper
-- should_block: If true, backdrop should block input
-- background: Optional texture name / handle
-- Returns: Backdrop handle
------------------------------------------------------
function Backdrop (should_block, background)
	local B = New("Pane", UIGroup())

	if not should_block then
		B:SetSignal("test", nil)
	end

	if background then
		B:SetPicture("main", PicSetup(background))
	end

	return B
end

-- Fade pane helper
-- options: Configuration options
-- Returns: Pane handle, transition handle, cue function
---------------------------------------------------------
function FadePane (options)
	-- If requested, make the fade effect dependent on a user-defined condition.
	local pic_func = DrawFilledQuad
	local draw_if = options.drawif

	if draw_if then
		function pic_func (x, y, w, h, props)
			if draw_if() then
				DrawFilledQuad(x, y, w, h, props)
			end
		end
	end

	--
	local color = newColor()
	local pic = Picture(pic_func, { color = color, color_mode = "modulate" })
	local pane = Backdrop_(false, pic)

	--
	local transition = New("Interpolator", ContextColorInterp_, options.duration, options.color1, options.color2, color)
	local on_quit

	local task = WithInterpolator(transition, nil, function()
		(on_quit or NoOp)()
	end)

	local function cue (how, quit)
		--
		on_quit = quit

		-- Add a fade task and segue into the fade.
		GetEventStream("enter_update"):Add(task)

		transition:Start("once", how)
	end

	--
	return pane, transition, cue
end

-- Image setup helper
-- picture: Picture texture name/handle
-- Returns: Image handle
----------------------------------------
function Image (picture)
	local I = New("Image", UIGroup())

	I:SetPicture("main", PicSetup(picture))

	return I
end

-- Listbox setup helper
-- capacity: Listbox capacity
-- Returns: Listbox handle
------------------------------
function Listbox (capacity)
	local L = New("Listbox", UIGroup(), capacity)

	L:SetFont(GUIFont)
	L:SetPicture("main", Picture("Textures/gui/menu/menu.png"))
	L:SetPicture("highlight", Picture("Textures/gui/slider/thumb.png"))

	return L
end

-- Marquee setup helper
-- str: Marquee string
-- right_to_left: If true, marquee scrolls right-to-left
-- Returns: Marquee handle
---------------------------------------------------------
function Marquee (str, right_to_left)
	local M = New("Marquee", UIGroup(), right_to_left)

	M:SetBorder(0, 0)

	M:SetFont(GUIFont)
	M:SetString(str)

	return M
end

-- Scroll button setup helper
-- how: Scroll behavior
-- Returns: Scroll button handle
---------------------------------
function ScrollButton (how)
	local S = New("ScrollButton", UIGroup())

	S:SetPicture{
		main = Picture("Textures/gui/radio/off.png"),
		entered = Picture("Textures/gui/radio/on.png"),
		grabbed = Picture("Textures/gui/radio/on.png")
	}
	S:SetTimeout(.2)

	return S
end

-- String setup helper
-- string: String to assign to text
-- Returns: String handle
------------------------------------
function String (string)
	local S = New("String", UIGroup())

	S:SetFont(GUIFont)
	S:SetShadowOffsets(2, 2)
	S:SetString(string)
	S:SetColor("shadow", "black")

	return S
end

-- Textbox setup helper
-- emit_rate: Delay between character emissions
-- Returns: Textbox handle
------------------------------------------------
function Textbox (emit_rate)
	local P = New("Textbox", UIGroup(), emit_rate)

	P:SetFont(GUIFont)
	P:SetShadowOffsets(2, 2)
	P:SetColor("shadow", "black")

	return P
end

-- Generic widget setup helper
-- slot, signal: SetSignal arguments
-- Returns: Widget handle
-------------------------------------
function Widget (slot_or_table, signal)
	local W = New("Widget", UIGroup())

	W:SetFont(GUIFont)

	assert(slot_or_table ~= nil, "Invalid slot or slot table")

	if type(slot_or_table) == "table" then
		W:SetMultipleSignals(slot_or_table)
	else
		W:SetSignal(slot_or_table, signal)
	end

	return W
end

-- Cache some routines.
Backdrop_ = Backdrop
ContextColorInterp_ = ContextColorInterp
Image_ = Image
String_ = String