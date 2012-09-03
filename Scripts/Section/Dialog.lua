----------------------------
-- Standard library imports
----------------------------

-----------
-- Imports
-----------
local GetSize = windows.GetSize
local SetupScreen = section.SetupScreen

-----------
-- Widgets
-----------


-- Install the example dialog.
section.Load("Example", function(state, data, ...)
	-- Load --
	if state == "load" then
		data.pane = ui.Backdrop(false)

		-- Load buttons.

	-- Open --
	elseif state == "open" then
		local lookup = SetupScreen(data)
		local vw, vh = GetSize()



	-- Trap --
	elseif state == "trap" then

	end
end, {
	english = {

	}, martian = {

	}
})