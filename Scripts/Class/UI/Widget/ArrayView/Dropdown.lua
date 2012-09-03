-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local ipairs = ipairs
local max = math.max
local min = math.min
local pairs = pairs

-- Imports --
local DrawString = widgetops.DrawString
local Find = table_ex.Find
local ListenToTasks = widgetops.ListenToTasks
local PointInBox = numericops.PointInBox
local StateSwitch = widgetops.StateSwitch
local SuperCons = class.SuperCons

-- Cached methods --
local GetH = class.GetMember("Widget", "GetH")

-- Unique member keys --
local _heading = {}
local _pick = {}
local _scroll_set = {}

-- Event listener set --
local Listeners = table_ex.Weak("v")

-- Listener task table --
local ListenerTasks = {}

function ListenerTasks:grab ()
	if self[_pick] then
		local grabbed = self:GetGroup():GetGrabbed()

		if self ~= grabbed and not Find(self[_scroll_set], grabbed) then
			self:SetOpen(false)
		end
	end
end

-- D: Dropdown handle
-- heading: Heading to assign
local function SetHeading (D, heading)
	D[_heading] = heading
end

-- D: Dropdown handle
-- pick: Pick to assign
local function SetPick (D, pick)
	D[_pick] = pick
end

-- Stock part signals --
local PartSignals = {}

---
function PartSignals:drop ()
	local dropdown = self:GetOwner()
	local heading = dropdown.offset:Get() + Find(dropdown.view, self, true) - 1

	StateSwitch(dropdown, heading ~= dropdown:GetHeading(), false, SetHeading, "click_item", heading)
end

---
function PartSignals:enter ()
	local dropdown = self:GetOwner()
	local pick = dropdown.offset:Get() + Find(dropdown.view, self, true) - 1

	StateSwitch(dropdown, pick ~= dropdown[_pick], false, SetPick, "pick", pick)
end

-- Stock signals --
local Signals = {}

---
function Signals:bind_as_scroll_target (targeter, how)
	self[_scroll_set][how] = targeter

	-- Put the targeter into a matching state.
	local is_open = self:IsOpen()

	targeter:Allow("render", is_open)
	targeter:Allow("test", is_open)
end

---
function Signals:grab ()
	self:SetOpen(not self[_pick])
end

---
function Signals:render (x, y, w, h)
	local dh = h
	local size = #self

	-- Partition the dropdown height between the heading and backdrop.
	if self[_pick] then
		dh = dh / (min(size, #self.view) + 1)
	end

	-- Draw the dropdown heading.
	self:DrawPicture("heading", x, y, w, dh)

	-- If the dropdown is not empty, draw the heading text.
	if size > 0 then
		DrawString(self, self:GetHeading(), "center", "center", x, y, w, dh)

		-- If the box is open, draw the backdrop below the heading.
		if self[_pick] then
			local backy = y + dh
			local pick = self[_pick]

			self:DrawPicture("backdrop", x, backy, w, h - dh)

			-- Iterate through the visible items. If an item is picked, highlight it.
			-- Draw any string attached to the item and go to the next line.
			for i, text in self:View() do
				if i == pick then
					self:DrawPicture("highlight", x, backy, w, dh)
				end

				DrawString(self, text, "center", "center", x, backy, w, dh)

				backy = backy + dh
			end
		end
	end

	-- Frame the dropdown.
	self:DrawPicture("frame", x, y, w, dh)
end

---
function Signals:test (cx, cy, x, y, w, h)
	if PointInBox(cx, cy, x, y, w, h) then
		if self[_pick] then
			local index, dh = 0, h / (min(#self, #self.view) + 1)

			for _ in self:View() do
				index, y = index + 1, y + dh

				if cy >= y and cy < y + dh then
					 return self.view[index]
				end
			end
		end

		return self
	end
end

---
function Signals:unbind_as_scroll_target (_, how)
	self[_scroll_set][how] = nil
end

-- Dropdown class definition --
class.Define("Dropdown", function(Dropdown)
	-- Adds an entry to the end of the dropdown
	-- text: Text to assign
	-- ...: Entry members
	--------------------------------------------
	function Dropdown:Append (text, ...)
		local old_size = #self

		self:AddEntry(old_size + 1, text, ...)

		-- Handle the first entry.
		if old_size == 0 then
			self:Signal("switch_to", "first")
		end
	end

	-- Returns: Heading entry text, members
	----------------------------------------
	function Dropdown:GetHeading ()
		return self:GetEntry(self:Heading())
	end

	-- GetH override
	-----------------
	function Dropdown:GetH ()
		local offset = self[_pick] and min(#self, #self.view) or 0

		return (offset + 1) * GetH(self)
	end

	-- Returns: Pick index
	-----------------------
	function Dropdown:GetPick ()
		return self[_pick]
	end

	-- Returns: Heading index
	--------------------------
	function Dropdown:Heading ()
		return self[_heading] or 1
	end

	-- Returns: If true, the dropdown is open
	------------------------------------------
	function Dropdown:IsOpen ()
		return self[_pick] ~= nil
	end

	-- Picks an entry
	-- index: Command or entry index
	-- always_refresh: If true, refresh on no change
	-------------------------------------------------
	function Dropdown:Pick (index, always_refresh)
		local pick = self[_pick]

		if pick then
			local size = #self

			if index == "-" then
				index = max(pick - 1, 1)
			elseif index == "+" then
				index = min(pick + 1, size)
			end

			assert(index > 0 and index <= size, "Invalid pick")

			StateSwitch(self, index ~= pick, always_refresh, SetPick, "pick", index)

			-- Put the pick in view if it switched while out of view.
			local offset = self.offset:Get()

			if index < offset then
				self.offset:Set(index)
			elseif index >= offset + #self.view then
				self.offset:Set(index - #self.view + 1)
			end
		end
	end

	-- heading: Heading to assign
	-- always_refresh: If true, refresh on no change
	-------------------------------------------------
	function Dropdown:SetHeading (heading, always_refresh)
		StateSwitch(self, heading ~= self:GetHeading(), always_refresh, SetHeading, "set_heading", heading)
	end

	-- open: Open state to assign
	------------------------------
	function Dropdown:SetOpen (open)
		if not open ~= not self[_pick] then
			if open then
				if #self > 0 then
					-- Prioritize scroll set callbacks within the attach list.
					self:Promote()

					for _, component in pairs(self[_scroll_set]) do
						component:Promote()
					end

					-- Pick the heading and open the dropdown on it.
					self[_pick] = self:Heading()

					self.offset:Set(self[_pick])

					-- Report the opening.
					self:Signal("switch_to", "open")
				end

			else
				self:Signal("switch_from", "open")

				self[_pick] = nil
			end

			-- Enable or disable the scroll set as necessary.
			for _, component in pairs(self[_scroll_set]) do
				component:Allow("render", open)
				component:Allow("test", open)
			end
		end
	end
end,

--- Class constructor.
-- @class function
-- @name Constructor.
-- @param group: Group handle.
-- @param capacity: Dropdown capacity.
function(D, group, capacity)
	SuperCons(D, "ArrayView", group, capacity)

	-- Scroll control tracking --
	D[_scroll_set] = {}

	-- View part signals --
	for _, part in ipairs(D.view) do
		part:SetMultipleSignals(PartSignals)
	end

	-- Signals --
	D:SetMultipleSignals(Signals)

	-- Listeners --
	ListenToTasks(D, group, Listeners, ListenerTasks)
end, { base = "ArrayView" })