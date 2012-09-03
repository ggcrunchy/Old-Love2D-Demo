-- See TacoShell Copyright Notice in main folder of distribution

-- Standard imports --
local assert = assert
local rawget = rawget
local type = type

-- Imports --
local IsCallable = varops.IsCallable

-- Signal store --
local Signals = table_ex.SubTablesOnDemand("k")

-- Signalable class definition --
class.Define("Signalable", function(Signalable)
	-- Gets the signal listened to on a slot
	-- S: Signalable handle
	-- slot: Slot to query
	-- Returns: Signal, or nil
	local function GetSignal (S, slot)
		local slot_table = rawget(Signals, slot)

		return slot_table and slot_table[S]
	end

	--- Gets the function which handles a given signal.
	-- @class function
	-- @name Signalable:GetSignal
	-- @param slot Signal slot.
	-- @return Signal handler, or <b>nil</b> if absent.
	-- @see Signalable:SetSignal
	Signalable.GetSignal = GetSignal

	-- Adds a listener to a signal
	local function Add (S, slot, signal)
		Signals[slot][S] = signal
	end

	--- Multi-signal variant of <b>Signalable:SetSignal</b>.
	-- @param signals Table of (<i>slot</i>, <i>signal</i>) pairs, where <i>signal</i> is
	-- a handler for that slot.
	-- @see Signalable:SetSignal
	function Signalable:SetMultipleSignals (signals)
		assert(type(signals) == "table", "Invalid signals table")

		for k, v in pairs(signals) do
			assert(IsCallable(v), "Uncallable signal")
		end

		for k, v in pairs(signals) do
			Add(self, k, v)
		end
	end

	--- Accessor.
	-- @param slot The signal slot.
	-- @param signal The signal handler to associate with it, or <b>nil</b> to clear the slot.
	-- @see Signalable:GetSignal
	function Signalable:SetSignal (slot, signal)
		assert(slot ~= nil, "Invalid slot")
		assert(signal == nil or IsCallable(signal), "Uncallable signal")

		Add(self, slot, signal)
	end

	--- Sends a signal to this item, if possible.
	-- @param slot Signal slot.
	-- @param ... Signal arguments.
	-- @return Call results, if a signal handler existed.
	function Signalable:Signal (slot, ...)
		assert(slot ~= nil, "Invalid slot")

		local signal = GetSignal(self, slot)

		if signal then
			return signal(self, ...)
		end
	end
end,

--- Class constructor.
-- @class function
-- @name Constructor
funcops.NoOp)