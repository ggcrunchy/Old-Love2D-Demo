-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local ipairs = ipairs

-- Imports --
local New = class.New
local PurgeAttachList = widgetops.PurgeAttachList
local RotateIndex = numericops.RotateIndex
local SuperCons = class.SuperCons
local StateSwitch = widgetops.StateSwitch

-- Unique member keys --
local _index = {}
local _margin = {}
local _pages = {}
local _timer = {}
local _to_left = {}

-- Page class definition --
local u_PageName = widgetops.DefineOwnedWidget()

-- M: Multipane handle
-- index: Index to assign
local function SetIndex (M, index)
	M[_index] = index
end

-- Multipane update signal
-- M: Multipane handle
-- dt: Time lapse
local function Update (M, dt)
	if M:IsFlipping() then
		local w, h = M:GetW(), M:GetH()

		-- On timeout, complete the flip.
		if M[_timer]:Check() > 0 then
			local pages = M[_pages]
			local index = M[_index]
			local next = RotateIndex(index, #pages, M[_to_left])

			-- Detach the transition page. Set the new page and view at the origin.
			local cur = pages[index]
			local new = pages[next]

			M:GetGroup():AddDeferredTask(function()
				cur:Detach()

				M:Attach(new, 0, 0, w, h)
				M:SetViewOrigin(0)
			end)

			-- Switch the page.
			StateSwitch(M, true, false, SetIndex, "flip", next)

		-- Otherwise, slide the view toward the new page.
		else
			local when = M[_timer]:GetCounter(true)

			M:SetViewOrigin((w + M[_margin]) * (M[_to_left] and 1 - when or when))

			M[_timer]:Update(dt)
		end
	end
end

-- MultiPane class definition --
class.Define("MultiPane", function(MultiPane)
	-- Adds a page to the multipane
	-- setup: Page setup routine
	--------------------------------
	function MultiPane:AddPage (setup)
		local pages = self[_pages]
		local new_page = New(u_PageName, self)
		local w, h = self:GetW(), self:GetH()

		-- Configure and load the page.
		new_page:SetPicture("main", self:GetPicture("page"))

		setup(new_page, w, h)

		pages[#pages + 1] = new_page

		-- If this is the first entry, put the page in view.
		if #pages == 1 then
			self:Attach(new_page, 0, 0, w, h)
			self:SetViewOrigin(0)

			-- Invoke a switch.
			self:Signal("switch_to", "first")
		end
	end

	-- Clears the multipane
	------------------------
	function MultiPane:Clear ()
		for _, page in ipairs(self[_pages]) do
			PurgeAttachList(page)

			page:Detach()
		end

		self[_pages] = {}
		self[_index] = 1

		self[_timer]:Stop()
	end

	-- Initiates a flip
	-- duration: Flip duration
	-- to_left: If true, flip left
	-------------------------------
	function MultiPane:Flip (duration, to_left)
		local pages = self[_pages]

		if not self:IsFlipping() and #pages > 1 then
			self[_to_left] = to_left

			self[_timer]:Start(duration)

			-- Put the transition and new page side by side, with some margin. Place the
			-- view on the transition page.
			local index = self[_index]
			local next = RotateIndex(index, #pages, to_left)
			local x2 = w + self[_margin]
			local curx = to_left and x2 or 0
			local w, h = self:GetW(), self:GetH()

			self:Attach(pages[index], curx, 0, w, h)
			self:Attach(pages[next], to_left and 0 or x2, 0, w, h)
			self:SetViewOrigin(curx)
		end
	end

	-- Returns: Current page
	-------------------------
	function MultiPane:GetPage ()
		return self[_index]
	end

	-- Returns: If true, multipane is flipping
	-------------------------------------------
	function MultiPane:IsFlipping ()
		return self[_timer]:GetDuration() ~= nil
	end

	-- Returns: Page count
	-----------------------
	function MultiPane:__len ()
		return #self[_pages]
	end

	-- margin: Inter-page margin to assign
	---------------------------------------
	function MultiPane:SetMargin (margin)
		self[_margin] = margin
	end
end,

--- Class constructor.
-- @class function
-- @name Constructor.
-- @param group Group handle.
function(M, group)
	SuperCons(M, "Widget", group)

	-- Currently referenced page --
	M[_index] = 1

	-- Margin between pages --
	M[_margin] = 0

	-- Page list --
	M[_pages] = {}

	-- Page switch timer --
	M[_timer] = New("Timer")

	-- Signals --
	M:SetSignal("update", Update)
end, { base = "Pane" })