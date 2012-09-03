-- See TacoShell Copyright Notice in main folder of distribution

-----------
-- Imports
-----------
local setScissor = love.graphics.setScissor
local sleep = love.timer.sleep

-------------------
-- Delayed imports
-------------------
local console
local game
local printf

-- Game loader
---------------
function load ()
	-- Install a loader.
	local loader = (love.filesystem.load("Load.lua"))("/")

	-- Boot the game.
	loader({ boot = "Boot", name = "Scripts" }, "", _G, nil, nil, love.filesystem.load)

	-- Resolve delayed bindings.
	console = _G.console
	game = _G.game
	printf = _G.printf
	---[[
MUSIC = love.audio.newMusic("Music/MUSIC2.ogg")
love.audio.play(MUSIC, 4)
--]]
	-- Launch the main screen.
	section.Screen("Main")
end

-- Game draw
-------------
function draw ()
	game.draw()

	-- Clear scissor state for proper background wipe.
	setScissor()

	-- Draw the console, if active.
	console:Draw()

	-- Do printouts.
	printf:Output()
end

-- Key was pressed
-------------------
function keypressed (key)
	game.keypressed(key) 

	-- Hand input off to the console.
	console:KeyPressed(key)
end

-- Key was released
--------------------
function keyreleased (key)
	game.keyreleased(key)

	-- Hand input off to the console.
	console:KeyReleased(key)
end

-- Mouse button was pressed
----------------------------
function mousepressed (button, x, y)

end

-- Mouse button was released
-----------------------------
function mousereleased (button, x, y)

end

-- Game update
---------------
function update (dt)
	game.update(dt)

	-- Update the console, if active.
	console:Update(dt)

	-- Hand the CPU off to other processes.
	sleep(10)
end