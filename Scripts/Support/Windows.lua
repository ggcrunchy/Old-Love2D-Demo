----------------------------
-- Standard library imports
----------------------------
local ipairs = ipairs

-----------
-- Imports
-----------
local getPosition = love.mouse.getPosition
local getHeight = love.graphics.getHeight
local getWidth = love.graphics.getWidth
local isDown = love.mouse.isDown
local mouse_left = love.mouse_left
local New = class.New
local PopScissorRect = graphics.PopScissorRect
local PushScissorRect = graphics.PushScissorRect
local WithResource = funcops.WithResource

----------------------
-- Mouse mode boolean
----------------------
local MouseMode = true

----------------
-- Focus chains
----------------
local Chains = table_ex.Weak("k")

-------------------------
-- Current context index
-------------------------
local Cur

-----------------------------------------------
-- Action maps: typically used one per context
-----------------------------------------------
local ActionMaps = {}

------------------------------
-- Per-context section groups
------------------------------
local SectionGroups = {}

-------------------------
-- Per-context UI groups
-------------------------
local UIGroups = {}

-- Export the windows namespace.
module "windows"

-- Allocate context-based data.
for i = 1, 5 do
	local slot = i
	local am

	-- Put the main context in slot 0. The first action map does double duty.
	if i < 5 then
--		am = New("ActionMap", i)
	else
--		am, slot = ActionMaps[1], 0
		slot = 0
	end

	-- Install data.
	ActionMaps[slot] = am
	SectionGroups[slot] = New("SectionGroup")
	UIGroups[slot] = New("UIGroup")
end

-- which: Optional action map index
-- Returns: Current or indexed action map handle
-------------------------------------------------
function ActionMap (which)
	return ActionMaps[which or Cur or 0]
end

-- group: Group to execute
-- data: Data used to produce input
------------------------------------
function Execute (group, data)
	local is_pressed, cx, cy

	-- In mouse mode, the cursor is at the mouse position.
	if MouseMode
	or true -- TODO: FIX
	then
		is_pressed = isDown(mouse_left)
		cx, cy = getPosition()

	-- Otherwise, the cursor is at local position (1, 1) of the widget with focus in the
	-- current section, or the origin if no such widget is available.
	else
		local focus = Chains[data] and Chains[data]:GetFocus()

		if focus then
			cx, cy = focus:GetRect(true)
		end

--		is_pressed = am:ButtonIsPressed("confirm")
		cx, cy = cx or 0, cy or 0
	end

	-- Send input to the group.
	group:Execute(cx, cy, is_pressed)
end

-- data: Section data
-- no_create: If true, do not create missing chain
-- Returns: Section's focus chain handle
---------------------------------------------------
function FocusChain (data, no_create)
	local chain = Chains[data]

	if not (chain or no_create) then
		chain = New("FocusChain")

		Chains[data] = chain
	end

	return chain
end

-- Returns: Current window dimensions
--------------------------------------
function GetSize ()
	return getWidth(), getHeight()
end

-- Returns: If true, mouse mode is active
------------------------------------------
function InMouseMode ()
	return MouseMode == true
end

-- group: Group to render
--------------------------
function Render (group)
	group:Render(PushScissorRect, PopScissorRect)
end

-- which: Optional section group index
-- Returns: Current or indexed section group handle
----------------------------------------------------
function SectionGroup (which)
	return SectionGroups[which or Cur or 0]
end

-- Switches to and from mouse mode
-----------------------------------
function ToggleMouseMode ()
	MouseMode = not MouseMode
end

-- which: Optional UI group index
-- Returns: Current or indexed UI group handle
-----------------------------------------------
function UIGroup (which)
	return UIGroups[which or Cur or 0]
end

-- Resource usage
-- func: Routine to perform
-- start: First index
-- final: Final index; if nil, same as start
---------------------------------------------
local function Use (_, func, start, final)
	for i = start, final or start do
		Cur = i

		func(i)
	end
end

-- Resource release
-- save: State to restore
--------------------------
local function Release (save)
	Cur = save or nil
end

-- Performs a routine with over a range of bound groups
-- func: Routine to perform
-- start: First index
-- final: Final index; if nil, same as start
--------------------------------------------------------
function WithBoundGroups (func, start, final)
	WithResource(nil, Use, Release, Cur or false, func, start, final)
end