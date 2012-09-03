-- Console.lua
-- For your console needs

local assert = assert
local ceil = math.ceil
local format = string.format
local max = math.max
local tonumber = tonumber
local type = type

-----------
-- Imports
-----------
local draw = love.graphics.draw
local drawRect = love.graphics.rectangle
local IsInteger = varops.IsInteger
local setFont = love.graphics.setFont

----------------------
-- Constants
----------------------
local PROMPT_POS_CHAR = "|"
local PROMPT_POS_DELAY = 0.5

local PROMPT_FIRST_DELAY = 0.5
local PROMPT_DELAY = 0.05

local CONSOLE_LINE_LENGTH = 85
local CONSOLE_LINE_COUNT = 15

local SYMBOL_KEY = { ["1"]="!", ["2"]="@", ["3"]="#", ["4"]="$", ["5"]="%", ["6"]="^", ["7"]="&", ["8"]="*", ["9"]="(", ["0"]=")", ["-"]="_", ["="]="+", ["["]="{", ["]"]="}", ["/"]="?", ["\\"]="|", [";"]=":", ["\'"]="\"", [","]="<", ["."]=">" }

----------------------
-- Stuff
----------------------
local bVisible = false

local Font = love.graphics.newFont(love.default_font)

local MaxLine = 500 -- Maximum lines to store in the String
local Strings = {} -- Buffer of strings to print

local PromptMemory = {} -- list of buffered prompts from last command
local PromptMemoryMax = 100
local PromptMemoryCur = 0
local bPromptMemoryPressed = false

local PromptChar = ">"
local PromptCache = "" -- Buffer string when typing blocks of code (when you shift+enter)
local Prompt = "" -- Current prompt string
local PromptCurKey = 0
local PromptCurDelay = 0 

local PromptPosBlinkCurDelay = 0
local bPromptPosDisplay = true
local PromptPos = 0 -- current prompt edit position

local EndLine = 0

local MaxHeight = 200 -- In pixels.
local Y = -MaxHeight -- In pixels. 

local ToggleKey = 96 -- Default toggle key...for some reason tilde is not available as constant, lame!

----------------------
-- Private functions
---------------------- 

