-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local pairs = pairs

-- Imports --
local Define = class.Define
local New = class.New
local NoOp = funcops.NoOp
local SuperCons = class.SuperCons
local Type = class.Type
local Weak = table_ex.Weak

-- Export widgetops namespace.
module "widgetops"

-- Attach a widget to its root
-- widget: Widget handle
-- x, y: Widget coordinates
-- w, h: Widget dimensions
-- bPromote: If true, promote the widget
-- TODO: Get rid of this!!!
function AttachToRoot (widget, x, y, w, h, bPromote)
    widget:GetGroup():GetRoot():Attach(widget, x, y, w, h)

    if bPromote then
        widget:Promote()
    end
end

-- Augments a signal call
-- O: Signallable object
-- how: Augmentation style
-- slot: Slot to augment
-- func: Function to add
-- defcore: Optional default core
-- Returns: Augmented function handle
-- TODO: Move this into Support??
function AugmentSignal (O, how, slot, func, defcore)
	local signal = O:GetSignal(slot) or defcore

	-- If the signal is not yet augmented, make it so.
	if Type(signal) ~= "AugmentedFunction" then
		signal = New("AugmentedFunction", signal)
	end

	-- Attach the new function as appropriate.
	assert(how == "after" or how == "before", "Unsupported augmentation style")

	if how == "after" then
		signal:AddAfter(func)
	else
		signal:AddBefore(func)
	end

	-- Install the signal.
	O:SetSignal(slot, signal)

	-- Supply the function in case more is to be done with it.
	return signal
end

--- Renders a widget that behaves like a button. This will draw one of these pictures with
-- rect (x, y, w, h), based on the current widget state: <b>"main"</b>, <b>"grabbed"</b>,
-- or <b>"entered"</b>.
-- @param W Widget handle.
-- @param x Rect x-coordinate.
-- @param y Rect y-coordinate.
-- @param w Rect width.
-- @param h Rect height.
function ButtonStyleRender (W, x, y, w, h)
	local picture = "main"
	local is_grabbed = W:IsGrabbed()
	local is_entered = W:IsEntered()

	if is_grabbed and is_entered then
		picture = "grabbed"
	elseif is_grabbed or is_entered then
		picture = "entered"
	end

	W:DrawPicture(picture, x, y, w, h)
end

do
	-- Owners of owned widgets --
	local Owners = Weak("v")

	-- W: Owned widget handle
	-- Returns: Owner handle
	local function GetOwner (W)
		return Owners[W]
	end

	--- Defines an owned proxy widget class.
	-- @param members Members table; will be a dummy table if absent.
	-- @param cons Post-boilerplate constructor portion; will be a no-op if absent.
	-- @param params Non-default params; will be a dummy table if absent.
	-- @return Type name.
	function DefineOwnedWidget (members, cons, params)
		-- If necessary, set default arguments.
		cons = cons or NoOp
		members = members or {}
		params = params or {}

		-- Install defaults.
		members.GetOwner = GetOwner

		params.base = "Widget"
		params.bHidden = true

		-- Define the widget type, given a private name.
		local type = {}

		Define(type, members, function(W, owner, ...)
			SuperCons(W, "Widget", owner:GetGroup())

			-- Perform type-specific construction.
			cons(W, owner, ...)

			-- Bind owner.
			Owners[W] = owner
		end, params)

		return type
	end
end

-- Binds listener tasks to an object
-- O: Object handle.
-- group: Group handle.
-- live: Live object table.
-- tasks: Tasks to bind.
-- TODO: Improve this so that groups can be removed
function ListenToTasks (O, group, live, tasks)
	-- Install listeners.
	local key = {}

	for k, func in pairs(tasks) do
		group:AddListenerTask(k, function()
			local object = live[key]

			if object then
				func(object)

				return true
			end
		end)
	end

	-- Register the object so its tasks persist while it lives.
	live[key] = O
end

-- Detach all children from a widget.
-- W: Widget handle.
-- TODO: Move to Support??
function PurgeAttachList (W)
	repeat
		local widget = W:GetAttachListHead()

		if widget then
			widget:Detach()
		end
	until not widget
end

--- Assigns local rect fields.
-- @param W Widget handle.
-- @param x Local x-coordinate to assign.
-- @param y Local y-coordinate to assign.
-- @param w Width to assign.
-- @param h Height to assign.
function SetLocalRect (W, x, y, w, h)
	W:SetX(x)
	W:SetY(y)
	W:SetW(w)
	W:SetH(h)
end

