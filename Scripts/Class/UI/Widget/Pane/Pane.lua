-- See TacoShell Copyright Notice in main folder of distribution

-----------
-- Imports
-----------
local SuperCons = class.SuperCons

----------------------
-- Stock signal table
----------------------
local Signals = {
	onFrame = function(P)
		P:Promote()
	end,
	onUnframe = function(P)
		
	end
}

-------------------------
-- Pane class definition
-------------------------
class.Define("Pane", {
	-- bBlock: If true, pane should block
	--------------------------------------
	SetBlocking = function(P, bBlock)
		P.bBlock = not not bBlock
	end
},

-- Constructor
-- group: Group handle
-----------------------
function(P, group)
	SuperCons(P, "Widget", group)

	-- Signals --
	P:SetSignal(Signals)
end, { base = "Widget" })