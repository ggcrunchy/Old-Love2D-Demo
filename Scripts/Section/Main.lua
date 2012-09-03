----------------------------
-- Standard library imports
----------------------------
local format = string.format
local ipairs = ipairs

-----------
-- Imports
-----------
local Clear = keylogic.Clear
local FocusChain = windows.FocusChain
local GetSize = windows.GetSize
local SetupScreen = section.SetupScreen
local Update = keylogic.Update

-----------
-- Widgets
-----------
local Buttons, DynamicString, Editbox, Marquee, Radio, Slider, StaticString, Textbox

-- Install the main screen.
section.Load("Main", function(state, data, ...)
	-- Load --
	if state == "load" then
		data.pane = ui.Backdrop(false)

		-- Load buttons.
		Buttons = table_ex.Map({
			function()
				printf("MIPPS!")
			end,
			function()
				printf("PIPPS!")
			end,
			function()
				printf("HIPPS!")
			end
		}, ui.PushButton)

		Buttons[1]:SetString("BIBBLE")
		Buttons[2]:SetString("MOIST!")
		Buttons[3]:SetString("TROWEL")

		DynamicString = ui.String(function()
			return format("%i: %s", Radio:GetChoice())
		end)

		Editbox = ui.Editbox()

		Marquee = ui.Marquee("TWEEBLE")
		Marquee:SetPicture("frame", class.New("Picture", graphics.DrawOutlineQuad))

		Radio = ui.Radio(32, 32)

		Radio:AddOption(0, 0, "Trucks")
		Radio:AddOption(68, 0, "Bucks")
		Radio:AddOption(0, 68, "Does")
		Radio:AddOption(68, 68, "Foes")

		Slider = ui.SliderHorz()

		Slider:SetSignal("switch_to", function(S, what)
			if what == "set_offset" then
				local hue = 255 * S:GetOffset()

				Buttons[1]:SetColor("string", love.graphics.newColor(hue, 255 - hue, 255 - hue))
			end
		end)

		StaticString = ui.String("HI YO, SILVER!")

		Textbox = ui.Textbox(.02)

		Textbox:SetColor("shadow", "magenta")
		Textbox:SetShadowOffsets(4, 4)

	-- Open --
	elseif state == "open" then
		local lookup = SetupScreen(data)
		local vw, vh = GetSize()

		for i, button in ipairs(Buttons) do
			data.pane:Attach(button, vw - 300, 50 + i * 75, 150, 64)
		end

		data.pane:Attach(DynamicString, vw - 300, vh - 100)

		data.pane:Attach(Editbox, 50, 350, 250, 32)

		data.pane:Attach(Marquee, vw - 350, vh - 200, 300, 30)

		Marquee:Play(35, true)

		data.pane:Attach(Radio, 50, 400, 100, 100)

		data.pane:Attach(Slider, 50, 50, 200, 32)

		data.pane:Attach(StaticString, vw - 300, vh - 150)

		data.pane:Attach(Textbox, 50, 150, 250, 350)

		Textbox:SetString(
			"One day I will find the magic lure in the bucket of my hopes and dreams! " ..
			"And on that day, I will build myself a boat out of raincoats. And I will " ..
			"fly all the way to the land of the meowing goat!!!"
		)

		FocusChain(data):Load{ Editbox }

	-- Trap --
	elseif state == "trap" then

	-- Update --
	elseif state == "update" then
		Update(FocusChain(data), ...)

	-- Close --
	elseif state == "close" then
		Clear()
	end
end, {
	english = {

	}, martian = {

	}
})