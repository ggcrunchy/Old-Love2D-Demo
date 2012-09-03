-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local pairs = pairs

-- Imports --
local AddAfter = list.AddAfter
local Append = list.Append
local Back = list.Back
local BackToFrontIter = list.BackToFrontIter
local CallOrGet = funcops.CallOrGet
local FrontToBackIter = list.FrontToBackIter
local IsType = class.IsType
local PointInBox = numericops.PointInBox
local RemoveFrom = list.RemoveFrom
local SetLocalRect = widgetops.SetLocalRect
local SuperCons = class.SuperCons

-- Callback permissions --
local Permissions = table_ex.MakeSet{ "attach_list_render", "attach_list_test", "attach_list_update", "render", "test", "update" }

-- Unique member keys --
local _attach_list = {}
local _bh = {}
local _bw = {}
local _colors = {}
local _font = {}
local _group = {}
local _h = {}
local _parent = {}
local _pictures = {}
local _string = {}
local _sx = {}
local _sy = {}
local _vx = {}
local _vy = {}
local _w = {}
local _x = {}
local _y = {}

-- Stock signals --
local Signals = {}

--- Draws picture <b>"main"</b> with rect (x, y, w, h).
-- @param x Rect x-coordinate.
-- @param y Rect y-coordinate.
-- @param w Rect width.
-- @param h Rect height.
function Signals:render (x, y, w, h)
	self:DrawPicture("main", x, y, w, h)
end

--- Succeeds if (cx, cy) is inside (x, y, w, h).
-- @param cx Cursor x-coordinate.
-- @param cy Cursor y-coordinate.
-- @param x Bounding rect x-coordinate.
-- @param y Bounding rect y-coordinate.
-- @param w Bounding rect width.
-- @param h Bounding rect height.
-- @return On a successful test, returns the widget.
function Signals:test (cx, cy, x, y, w, h)
	if PointInBox(cx, cy, x, y, w, h) then
		return self
	end
end

