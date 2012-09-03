-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local insert = table.insert
local ipairs = ipairs
local remove = table.remove

-- Imports --
local ClearRange = varops.ClearRange
local CollectArgsInto = varops.CollectArgsInto
local IPairsR = iterators.IPairsR
local IsCallable = varops.IsCallable
local UnpackClearAndRecache = varops.UnpackClearAndRecache

-- Unique member keys --
local _afters = {}
local _befores = {}
local _core = {}

-- Cache of core results tables --
local Results = {}

-- AugmentedFunction class definition --
class.Define("AugmentedFunction", function(AugmentedFunction)
	--- Appends an "after" function.
	-- @param after Function to add.
	-- @see AugmentedFunction:PopAfter
	function AugmentedFunction:AddAfter (after)
		assert(IsCallable(after), "Uncallable after")

		insert(self[_afters], after)
	end

	--- Prepends a "before" function.
	-- @param before function to add.
	-- @see AugmentedFunction:PopBefore
	function AugmentedFunction:AddBefore (before)
		assert(IsCallable(before), "Uncallable before")

		insert(self[_befores], before)
	end

	--- Metamethod.<br><br>
	-- If no core is present, this is a no-op.<br><br>
	-- If any "before" functions have been added, these are called, in most- to least-
	-- recent order, with the call arguments. If any of these returns a true result, the
	-- call is aborted.<br><br>
	-- The core is then called with the call arguments.<br><br>
	-- If any "after" functions have been added, these are called, in least- to most-
	-- recent order, with the call arguments.<br><br>
	-- Finally, the results of the core call are returned.
	-- @param ... Arguments to call.
	-- @return Call results.
	-- @see AugmentedFunction:AddAfter
	-- @see AugmentedFunction:AddBefore
	-- @see AugmentedFunction:SetCore
	function AugmentedFunction:__call (...)
		local core = self[_core]

		if core then
			-- Invoke each before routine, aborting on non-nil/false returns.
			for _, before in IPairsR(self[_befores]) do
				if before(...) then
					return
				end
			end

			-- Invoke the core. If after routines are to be called, cache its results
			-- beforehand. In either case, supply the results.
			if #self[_afters] == 0 then
				return core(...)

			else
				local count, results = CollectArgsInto(remove(Results) or {}, core(...))

				-- Invoke each after routine.
				for _, after in ipairs(self[_afters]) do
					after(...)
				end

				-- Return the results from the core function.
				return UnpackClearAndRecache(Results, results, count)
			end
		end
	end

	--- Accessor.
	-- @return Core function, or <b>nil</b> if absent.
	-- @see AugmentedFunction:SetCore
	function AugmentedFunction:GetCore ()
		return self[_core]
	end

	--- Removes the most-recently added "after" function.
	-- @return Removed function, or <b>nil</b> if none was present.
	-- @see AugmentedFunction:AddAfter
	function AugmentedFunction:PopAfter ()
		return remove(self[_afters])
	end

	--- Removes the most-recently added "before" function.
	-- @return Removed function, or <b>nil</b> if none was present.
	-- @see AugmentedFunction:AddBefore
	function AugmentedFunction:PopBefore ()
		return remove(self[_befores])
	end

	--- Accessor.
	-- @param func Core function to assign, or <b>nil</b> to clear the core.
	-- @param should_clear If true, the "after" and "before" function lists are cleared.
	-- @see AugmentedFunction:AddAfter
	-- @see AugmentedFunction:AddBefore
	-- @see AugmentedFunction:GetCore
	function AugmentedFunction:SetCore (func, should_clear)
		assert(func == nil or IsCallable(func), "Uncallable core")

		-- Install the core.
		self[_core] = func

		-- If requested, reset the function lists at the same time.
		if should_clear then
			self[_afters] = {}
			self[_befores] = {}
		end
	end
end,

--- Class constructor.
-- @class function
-- @name Constructor
-- @param func Optional core function.
-- @see AugmentedFunction:SetCore
function(A, func)
	A:SetCore(func, true)
end)