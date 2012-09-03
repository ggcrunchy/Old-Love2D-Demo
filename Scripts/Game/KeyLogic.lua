----------------------------
-- Standard library imports
----------------------------
local assert = assert
local char = string.char
local ipairs = ipairs
local remove = table.remove
local type = type
local upper = string.upper

-----------
-- Modules
-----------
local love = love

-----------
-- Imports
-----------
local ClearRange = varops.ClearRange
local CullingForEach = table_ex.CullingForEach
local ForEach = table_ex.ForEach
local Identity = funcops.Identity
local isDown = love.keyboard.isDown
local IsInteger = varops.IsInteger
local New = class.New
local NoOp = funcops.NoOp

-- Export the key logic namespace.
module "keylogic"

------------------------------
-- Key handlers for each type
------------------------------
local Handlers = New("Multimethod", 1)

Handlers:Define(NoOp)

--------------------------------------------
-- Key states in use; cache of unused state
--------------------------------------------
local States, Cache = {}, {}

-- Clear helper
----------------
local function AuxClear (state)
	state.timer:Stop()

	Cache[#Cache + 1] = state
end

-- Clears all key state
------------------------
function Clear ()
	ForEach(States, AuxClear, true)

	ClearRange(States)
end

-- State update on key press
-- timeout: Optional repeat timeout
------------------------------------
function KeyPressed (key, timeout)
	assert(IsInteger(key) and key >= 0, "Invalid key")
	assert(timeout == nil or (type(timeout) == "number" and timeout > 0), "Invalid timeout")

	local state = remove(Cache) or { timer = New("Timer") }

	state.key = key
	state.first = true

	if timeout then
		state.timer:Start(timeout)
	end

	States[#States + 1] = state
end

-- State update on key release
-------------------------------
function KeyReleased (key)
	assert(IsInteger(key) and key >= 0, "Invalid key")

	-- Clear any state for this key.
	for i, state in ipairs(States) do
		if state.key == key then
			AuxClear(state)

			States[i] = nil

			return
		end
	end
end

-- Repeat count helper
-----------------------
local function RepeatCount (state)
	local count = state.first and 1 or 0

	count = count + state.timer:Check("continue")

	state.first = false

	return count
end

-- Updates key state for a focus chain
-- chain: Focus chain handle
-- dt: Time lapse
---------------------------------------
function Update (chain, dt)
	-- Remove dead states.
	CullingForEach(States, Identity, nil, true)

	-- Pass key input to the focus.
	local focus = chain:GetFocus()

	for _, state in ipairs(States) do
		local key = state.key

		for _ = 1, RepeatCount(state) do
			Handlers(focus, key)
		end

		state.timer:Update(dt)
	end
end

-- Editbox key handler --
Handlers:Define(function(E, key)
	-- Backspace and delete --
	if key == love.key_backspace or key == love.key_delete then
		E:RemoveText(key == love.key_backspace)

	-- Left and right --
	elseif key == love.key_left or key == love.key_right then
		E:SetCursor(key == love.key_left and "-" or "+")

	-- Space, underscore, and numerals --
	elseif key == love.key_space or key == love.key_underscore or (key >= love.key_0 and key <= love.key_9) then
		E:AddText(char(key))

	-- A-Z --
	elseif key >= love.key_a and key <= love.key_z then
		local kvalue = char(key)
		local shift = isDown(love.key_lshift) or isDown(love.key_rshift)

		E:AddText(shift and upper(kvalue) or kvalue)
	end
end, "Editbox")

