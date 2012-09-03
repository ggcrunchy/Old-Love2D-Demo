-- Standard library imports --
local wrap = coroutine.wrap

-- Imports --
local ApplyScissorState = graphics.ApplyScissorState
local GetEventStream = section.GetEventStream
local KeyPressed = keylogic.KeyPressed
local KeyReleased = keylogic.KeyReleased
local SectionGroup = windows.SectionGroup
local WithBoundGroups = windows.WithBoundGroups

-- Modules --
local coroutineops = coroutineops
local love = love
local tasks = tasks

-- Install a default time lapse function.
funcops.SetTimeLapseFunc(nil, love.timer.getDelta)

-- Set the current language.
settings.SetLanguage("english")

-- Export the game namespace.
module "game"

-- Actions in progress? --
local KeyActionStates = {}

-- Specialized key actions --
local KeyActions = {}

-- F4 state --
local F4_WasPressed

-- Install a timed task that runs for 7/10ths of a second --
KeyActions[love.key_f1] = function()
	local updates = 0

	GetEventStream("leave_update"):Add(tasks.WithTimer(
		.7,	-- TIMED TASK DURATION --

		function()	-- UPDATE FUNCTION --
			updates = updates + 1
		end,

		function()	-- QUIT FUNCTION --
			printf("Timed task done! %i updates", updates)

			KeyActionStates[love.key_f1] = false
		end)
	)
end

-- Install a periodic task that goes off every second --
KeyActions[love.key_f2] = function()
	local update = 0

	GetEventStream("leave_update"):Add(tasks.WithPeriod(
		1,	-- TIMEOUT DURATION --

		function()
			update = update + 1

			printf("Periodic timeout #%i", update)
		end)
	)
end

-- Install a coroutine as a task --
KeyActions[love.key_f3] = function()
	local func = wrap(function()
		printf("Starting coroutine event, waiting 1.5 seconds, then printing for a couple seconds...")

		coroutineops.Wait(1.5, nil, nil, true)	-- yvalue of true so that the coroutine op yields true and event persists in stream
		coroutineops.Wait(2, function(time)
			printf("Update at time: %f", time)
		end, nil, true)

		printf("Waiting for user to press F4")

		coroutineops.WaitUntil(function()
			return F4_WasPressed
		end, nil, nil, true)

		printf("Ending coroutine event")

		F4_WasPressed = false
		KeyActionStates[love.key_f3] = false
	end)

	GetEventStream("leave_update"):Add(func)
end

-- Helper function to cooperate with coroutine task --
KeyActions[love.key_f4] = function()
	F4_WasPressed = true

	KeyActionStates[love.key_f4] = false
end

do
	-- Key pressed function --
	function keypressed (key)
	    if not KeyActions[key] then
		    KeyPressed(key, .15)
        end
	end

	-- Key released function --
	function keyreleased (key)
	    if KeyActions[key] then
			if not KeyActionStates[key] then
				KeyActionStates[key] = true

				KeyActions[key]()
			end
        else
			KeyReleased(key)
		end
	end
end

do
	-- Render body
	---------------
	local function Render ()
		SectionGroup()("render")
	end

	-- Draw function --
	function draw ()
		-- If necessary, restore the scissor state.
		ApplyScissorState()

		--
		WithBoundGroups(Render, 0)
	end
end

do
	local DT

	-- Between body
	----------------
	local function Between ()
		GetEventStream("between_frames")()
	end

	-- Trap body
	-------------
	local function Trap ()
		SectionGroup()("trap")
	end

	-- Update body
	---------------
	local function Update ()
		SectionGroup()("update", DT)
	end

	-- Update function --
	function update (dt)
		DT = dt

		WithBoundGroups(Between, 0)
		WithBoundGroups(Trap, 0)
		WithBoundGroups(Update, 0)
	end
end