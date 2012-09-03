-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert

-- Imports --
local IsCallable = varops.IsCallable
local NoOp = funcops.NoOp

-- Unique member keys --
local _graphic = {}
local _props = {}

-- Picture class definition --
class.Define("Picture", function(Picture)
	--- Draws the picture in (x, y, w, h). If no graphic is assigned, this is a no-op.
	-- @param x Rect x-coordinate.
	-- @param y Rect y-coordinate.
	-- @param w Rect width.
	-- @param h Rect height.
	-- @param props Optional replacement property set. If absent, the property set
	-- belonging to the picture is used.
	-- @see Picture:SetGraphic
	function Picture:Draw (x, y, w, h, props)
		(self[_graphic] or NoOp)(x, y, w, h, props or self[_props])
	end

	--- Accessor.
	-- @return Picture graphic.
	-- @see Picture:SetGraphic
	function Picture:GetGraphic ()
		return self[_graphic]
	end

	--- Accessor.
	-- @param name Name of property to get. Must not be <b>nil</b>.
	-- @return Property value.
	function Picture:GetProperty (name)
		assert(name ~= nil, "name == nil")

		return self[_props][name]
	end

	--- Accessor.
	-- @param graphic Graphic to assign, or <b>nil</b> to remove the graphic.<br><br>
	-- A valid graphic is a function or callable object called as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>graphic(x, y, w, h, props)</b></i>,<br><br>
	-- where <i>x</i>, <i>y</i>, <i>w</i>, and <i>h</i> are the rect in which the
	-- graphic is being drawn, and <i>props</i> is a table of (name, value) property
	-- pairs.
	function Picture:SetGraphic (graphic)
		assert(graphic == nil or IsCallable(graphic), "Uncallable graphic")

		self[_graphic] = graphic
	end

	--- Accessor.
	-- @param name Name of property to set. Must not be <b>nil</b>.
	-- @param value Value to assign to property.
	function Picture:SetProperty (name, value)
		assert(name ~= nil, "name == nil")

		self[_props][name] = value
	end
end,

--- Class constructor.
-- @class function
-- @name Constructor
-- @param graphic Graphic handle.
-- @param props Optional external property set. If absent, a fresh table will be used.
-- @see Picture:SetGraphic
function(P, graphic, props)
	P[_props] = props or {}

	P:SetGraphic(graphic)
end)