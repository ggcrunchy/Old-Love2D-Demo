-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local ipairs = ipairs
local type = type

-- Imports --
local ClearRange = varops.ClearRange
local Copy = table_ex.Copy
local Find = table_ex.Find
local IsType = class.IsType
local RotateIndex = numericops.RotateIndex
local WithBoundTable = table_ex.WithBoundTable

-- Unique member keys --
local _chain = {}
local _index = {}

-- FocusChain class definition --
class.Define("FocusChain", function(FocusChain)
	-- Clear helper
	-- F: Focus chain handle
	local function AuxClear (F)
		-- Remove the focus. Indicate that this is during a load.
		local focus = F:GetFocus()

		if focus then
			focus:Signal("lose_focus", F, true)
		end

		-- Detach focus items.
		local chain = F[_chain]

		for _, item in ipairs(F[_chain]) do
			item:Signal("remove_from_focus_chain", F)
		end
	end

	--- Removes all items in the chain.<br><br>
	-- If the chain is not empty, the item with focus is sent a signal as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>lose_focus(I, F, true)</b></i>,<br><br>
	-- where <i>I</i> is the item losing focus, <i>F</i> is this focus chain, and the <b>
	-- true</b> indicates that the focus was lost during a clear.<br><br>
	-- Each item in the chain is sent a signal as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>remove_from_focus_chain(I, F)</b></i>,<br><br>
	-- where <i>I</i> is the current item and <i>F</i> is this focus chain.
	function FocusChain:Clear ()
		AuxClear(self)

		ClearRange(self[_chain])
	end

	--- Information.
	-- @param item Item to seek.
	-- @return If true, the item is in the chain.
	function FocusChain:Contains (item)
		return Find(self[_chain], item, true) ~= nil
	end

	--- Accessor.
	-- @return Focus item, or <b>nil</b> if the chain is empty.
	-- @see FocusChain:GetIndex
	-- @see FocusChain:SetFocus
	function FocusChain:GetFocus ()
		if #self[_chain] > 0 then
			return self[_chain][self[_index]]
		end
	end

	--- Accessor.
	-- @return Focus index, or <b>nil</b> if the chain is empty.
	function FocusChain:GetIndex ()
		if #self[_chain] > 0 then
			return self[_index]
		end
	end

	--- Metamethod.
	-- @return Number of items in the chain.
	function FocusChain:__len ()
		return #self[_chain]
	end

	--- Loads the focus chain with items.<br><br>
	-- These items must derive from <b>"Signalable"</b>.<br><br>
	-- If the chain currently contains items, these are first cleared as per
	-- <b>FocusChain:Clear</b>.
	-- Each item added to the chain is sent a signal as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>add_to_focus_chain(I, F)</b></i>,<br><br>
	-- where <i>I</i> is the current item and <i>F</i> is this focus chain.<br><br>
	-- If any items were added, the first item will be the focus. It is sent a signal
	-- as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>gain_focus(I, F)</b></i>,<br><br>
	-- where <i>I</i> is the item gaining focus and <i>F</i> is this focus chain.
	-- @param items Ordered array of items to install.
	-- @see FocusChain:Clear
	function FocusChain:Load (items)
		-- Validate the new items.
		for _, item in ipairs(items) do
			assert(IsType(item, "Signalable"), "Unsignalable focus chain item")
		end

		-- Remove current items.
		AuxClear(self)

		-- Install the focus chain.
		local chain = self[_chain]

		WithBoundTable(chain, Copy, items, "overwrite_trim", nil, #chain)

		self[_index] = 1

		-- Attach focus items.
		for _, item in ipairs(chain) do
			item:Signal("add_to_focus_chain", self)
		end

		-- Give the first item focus.
		if #chain > 0 then
			chain[1]:Signal("gain_focus", self)
		end
	end

	--- Sets the current focus.<br><br>
	-- Focus changes will send two signals: The item losing focus will be sent a signal
	-- as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>lose_focus(I, F)</b></i>,<br><br>
	-- where <i>I</i> is the item and <i>F</i> is this focus chain. The item gaining focus
	-- will be sent a signal as<br><br>
	-- &nbsp&nbsp&nbsp<i><b>gain_focus(I, F)</b></i>,<br><br>
	-- where <i>I</i> is the item and <i>F</i> is this focus chain.
	-- @param focus Command or entry to assign.<br><br>
	-- If this is a number, it must be an integer between 1 and the item count, inclusive.
	-- This index will be assigned.<br><br>
	-- If it is one of the strings <b>"-"</b> or <b>"+"</b>, the index will be rotated one
	-- step backward or forward, respectively.<br><br>
	-- If neither of the above is the case, <i>focus</i> is assumed to be an item in the
	-- chain. In this case, the index is moved to that item. This is an error if the item
	-- is not present.
	-- @see FocusChain:GetFocus
	function FocusChain:SetFocus (focus)
		local cur = self:GetFocus()

		if cur then
			local index = self[_index]

			-- If a command is passed instead of a name, get the item index.
			if focus == "-" or focus == "+" then
				focus = RotateIndex(index, #self[_chain], focus == "-")

			-- Otherwise, find the index of the new focus.	
			else
				if type(focus) ~= "number" then
					focus = Find(self[_chain], focus, true)
				end

				assert(self[_chain][focus or 0], "Invalid focus entry")
			end

			-- On a switch, indicate that the old focus is lost and the new focus gained.
			if index ~= focus then
				cur:Signal("lose_focus", self)

				self[_index] = focus

				self[_chain][focus]:Signal("gain_focus", self)
			end
		end
	end
end,

--- Class constructor.
-- @class function
-- @name Constructor
function(F)
	F[_chain] = {}
end)