-- Return a list of strings split based on given criteria
local function StringSplit(str, criteria)
	local ret = {}
	local index = 1
	
	while index <= #str  do
		local s, e = string.find(str, criteria, index)
		
		-- No more pattern, set s and e as the entire sub
		if s == nil then
			e = #str
			
			ret[#ret + 1] = string.sub(str, index, #str)
		-- Get the substring before the start of pattern
		else
			ret[#ret + 1] = string.sub(str, index, index + s - 1)
		end
		
		-- Get to the next thing
		index = e + 1
	end
		
	return ret
end

-- Return a list of strings, divided by given string length
local function StringSplitLength(str, length)
	local ret = {}
	local s = 1
	
	while s <= #str do
		ret[#ret + 1] = string.sub(str, s, s + length)
		
		s = s + length + 1
	end
	
	return ret
end

-- Prints formatted output strings to console
-- str: Format string
-- ...: Format parameters
-----------------------------------
console = setmetatable({}, {
	__call = function(_, str, ...)
		buffer = format(tostring(str), ...)
	
		-- Split strings based on newline
		lines = StringSplit(buffer, "\n")
		
		local bCalcEndLine = EndLine == #Strings
		
		-- Now for each line, make sure it can fit based on CONSOLE_LINE_LENGTH,
		-- if not, then split it up by that amount
		for i = 1, #lines do
			sublines = StringSplitLength(lines[i], CONSOLE_LINE_LENGTH)
						
			for j = 1, #sublines do
				-- pop one out if we are exceeding our max cache size
				if #Strings == MaxLine then
					table.remove(Strings, 1)
				end
				
				Strings[#Strings + 1] = sublines[j]
			end
		end
		
		if bCalcEndLine then
			EndLine = #Strings
		end
	end,
	__metatable = true
})

local function ProcessKey(key)
	-- reset prompt pos blink
	bPromptPosDisplay = true
	PromptPosBlinkCurDelay = 0
	
	local shiftDown = love.keyboard.isDown(love.key_lshift) or love.keyboard.isDown(love.key_rshift)
	
	-- enter key
	if key == love.key_return then
		-- display our prompt
		console(Prompt)
		
		-- if shift is down, then put prompt to cache
		if shiftDown then
			PromptCache = Prompt.."\n"
			PromptChar = ">>"
		else
			--execute prompt
			local str = PromptCache..Prompt
			if #str then
				local success, err = pcall(function () loadstring(PromptCache..Prompt)() end)
				if not success then
					console(err)
				end
			end
			
			PromptCache = ""
			PromptChar = ">"
		end
		
		-- store our prompt in memory
		if #Prompt > 0 then
			if #PromptMemory == PromptMemoryMax then
				table.remove(PromptMemory, 1)
			end
			
			PromptMemory[#PromptMemory + 1] = Prompt
			PromptMemoryCur = #PromptMemory
			bPromptMemoryPressed = false
			
			-- empty out prompt and reset pos
			Prompt = ""
			PromptPos = 0
		end
		
	-- backspace
	elseif key == love.key_backspace and PromptPos > 0 then
		PromptPos = PromptPos - 1
		if PromptPos < #Prompt-1 then
			Prompt = string.sub(Prompt, 1, PromptPos)..string.sub(Prompt, PromptPos+2, #Prompt)
		else
			Prompt = string.sub(Prompt, 1, PromptPos)
		end
		
	-- delete
	elseif key == love.key_delete then
		if PromptPos == 0 then
			Prompt = string.sub(Prompt, 2, #Prompt) 
		elseif PromptPos == #Prompt-1 then
			Prompt = string.sub(Prompt, 1, PromptPos)
		else
			Prompt = string.sub(Prompt, 1, PromptPos)..string.sub(Prompt, PromptPos+2, #Prompt)
		end
		
	-- page up/down	
	elseif key == love.key_pageup and EndLine > 1 then
		EndLine = EndLine - 1
		
	elseif key == love.key_pagedown and EndLine < #Strings then 
		EndLine = EndLine + 1
		
	-- left/right arrow
	elseif key == love.key_left and PromptPos > 0 then 
		PromptPos = PromptPos - 1		
		
	elseif key == love.key_right and PromptPos < #Prompt then 
		PromptPos = PromptPos + 1
		
	-- up/down arrow
	elseif key == love.key_up then
		
			Prompt = #PromptMemory == 0 and "" or bPromptMemoryPressed and PromptMemory[PromptMemoryCur-1] or PromptMemory[PromptMemoryCur]
			
			if PromptMemoryCur > 1 then
				PromptMemoryCur = PromptMemoryCur - 1
			end

		
		PromptPos = #Prompt
		bPromptMemoryPressed = true
		
	
	elseif key == love.key_down and PromptMemoryCur < #PromptMemory then
		PromptMemoryCur = PromptMemoryCur + 1
				
		Prompt = PromptMemory[PromptMemoryCur]
		PromptPos = #Prompt
		
	-- home/end
	elseif key == love.key_home then
		PromptPos = 0
		
	elseif key == love.key_end then
		PromptPos = #Prompt
		
	-- normal input
	elseif key >= love.key_space and key < love.key_z then
		char = string.char(key)
		
		if shiftDown then
			char = SYMBOL_KEY[char] ~= nil and SYMBOL_KEY[char] or string.upper(char) 
		end
		
		if PromptPos < #Prompt then
			Prompt = string.sub(Prompt, 1, PromptPos)..char..string.sub(Prompt, PromptPos+1, #Prompt)
		else
			Prompt = Prompt..char
		end
		
		PromptPos = PromptPos + 1
	end
end

function console:KeyPressed(key)
	if key == ToggleKey then
		console:SetVisible(not bVisible)
		PromptCurDelay = 0
		return
	end
	
	if not bVisible or (PromptCurDelay ~= 0 and PromptCurKey == key) then
		return
	end
	
	PromptCurKey = key
	
	-- begin key input repeat
	PromptCurDelay = PROMPT_FIRST_DELAY
	
	ProcessKey(key)
end

function console:KeyReleased(key)
	if not bVisible then
		return
	end
	
	if PromptCurKey == key then
		PromptCurDelay = 0
		PromptCurKey = 0
	end
end

function console:Update(dt)
	if bVisible and Y < 0 then
		Y = Y + dt*2000
		
		if Y >= 0 then
			Y = 0
		end
		
	elseif not bVisible and Y > -MaxHeight then
		Y = Y - dt*2000
		
		if Y < -MaxHeight then
			Y = -MaxHeight
		end
	end
	
	-- update prompt blink
	PromptPosBlinkCurDelay = PromptPosBlinkCurDelay + dt
	if PromptPosBlinkCurDelay >= PROMPT_POS_DELAY then
		bPromptPosDisplay = not bPromptPosDisplay
		PromptPosBlinkCurDelay = 0
	end
	
	-- update repeat
	if PromptCurDelay > 0 and PromptCurKey > 0 then
		PromptCurDelay = PromptCurDelay - dt
		if PromptCurDelay < 0 then
			ProcessKey(PromptCurKey)
			PromptCurDelay = PROMPT_DELAY
		end
	end
end

function console:Draw() 
	if Y > -MaxHeight then
		love.graphics.setBlendMode( love.blend_normal )
		love.graphics.setColorMode( love.color_normal  ) 
		love.graphics.setColor(170, 128, 170, 150)
		drawRect( love.draw_fill, 0, Y, love.graphics.getWidth(), MaxHeight)
		
		setFont(Font)
		
		local advance, x = ceil(Font:getHeight() * Font:getLineHeight()), 5
		local y = Y + MaxHeight - advance*0.25
		
		love.graphics.setColor(255, 255, 255, 255)
		
		-- display prompt
		local promptStr = PromptChar..Prompt
		
		draw(promptStr, x, y)
		
		-- display prompt cursor
		if bPromptPosDisplay then
			if PromptPos < #Prompt then
				draw(PROMPT_POS_CHAR, x+Font:getWidth( string.sub(promptStr, 1, #PromptChar+PromptPos) ), y)
			else
				draw(PROMPT_POS_CHAR, x+Font:getWidth( promptStr ), y)
			end
		end
		
		if EndLine < #Strings then
			love.graphics.setColor(220, 220, 220, 255)
			
			draw("^", love.graphics.getWidth() - Font:getWidth( "^" ), y)
			draw("^", love.graphics.getWidth() - Font:getWidth( "^" ), y - advance*0.5)
			
			love.graphics.setColor(255, 255, 255, 255)
		end
		
		-- go from bottom to top
		for i = EndLine, 1, -1 do
			y = y - advance
			
			-- get out once we go out of screen
			if y < 0 then
				break
			end
			
			draw(Strings[i], x, y)
		end
	end
end

function console:SetToggleKey(key)
	ToggleKey = key
end

function console:SetVisible(visible)
	bVisible = visible
end

function console:SetMaxLine(num)
	MaxLine = num
end

--- Reset everything!
function console:Clear()
	Strings = {}

	PromptMemory = {}
	PromptMemoryCur = 0
	bPromptMemoryPressed = false
	
	PromptCache = ""
	Prompt = ""
	PromptCurKey = 0
	PromptCurDelay = 0 
	
	PromptPosBlinkCurDelay = 0
	bPromptPosDisplay = true
	PromptPos = 0
	
	StartLine = 1
end