--- Performs a state switch, with an optional in-between action.<br><br>
-- On a switch, the widget will be sent a signal as<br><br>
-- &nbsp&nbsp&nbsp<b><i>switch_from(W, what)</i></b>,<br><br>
-- where <i>W</i> will refer to the current widget and <i>what</i> is
-- some value related to the switch. The action is then performed. Then, the widget will
-- be sent a signal as<br><br>
-- &nbsp&nbsp&nbsp<b><i>switch_to(W, what)</i></b>,<br><br>
-- with <i>W</i> and <i>what</i> the same as before.<br><br>
-- @param W Widget handle.
-- @param do_switch If true, perform the switch.
-- @param always_refresh If true, the <b>"switch_to"</b> logic is still performed even
-- if the state did not change.
-- @param action Embedded action; this will be a no-op if absent.
-- @param what Action description.
-- @param arg Action argument.
function StateSwitch (W, do_switch, always_refresh, action, what, arg)
	if do_switch then
		W:Signal("switch_from", what)

		;(action or NoOp)(W, arg)

		W:Signal("switch_to", what)

	elseif always_refresh then
		W:Signal("switch_to", what)
	end
end

do
	-- Intermediate properties --
	local Props = {}

	-- Helper for common string operation
	-- func: Internal function
	-- W: Widget handle
	-- str: String to process
	-- ...: Operation arguments
	-- Returns: Function return values
	local function WithFontAndStr (func, W, str, ...)
		local font = W:GetFont()
		local ret1, ret2

		if font and str then
			font:SetLookupKey(W)

			ret1, ret2 = func(W, str, font, ...)

			font:SetLookupKey(nil)
		end

		return ret1, ret2
	end

	-- Draw string helper
	local function AuxDrawString (W, str, font, halign, valign, x, y, w, h, color, shadow_color)
		-- Adjust the coordinates to match the alignment.
		local dx, dy = font:GetAlignmentOffsets(str, w, h, halign, valign)

		x, y = x + dx, y + dy

		-- Draw any shadow string.
		local sx, sy = W:GetShadowOffsets()

		if sx ~= 0 or sy ~= 0 then
			Props.color = W:GetColor(shadow_color or "shadow")

			font(str, x + sx, y + sy, Props)
		end

		-- Draw the main string.
		Props.color = W:GetColor(color or "string")

		font(str, x, y, Props)

		-- Clear the settings.
		Props.color = nil
	end

	--- Renders a string, with optional shadowing.
	-- @param W Widget handle.
	-- @param str String to draw.
	-- @param halign Horizontal alignment, which may be one of the following: <b>"left"</b>,
	-- <b>"center"</b>, or <b>"right"</b>; if absent, <b>"left"</b> is assumed.
	-- @param valign Vertical alignment, which may be one of the following: <b>"top"</b>,
	-- <b>"center"</b>, or <b>"bottom"</b>; if absent, <b>"top"</b> is assumed.
	-- @param x Draw position x-coordinate.
	-- @param y Draw position y-coordinate.
	-- @param w Width, used for non-<b>"left"</b> alignment.
	-- @param h Height, used for non-<b>"top"</b> alignment.
	-- @param color Name of string color; if <b>nil</b>, <b>"string"</b> is used.
	-- @param shadow_color Name of shadow color; if <b>nil</b>, <b>"shadow"</b> is used.
	function DrawString (W, str, halign, valign, x, y, w, h, color, shadow_color)
		WithFontAndStr(AuxDrawString, W, str, halign, valign, x, y, w, h, color, shadow_color)
	end

	-- Height helper
	local function AuxGetH (_, str, font, with_padding)
		return font:GetHeight(str, with_padding)
	end

	--- Information.
	-- @param W Widget handle.
	-- @param str String to measure.
	-- @param with_padding If true, include line padding.
	-- @return String height.
	function StringGetH (W, str, with_padding)
		return WithFontAndStr(AuxGetH, W, str, with_padding) or 0
	end

	-- Size helper
	local function AuxGetSize (_, str, font, with_padding)
		return font:GetWidth(str), font:GetHeight(str, with_padding)
	end

	--- Information.
	-- @param W Widget handle.
	-- @param str String to measure.
	-- @param with_padding If true, include line padding.
	-- @return String dimensions.
	function StringSize (W, str, with_padding)
		local w, h = WithFontAndStr(AuxGetSize, W, str, with_padding)

		return w or 0, h or 0
	end

	-- Width helper
	local function AuxGetW (_, str, font)
		return font:GetWidth(str)
	end

	--- Information.
	-- @param W Widget handle.
	-- @param str String to measure.
	-- @return String width.
	function StringGetW (W, str)
		return WithFontAndStr(AuxGetW, W, str) or 0
	end
end