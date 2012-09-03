-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local max = math.max
local min = math.min
local sub = string.sub
local type = type

-- Imports --
local ClampIn = numericops.ClampIn
local DrawString = widgetops.DrawString
local IsCallable = varops.IsCallable
local New = class.New
local StateSwitch = widgetops.StateSwitch
local StringGetW = widgetops.StringGetW
local SuperCons = class.SuperCons
local SwapIf = numericops.SwapIf

-- Cached methods --
local SetString = class.GetMember("Widget", "SetString")

-- Unique member keys --
local _blink = {}
local _chain = {}
local _cursor = {}
local _filter = {}
local _grabbed = {}
local _has_varied = {}
local _offset = {}
local _over = {}
local _selection = {}
local _sequence = {}

-- Fits a position to a character
-- E: Editbox handle
-- cx, cy: Cursor coordinates
-- Returns: Index of best-fit character
local function Fit (E, cx, cy)
	local font = E:GetFont()
	local string = E:GetString()

	if font and string ~= "" then
		local offset = E[_offset]:Get()
		local x = E:GetRect(true)

		return ClampIn(font:GetIndexAtOffset(sub(string, offset - 1), cx - x) + 1, offset, #string + 1, false)
	end
end

-- E: Editbox handle
-- Returns: If true, editbox can be treated as focused
local function IsFocused (E)
	return not E[_chain] or E[_chain]:GetFocus() == E
end

-- Inserts items into the editbox
-- index: Index of first character
-- E: Editbox handle
-- string: String to insert
local function Insert (index, _, E, string)
	local curstr = E:GetString()

	SetString(E, sub(curstr, 1, index - 1) .. string .. sub(curstr, index))
end

-- Removes items from the editbox
-- index: Index of first character
-- count: Count of characters to remove
-- E: Editbox handle
local function Remove (index, count, E)
	local curstr = E:GetString()

	SetString(E, sub(curstr, 1, index - 1) .. sub(curstr, index + count))
end

-- E: Editbox handle
-- index: Index to assign
local function SetCursor (E, index)
	E[_cursor]:Set(index)
end

-- Stock signals --
local Signals = {}

---
-- @param chain Reference to focus chain.
function Signals:add_to_focus_chain (chain)
	assert(self[_chain] == nil, "Editbox already in focus chain")

	self[_chain] = chain
end

---
function Signals:drop ()
	self[_grabbed]:Clear()
end

--- If the grabbed position is different from the cursor, sends signals as<br><br>
-- &nbsp&nbsp&nbsp<b><i>signal(E, "grab_cursor")</i></b>,<br><br>
-- where <i>signal</i> will be <b>"switch_from"</b> or <b>"switch_to"</b>, and <i>E</i>
-- refers to the signaled editbox.
-- @param state Execution state.
function Signals:grab (state)
	-- Get the best-fit character. Indicate that drag has yet to occur.
	local fit = Fit(self, state("cursor"))

	if fit then
		self[_over] = fit
		self[_has_varied] = false

		-- Remove any selection.
		self[_selection]:Clear()

		-- Place the cursor over and grab the appropriate character.
		StateSwitch(self, fit ~= self[_cursor]:Get(), false, SetCursor, "grab_cursor", fit)

		self[_grabbed]:Set(min(fit, #self:GetString()))

		-- If the editbox is in a focus chain, give it the focus.
		if self[_chain] then
			self[_chain]:SetFocus(self)
		end
	end
end

---
-- @param state Execution state.
function Signals:leave_upkeep (state)
	-- If the editbox is in a focus chain but has lost focus, quit. Otherwise, given a
	-- grab, select the drag range if the cursor fits to a character other than the grabbed
	-- one, or has done so already.
	local grabbed = self[_grabbed]:Get()

	if grabbed and IsFocused(self) then
		local fit = min(Fit(self, state("cursor")), #self:GetString())

		if self[_has_varied] or fit ~= grabbed then
			self[_has_varied] = true

			fit, grabbed = SwapIf(fit < grabbed, fit, grabbed)

			self[_selection]:Set(grabbed, fit - grabbed + 1)
		end
	end
end

---
function Signals:lose_focus ()
	self[_selection]:Clear()
end

---
function Signals:remove_from_focus_chain ()
	self[_chain] = nil
end

--- The <b>"main"</b> picture is drawn with rect (x, y, w, h).<br><br>
-- In the second phase, the enter logic passed to <b>UIGroup:Render</b> is first called. If
-- this returns a true value, the following is done: If there is a selection, it is drawn
-- using the <b>"highlight"</b> picture, stretched to fit the selected region. The visible
-- part of the string is drawn. If there is not a selection, and blinking is enabled, the
-- cursor is drawn using the <b>"cursor"</b> picture. Last of all, <b>UIGroup:Render</b>'s
-- leave logic is called.<br><br>
-- At the end, the <b>"frame"</b> picture is drawn with rect (x, y, w, h).
-- @param x Rect x-coordinate.
-- @param y Rect y-coordinate.
-- @param w Rect width.
-- @param h Rect height.
-- @param state Render state.
function Signals:render (x, y, w, h, state)
	self:DrawPicture("main", x, y, w, h)

	-- Clip the editbox's border region and draw its contents over the background.
	local bw, bh = self:GetBorder()
	local cx, cy, cw, ch = x + bw, y + bw, w - bw * 2, h - bh * 2

	if state("enter")(cx, cy, cw, ch) then
		local string = self:GetString()
		local start = self[_selection]:GetStart()

		if string ~= "" then
			local offset = self[_offset]:Get()
			local count = #self[_selection]

			if start and start + count > offset then
				-- If the selection begins after the offset, find the text width leading
				-- up to it, and move ahead that far. Otherwise, reduce the selection to
				-- account for entries before the offset.
				local begin = 0
				local sx = cx

				if start > offset then
					begin = start - offset

					sx = sx + StringGetW(self, sub(string, 1, begin))

				else
					count = count + start - offset
				end

				-- If the selection begins within the visible region, get the clipped
				-- width of the selected text and draw a box.
				self:DrawPicture("highlight", sx, cy, StringGetW(self, sub(string, begin + 1, begin + count)), ch)
			end
		end

		-- Draw the visible portion of the string.
		DrawString(self, string, "left", "center", cx, cy, cw, ch)

		-- Draw the cursor if and when it is visible and there is no selection.
		local cursor = self[_cursor]:Get() or 0
		local duration = self[_blink]:GetDuration()

		if IsFocused(self) and not start and duration and cursor >= (offset or 0) and self[_blink]:GetCounter() < duration / 2 then
			self:DrawPicture("cursor", cx + StringGetW(self, sub(string, 1, cursor - 1)), cy, StringGetW(self, " "), ch)
		end

		-- Exit the clipping area.
		state("leave")()
	end

	-- Frame the editbox.
	self:DrawPicture("frame", x, y, w, h)
end

--- Updates cursor blinking.
-- @param dt Time lapse.
function Signals:update (dt)
	self[_blink]:Update(dt)
	self[_blink]:Check("continue")
end

-- Editbox class definition --
class.Define("Editbox", function(Editbox)
	--- Adds text to the editbox.<br><br>
	-- If a selection is active, it is overwritten by the new text, and the selection is
	-- removed.<br><br>
	-- Otherwise, the text is inserted at the cursor location.<br><br>
	-- In either case, the cursor is then placed at the end of the new text. The string is
	-- first passed through the filter, if present.
	-- @param text Text string to add.
	-- @see Editbox:SetFilter
	function Editbox:AddText (text)
		if #self[_selection] > 0 then
			self:RemoveText(false)
		end

		local filter = self[_filter]

		if filter then
			text = filter(self, text) or ""
		end

		if #text > 0 then
			local cursor = self[_cursor]:Get()

			self[_sequence]:Insert(cursor, #text, self, text)

			self[_cursor]:Set(cursor + #text)
		end
	end

	-- Creates an interval on the editbox.
	-- Returns: Interval handle.
	function Editbox:CreateInterval ()
		return self[_sequence]:CreateInterval()
	end

	-- Creates a spot on the editbox.
	-- is_add_spot: If true, spot can be immediately after the editbox.
	-- can_migrate: If true, spot can migrate on removal.
	-- Returns: Spot handle.
	function Editbox:CreateSpot (is_add_spot, can_migrate)
		return self[_sequence]:CreateSpot(is_add_spot, can_migrate)
	end

	--- Gets the current location of the cursor.
	-- @return Cursor offset.
	function Editbox:GetCursor ()
		if #self[_selection] == 0 then
			return self[_cursor]:Get()
		end
	end

	--- Gets information about the currently selected text.
	-- @return Selection string; if there is no selection, this is the empty string.
	-- @return If there is a selection, its starting location.
	-- @return If there is a selection, the number of selected characters.
	function Editbox:GetSelection ()
		local start = self[_selection]:GetStart()

		if start then
			local count = #self[_selection]

			return sub(self:GetString(), start, start + count - 1), start, count
		end

		return ""
	end

	--- Removes text from the editbox.<br><br>
	-- If any text is selected, it will be removed and the cursor placed at the start
	-- location.<br><br>
	-- Otherwise, the character at the cursor is removed. If "backspace" is requested, the
	-- cursor is first moved back one spot.
	-- @param back If true, perform a backspace-style deletion.
	function Editbox:RemoveText (back)
		local start = self[_selection]:GetStart()

		if start then
			local count = #self[_selection]

			self[_sequence]:Remove(start, count, self)

			self[_cursor]:Set(start)

		else
			local cursor = self[_cursor]:Get() + (back and -1 or 0)

			if cursor >= 1 then
				self[_sequence]:Remove(cursor, 1, self)
			end
		end
	end

	--- Sets the current cursor position. Any selection is cleared. If there was a selection,
	-- and a move command was specified, the cursor will be placed either before or after the
	-- selection range.<br><br>
	-- Position changes will send signals as<br><br>
	-- &nbsp&nbsp&nbsp<b><i>signal(E, "set_cursor")</i></b>,<br><br>
	-- where <i>signal</i> will be <b>"switch_from"</b> or <b>"switch_to"</b>, and <i>E</i>
	-- refers to this editbox.
	-- <br><br>TODO: Handle setting the cursor while it isn't in view
	-- @param index Command or entry index to assign; this may be a number between 1 and the
	-- string length + 1, or one of the strings <b>"-"</b> or <b>"+"</b>, which will move the
	-- cursor one spot backward or forward, respectively (clamped at the ends).
	-- @param always_refresh If true, receive <b>"switch_to"</b> signals even when the cursor
	-- index does not change.
	function Editbox:SetCursor (index, always_refresh)
		-- Cache the selection interval and clear it.
		local start = self[_selection]:GetStart()
		local count = #self[_selection]

		self[_selection]:Clear()

		-- On a command, move the cursor according to whether a selection was cleared.
		-- Update the cursor index.
		local cursor = self[_cursor]:Get()
		local string = self:GetString()

		if index == "-" then
			index = max(start or cursor - 1, 1)
		elseif index == "+" then
			index = min(start and start + count or cursor + 1, #string + 1)
		end

		assert(index > 0 and index <= #string + 1, "Invalid cursor")

		StateSwitch(self, index ~= cursor, always_refresh, SetCursor, "set_cursor", index)

		-- Put the selection in view if it switched while out of view.
--[[
		local offset = self[_offset]:Get()
		if index < offset then
			self[_offset]:Set(index)
		elseif index >= offset + #L.view then
			self[_offset]:Set(index - #L.view + 1)
		end
]]
	end

	--- Sets the current filter function. A filter should be a function with signature:<br><br>
	-- &nbsp&nbsp&nbsp<b><i>filter(E, text)</i></b>,<br><br>
	-- where <i>E</i> refers to this editbox and <i>text</i> to the string being assigned.
	-- Its return value is the filtered text.
	-- @param filter Filter to assign; if <b>nil</b>, filtering is disabled.
	-- @see Editbox:AddText
	-- @see Editbox:SetString
	function Editbox:SetFilter (filter)
		assert(filter == nil or IsCallable(filter), "Uncallable filter")

		self[_filter] = filter
	end

	--- Override of <b>Widget:SetString</b>. The current string is overwritten, affecting
	-- any spots or intervals watching the sequence. Any selection is removed. The cursor
	-- is placed after the new string.<br><br>
	-- The string is first passed through the filter, if present.
	-- @param string String to assign.
	-- @see Editbox:SetFilter
	function Editbox:SetString (string)
		self[_selection]:Set(1, #self:GetString())

		self:AddText(string or "")
	end

	--- Sets the cursor blink timeout.
	-- @param timeout Timeout value to assign, in fraction of seconds; if <b>nil</b>, the
	-- cursor is disabled (the default).
	function Editbox:SetTimeout (timeout)
		assert(timeout == nil or (type(timeout) == "number" and timeout > 0), "Invalid timeout")

		if timeout then
			self[_blink]:Start(timeout)
		else
			self[_blink]:Stop()
		end
	end
end,

--- Class constructor.
-- @class function
-- @name Constructor
-- @param group Group handle.
function(E, group)
	SuperCons(E, "Widget", group)

	-- Character sequence --
	E[_sequence] = New("Sequence", function()
		return #E:GetString()
	end, Insert, Remove)

	SetString(E, "")

	-- Cursor position --
	E[_cursor] = E[_sequence]:CreateSpot(true, true)

	-- Offset where editbox is grabbed --
	E[_grabbed] = E[_sequence]:CreateSpot(true, false)

	E[_grabbed]:Clear()

	-- Offset from which to begin rendering --
	E[_offset] = E[_sequence]:CreateSpot(false, true)

	-- Selected text --
	E[_selection] = E[_sequence]:CreateInterval()

	-- Blink timer --
	E[_blink] = New("Timer")

	-- Signals --
	E:SetMultipleSignals(Signals)
end, { base = "Widget" })