-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local error = error
local insert = table.insert
local ipairs = ipairs
local remove = table.remove

-- Imports --
local New = class.New
local PointInBox = numericops.PointInBox
local RotateIndex = numericops.RotateIndex
local StateSwitch = widgetops.StateSwitch
local SuperCons = class.SuperCons

-- Unique member keys --
local _array = {}
local _choice = {}
local _oh = {}
local _ow = {}
local _sequence = {}

---
-- @class function
-- @name OptionSignals:drop

--
local function Drop (O)
	local radio = O:GetOwner()

	for i, option in ipairs(radio[_array]) do
		if option.part == O then
			radio:SetChoice(i)

			return
		end
	end

	error("Option not in radio")
end

-- Option class definition --
local u_OptionName = widgetops.DefineOwnedWidget(nil, function(O)
	O:SetSignal("drop", Drop)
end)

-- Inserts radio options
-- index: Insertion index
-- count: Count of options to insert
-- R: Radio handle
-- x, y: Option coordinates
-- data: Option data
local function Insert (index, count, R, x, y, data)
	local array = R[_array]

	for i = index, index + count - 1 do
		insert(array, i, { x = x, y = y, part = New(u_OptionName, R), data = data })
	end
end

-- Removes radio options
-- index: Removal index
-- count: Count of options to remove
-- R: Radio handle
local function Remove (index, count, R)
	local array = R[_array]

	for i = index + count - 1, index, -1 do
		remove(array, i)
	end
end

-- Stock signals --
local Signals = {}

--- The <b>"main"</b> picture is drawn with rect (x, y, w, h).<br><br>
-- The options are then drawn relative to (x, y). If an option is the choice, it is drawn
-- with the <b>"choice"</b> picture; otherwise, it uses the <b>"option"</b> picture.<br><br>
-- At the end, the <b>"frame"</b> picture is drawn with rect (x, y, w, h).
-- @param x Rect x-coordinate.
-- @param y Rect y-coordinate.
-- @param w Rect width.
-- @param h Rect height.
function Signals:render (x, y, w, h)
	self:DrawPicture("main", x, y, w, h)

	-- Draw normal options and the choice, as appropriate.
	local choice = self[_choice]:Get()
	local ow, oh = self[_ow], self[_oh]

	for i, option in ipairs(self[_array]) do
		self:DrawPicture(i == choice and "choice" or "option", x + option.x, y + option.y, ow, oh)
	end

	-- Frame the radio box.
	self:DrawPicture("frame", x, y, w, h)
end

--- Succeeds if (cx, cy) is inside (x, y, w, h) or an option, inside this rect.
-- @param cx Cursor x-coordinate.
-- @param cy Cursor y-coordinate.
-- @param x Bounding rect x-coordinate.
-- @param y Bounding rect y-coordinate.
-- @param w Bounding rect width.
-- @param h Bounding rect height.
-- @return On a successful test, returns the radio or an option widget.
function Signals:test (cx, cy, x, y, w, h)
	if PointInBox(cx, cy, x, y, w, h) then
		local ow, oh = self[_ow], self[_oh]

		for _, option in ipairs(self[_array]) do
			if PointInBox(cx, cy, x + option.x, y + option.y, ow, oh) then
				return option.part
			end
		end

		return self
	end
end

-- Radio class definition --
class.Define("Radio", function(Radio)
	--- Adds an option to the radio. If this was the first option, it sends a signal as<br><br>
	-- &nbsp&nbsp&nbsp<b><i>switch_to(R, "first")</i></b>,<br><br>
	-- where <i>R</i> refers to this radio.
	-- @param x Local x-coordinate.
	-- @param y Local y-coordinate.
	-- @param data User-defined option data.
	function Radio:AddOption (x, y, data)
		self[_sequence]:Insert(#self[_array] + 1, 1, self, x, y, data)

		-- Handle the first option.
		if #self[_array] == 1 then
			self:Signal("switch_to", "first")
		end
	end

	--- Clears the radio options.
	function Radio:Clear ()
		self[_sequence]:Remove(1, #self[_array], self)
	end

	--- Gets information about the radio's current choice.
	-- @return Choice index.
	-- @return User-defined option data, or <b>nil</b> if absent.
	-- @see Radio:SetChoice
	function Radio:GetChoice ()
		local index = self[_choice]:Get()

		return index, self[_array][index].data
	end

	--- Metamethod.
	-- @return Option count.
	function Radio:__len ()
		return #self[_array]
	end

	-- R: Radio handle
	-- choice: Choice to assign
	local function SetChoice (R, choice)
		R[_choice]:Set(choice)
	end

	--- Sets the current choice.<br><br>
	-- Choice index changes will send signals as<br><br>
	-- &nbsp&nbsp&nbsp<b><i>signal(R, "set_choice")</i></b>,<br><br>
	-- where <i>signal</i> will be <b>switch_from</b> or <b>switch_to</b>, and <i>R</i>
	-- refers to this radio.
	-- @param index Command or entry index to assign.<br><br>
	-- This may be an integer between 1 and the option count, inclusive, in which case that
	-- becomes the choice index.<br><br>
	-- Alternatively, this may be one of the strings <b>"-"</b> or <b>"+"</b>, which will
	-- rotate the choice one spot backward or forward, respectively.
	-- @param always_refresh If true, send the <b>"switch_to"</b> signal even when the choice
	-- index does not change.
	-- @see Radio:GetChoice
	function Radio:SetChoice (choice, always_refresh)
		local cur = self[_choice]:Get()

		if choice == "-" or choice == "+" then
			choice = RotateIndex(cur, #self[_array], choice == "-")
		end

		assert(choice > 0 and choice <= #self[_array], "Invalid choice")

		StateSwitch(self, choice ~= cur, always_refresh, SetChoice, "set_choice", choice)
	end

	--- Sets the current option dimensions.
	-- @param ow Option width; if <b>nil</b>, keep the current width.
	-- @param oh Option height; if <b>nil</b>, keep the current height.
	function Radio:SetDimensions (ow, oh)
		self[_ow], self[_oh] = ow or self[_ow], oh or self[_oh]
	end
end,

--- Class constructor.
-- @class function
-- @name Constructor
-- @param group Group handle.
-- @param ow Option width.
-- @param oh Option height.
function(R, group, ow, oh)
	SuperCons(R, "Widget", group)

	-- Option sequence --
	R[_sequence] = New("Sequence", function()
		return #R[_array]
	end, Insert, Remove)

	-- Chosen option --
	R[_choice] = R[_sequence]:CreateSpot(false, true)

	-- Options array --
	R[_array] = {}

	-- Option dimensions --
	R[_ow] = ow
	R[_oh] = oh

	-- Signals --
	R:SetMultipleSignals(Signals)
end, { base = "Widget" })