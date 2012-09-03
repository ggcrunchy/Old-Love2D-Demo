-- See TacoShell Copyright Notice in main folder of distribution

return {
	----------------------
	-- Base functionality
	----------------------
	{ name = "Base", boot = "Boot" },

	-----------------------
	-- Various debug tools
	-----------------------
	{ name = "DebugHelpers", boot = "Boot" },

	-- Set a convenient default for the variable dumper.
	function()
		vardump.SetDefaultOutf(printf)
	end,

	---------------------
	-- Primitive classes
	---------------------
	{ name = "Class", boot = "PrimitivesBoot" },

	-----------------
	-- API utilities
	-----------------
	{ name = "Utility", boot = "Boot" },

	---------------
	-- API Classes
	---------------
	{ name = "Class", boot = "APIBoot" },

	-----------------
	-- Configuration
	-----------------
	{ name = "Config", boot = "Boot" },

	--------------
	-- Subsystems
	--------------
	{ name = "Subsystems", boot = "Boot" },

	-------------------------
	-- Game support features
	-------------------------
	{ name = "Support", boot = "Boot" },

	----------------
	-- Game classes
	----------------
	{ name = "Class", boot = "GameBoot" },

	--------------
	-- Game logic
	--------------
	{ name = "Game", boot = "Boot" },

	------------
	-- Sections
	------------
	{ name = "Section", boot = "Boot" }
}, ...