-- Widget class definition --
class.Define("Widget", function(Widget)
	--- Assigns widget callback permissions. These determine whether widgets or their attach
	-- lists are run during <b>UIGroup:Execute</b>, <b>UIGroup:Render</b>, and <b>
	-- UIGroup:Update</b>.<br><br>
	-- Note that, if only the regular permission is disabled for a given operation, the
	-- attach list will still be run.
	-- @param what Permission type, which may be one of the following:<br><br>
	-- <b>"attach_list_render"</b>, <b>"attach_list_test"</b>, <b>"attach_list_update"</b>,
	-- <b>"render"</b>, <b>"test"</b>, <b>"update"</b>.
	-- @param allow If true, allow callback.
	-- @see Widget:IsAllowed
	function Widget:Allow (what, allow)
		if Permissions[what] then
			self[what] = not allow and true or nil
		end
	end

	--- Adds a widget to this widget's attach list, and sets its local rect as a
	-- convenience.<br><br>
	-- If the widget is already attached to another parent, it is first detached, with the
	-- associated behavior.<br><br>
	-- If the widget is not already in the attach list, it is appended.<br><br>
	-- The widget's local rect is then assigned, using the passed input.<br><br>
	-- If the widget was not already in the attach list, it gets sent an <b>"attach"</b>
	-- signal with no arguments, and this widget gets sent an <b>"attached_to"</b> signal,
	-- also without arguments.
	-- @param widget Widget to attach.
	-- @param x Local x-coordinate to assign.
	-- @param y Local y-coordinate to assign.
	-- @param w Width to assign.
	-- @param h Height to assign.
	-- @see Widget:Detach
	-- @see Widget:IsAttached
	function Widget:Attach (widget, x, y, w, h)
        local group = self[_group]

		assert(IsType(widget, "Widget"), "Cannot attach non-widget")
	    assert(group:GetMode() == "normal", "Attaching forbidden from callbacks/event issues")
		assert(group == widget[_group], "Attempt to mix widgets in different groups")
		assert(self ~= widget, "Cannot attach widget to self")
		assert(widget ~= group:GetRoot(), "Cannot attach root widget")

		-- If the widget is being assigned a new parent, attach it.
		local is_new_parent = widget[_parent] ~= self

		if is_new_parent then
			widget:Detach()

			-- Attach the widget and link its parent.
			self[_attach_list] = Append(self[_attach_list], widget)
			widget[_parent] = self
		end

		-- Update the region.
		SetLocalRect(widget, x, y, w, h)

		-- Invoke any attachment signals.
		if is_new_parent then
			widget:Signal("attach")
			self:Signal("attached_to")
		end
	end

	--- Iterates across the widget's attach list.
	-- @param reverse If true, iterate back to front.
	-- @return Iterator, which returns a widget handle at each iteration.
	-- @see Widget:GetAttachListBack
	-- @see Widget:GetAttachListHead
    function Widget:AttachListIter (reverse)
		return (reverse and BackToFrontIter or FrontToBackIter)(self[_attach_list])
    end

	-- Chain iterator body
	-- W: Bottom widget handle
	-- widget: Widget handle
	-- Returns: Widget handle
	local function ChainIter (W, widget)
		if widget then
			return widget[_parent]
		end

		return W
	end

	--- Iterates from this widget up the chain of parents.
	-- @return Iterator, which returns a widget handle at each iteration.
    function Widget:ChainIter ()
        return ChainIter, self
    end

	--- Detaches the widget from its parent.<br><br>
	-- If the widget is not attached, this is a no-op.<br><br>
	-- Otherwise, the parent widget is first sent a <b>"detached_from"</b> signal, with
	-- this widget as its argument, and this widget receives a <b>"detach"</b> signal
	-- with no arguments. The widget is then removed from the parent's attach list.
	-- @see Widget:Attach
	-- @see Widget:IsAttached
	function Widget:Detach ()
		assert(not self[_group]:IsRunningCallbacks(), "Detaching forbidden from callbacks")

        local parent = self[_parent]

		if parent then
			parent:Signal("detached_from", self)
			self:Signal("detach")

			parent[_attach_list] = RemoveFrom(parent[_attach_list], self)
			self[_parent] = nil
		end
	end

	--- Draws a widget picture with rect (x, y, w, h).<br><br>
	-- If the widget has a color associated with the picture name, this is assigned to the
	-- picture's <b>"color"</b> property during the draw call.<br><br>
	-- This is a no-op if the picture does not exist.
	-- @param name Picture name.
	-- @param x Rect x-coordinate.
	-- @param y Rect y-coordinate.
	-- @param w Rect width.
	-- @param h Rect height.
	-- @see Widget:GetPicture
	-- @see Widget:SetPicture
	function Widget:DrawPicture (name, x, y, w, h)
		local pictures = self[_pictures]

		if pictures then
			local picture = CallOrGet(pictures[name])
			
			if picture then
				-- If a color override is specified, cache the picture's current color property
				-- and apply the override.
				local color = self:GetColor(name)
				local save

				if color then
					save = picture:GetProperty("color")

					picture:SetProperty("color", color)
				end

				-- Render the picture.
				picture:Draw(x, y, w, h)

				-- Restore original color if it was overridden.
				if color then
					picture:SetProperty("color", save)
				end
			end
		end
	end

	--- Accessor.
	-- @return Widget handle, or <b>nil</b> if the attach list is empty.
	-- @see Widget:GetAttachListHead
	function Widget:GetAttachListBack ()
		return Back(self[_attach_list])
	end

	--- Accessor.
	-- @return Widget handle, or <b>nil</b> if the attach list is empty.
	-- @see Widget:GetAttachListBack
	function Widget:GetAttachListHead ()
		return self[_attach_list]
	end

	--- Accessor.
	-- @return Border width; 0 by default.
	-- @return Border height; 0 by default.
	function Widget:GetBorder ()
		return self[_bw] or 0, self[_bh] or 0
	end

	-- Lazy table builder
	local function LazyTable (W, member)
		W[member] = W[member] or {}

		return W[member]
	end

	-- Getter helper
	local function LazyGet (W, member, k)
		return CallOrGet(LazyTable(W, member)[k])
	end

	--- Gets a widget color.<br><br>
	-- If a color is a function or callable object, it will be called and the result will
	-- be returned as the color.
	-- @param name Color name.
	-- @return Color, or <b>nil</b> if not available.
	-- @see Widget:SetColor
	function Widget:GetColor (name)
		return LazyGet(self, _colors, name)
	end

	--- Accessor.
	-- @return Font handle, of nil if absent.
	-- @see Widget:SetFont
	function Widget:GetFont ()
		return self[_font]
	end

	-- Returns: Group handle
	function Widget:GetGroup ()
		return self[_group]
	end

	--- Accessor.
	-- @return Height.
	-- @see Widget:SetH
	function Widget:GetH ()
		return self[_h]
	end

	--- Dummy ownership (a no-op), to be overridden by widgets that need it.
	-- @class function
	-- @name Widget:GetOwner
	Widget.GetOwner = funcops.NoOp

	-- Accessor.
	-- @return Parent widget handle, or <b>nil</b> if the widget is unattached.
	-- @see Widget:Attach
	-- @see Widget:IsAttached
	function Widget:GetParent ()
		return self[_parent]
	end

	--- Gets a widget picture.<br><br>
	-- If a picture is a function or callable object, it will be called and the result will
	-- be returned as the picture.
	-- @param name Picture name.
	-- @return Picture, or <b>nil</b> if not available.
	-- @see Widget:DrawPicture
	-- @see Widget:SetPicture
	function Widget:GetPicture (name)
		return LazyGet(self, _pictures, name)
	end

	--- Gets the widget's rectangle, in either absolute or relative coordinates, taking view
	-- origins into account. This is computed from the <b>GetX</b>, <b>GetY</b>, <b>GetW</b>,
	-- and <b>GetH</b> methods of the widgets along the chain of parents.
	-- @param is_absolute If true, compute global rectangle.
	-- @return x, y, w, h of final rectangle.
	-- @see Widget:ChainIter
	-- @see Widget:GetX
	-- @see Widget:GetY
	-- @see Widget:GetW
	-- @see Widget:GetH
	-- @see Widget:SetViewOrigin
	function Widget:GetRect (is_absolute)
		local x, y = 0, 0

		if is_absolute then
			for widget in self:ChainIter() do
				local dx, dy = widget:GetX(), widget:GetY()

				x, y = x + dx, y + dy

				if widget ~= self then
					local vx, vy = widget:GetViewOrigin()

					x, y = x - vx, y - vy
				end
			end

		else
			x, y = self:GetX(), self:GetY()
		end

		return x, y, self:GetW(), self:GetH()
	end

	--- Accessor.
	-- @return Shadow x-offset; 0 by default.
	-- @return Shadow y-offset; 0 by default.
	-- @see Widget:SetShadowOffsets
	function Widget:GetShadowOffsets ()
		return self[_sx] or 0, self[_sy] or 0
	end

	--- Gets the widget's string.<br><br>
	-- If this is a function or callable object, it will be called and the result will be
	-- returned as the string.
 	-- @return Widget string.
	-- @see Widget:SetString
	function Widget:GetString ()
		return CallOrGet(self[_string])
	end

	--- Accessor.
	-- @return View origin x-coordinate; 0 by default.
	-- @return View origin y-coordinate; 0 by default.
	-- @see Widget:SetViewOrigin
	function Widget:GetViewOrigin ()
		return self[_vx] or 0, self[_vy] or 0
	end

	--- Accessor.
	-- @return Width.
	-- @see Widget:SetW
	function Widget:GetW ()
		return self[_w]
	end

	--- Accessor.
	-- @return Local x-coordinate.
	-- @see Widget:SetX
	function Widget:GetX ()
		return self[_x]
	end

	--- Accessor.
	-- @return Local y-coordinate.
	-- @see Widget:SetY
	function Widget:GetY ()
		return self[_y]
	end

	--- Accessor.
	-- @param what Permission to query, which may be one of the following:<br><br>
	-- <b>"attach_list_render"</b>, <b>"attach_list_test"</b>, <b>"attach_list_update"</b>,
	-- <b>"render"</b>, <b>"test"</b>, <b>"update"</b>.
	-- @return If true, the callback will be run.
	-- @see Widget:Allow
	function Widget:IsAllowed (what)
		return Permissions[what] ~= nil and not self[what]
	end

	--- Accessor.
	-- @return If true, the widget is attached to a parent.
	-- @see Widget:Attach
	-- @see Widget:Detach
	function Widget:IsAttached ()
		return self[_parent] ~= nil
	end

	--- Accessor.
	-- @return If true, the cursor is within the widget.
	function Widget:IsEntered ()
		return self[_group]:GetEntered() == self
	end

	--- Accessor.
	-- @return If true, the cursor has grabbed the widget.
	function Widget:IsGrabbed ()
		return self[_group]:GetGrabbed() == self
	end

	--- Puts the widget at the head of its parent's attach list.<br><br>
	-- It is an error to call this if a root widget at the top of the chain is running a
	-- callback.
	-- @see Widget:GetAttachListHead
	function Widget:Promote ()
		assert(not self[_group]:IsRunningCallbacks(), "Promotion forbidden from callbacks")

        local parent = self[_parent]

		if parent then 
			parent[_attach_list] = AddAfter(parent[_attach_list], nil, self)
		end
	end

	--- Assigns border margins for use by various operations.
	-- @param w Width to assign; if <b>nil</b>, keep the current width.
	-- @param h Height to assign; if <b>nil</b>, keep the current height.
	-- @see Widget:GetBorder
	function Widget:SetBorder (w, h)
		self[_bw], self[_bh] = w or self[_bw], h or self[_bh]
	end

	-- Setter helper
	local function LazySet (W, member, k, v)
		LazyTable(W, member)[k] = v
	end

	--- Sets a widget color.
	-- @param name Color name.
	-- @param color Color to assign, or <b>nil</b> to clear the color.
	-- @see Widget:GetColor
	function Widget:SetColor (name, color)
		LazySet(self, _colors, name, color)
	end

	-- font: Font to assign.
	-------------------------
	function Widget:SetFont (font)
		self[_font] = font
	end

	--- Accessor.
	-- @param h Height to assign.
	-- @see Widget:GetH
	function Widget:SetH (h)
		self[_h] = h
	end

	--- Sets a widget picture.<br><br>
	-- A valid picture is any object that has at minimum the following methods:<br><br>
	-- <b>picture:Draw(x, y, w, h, props)</b>, which draws the picture in the rect (x, y,
	-- w, h). If present, <i>props</i> will be a table of (name, prop) pairs.<br>
	-- <b>picture:GetProperty(name)</b>, which returns the value of the requested property,
	-- or <b>nil</b> if absent.<br>
	-- <b>picture:SetProperty(name, value)</b>, which assigns the given property. The
	-- picture is free to disregard this if it has no use for the property.<br>
	-- @param name Picture name.
	-- @param picture Picture to assign, or <b>nil</b> to clear the picture.
	-- @see Widget:DrawPicture
	-- @see Widget:GetPicture
	function Widget:SetPicture (name, picture)
		LazySet(self, _pictures, name, picture)
	end

	--- Assigns shadow offsets for use by various render operations.
	-- @param x Shadow x-offset, or <b>nil</b>.
	-- @param y Shadow y-offset, or <b>nil</b>.
	-- @see Widget:GetShadowOffsets
	function Widget:SetShadowOffsets (x, y)
		self[_sx], self[_sy] = x, y
	end

	--- Accessor.
	-- @param string String to assign.
	-- @see Widget:GetString
	function Widget:SetString (string)
		self[_string] = string
	end

	--- Set the corner offset for this widget, relative to its parent. By default, this is
	-- (0, 0).<br><br>
	-- The origin is taken into consideration while computing areas in <b>UIGroup:Execute
	-- </b> and <b>UIGroup:Render</b>.
	-- @param x View origin x-coordinate; if <b>nil</b>, keep the current x-coordinate.
	-- @param y View origin y-coordinate; if <b>nil</b>, keep the current y-coordinate.
	-- @see Widget:GetRect
	-- @see Widget:GetViewOrigin
	function Widget:SetViewOrigin (x, y)
		self[_vx], self[_vy] = x or self[_vx], y or self[_vy]
	end

	--- Accessor.
	-- @param w Width to assign.
	-- @see Widget:GetW
	function Widget:SetW (w)
		self[_w] = w
	end

	--- Accessor.
	-- @param x Local x-coordinate to assign.
	-- @see Widget:GetX
	function Widget:SetX (x)
		self[_x] = x
	end

	--- Accessor.
	-- @param y Local y-coordinate to assign.
	-- @see Widget:GetY
	function Widget:SetY (y)
		self[_y] = y
	end
end,

--- Class constructor.
-- @class function
-- @name Constructor
-- @param group Group handle.
function(W, group)
    assert(IsType(group, "UIGroup"), "Invalid group")

	SuperCons(W, "Signalable")

	-- Owner group --
	W[_group] = group

	-- Signals --
	W:SetMultipleSignals(Signals)
end, { base = "Signalable" })