-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local ipairs = ipairs
local remove = table.remove

-- Imports --
local ClearRange = varops.ClearRange
local CollectArgsInto = varops.CollectArgsInto
local IsCallable = varops.IsCallable

-- Export the iterators namespace.
module "iterators"

-- Builds a multiple user iterator which will recache itself after a full loop
-- builder: Function which supplies iterator body and finish / callback setup logic
-- Returns: Iterator
------------------------------------------------------------------------------------
function CachedCallback (builder)
	local cache = {}

	return function(...)
		local callback = remove(cache)

		if not callback then
			local body, done, setup, reclaim = builder(...)

			assert(IsCallable(body), "Uncallable callback body")
			assert(IsCallable(done), "Uncallable done function")
			assert(IsCallable(setup), "Uncallable setup function")
			assert(IsCallable(reclaim), "Uncallable reclaim function")

			-- Build a reclaim function.
			local active

			local function reclaim_func (state)
				assert(active, "Iterator is not active")

				reclaim(state)

				cache[#cache + 1] = callback

				active = false
			end

			-- Iterator body
			-- s, i: State, iteration variable
			-- Returns: Body results
			local function Iter (s, i)
				assert(active, "Iterator is done")

				if done(s, i) then
					reclaim_func(s)
				else
					return body(s, i)
				end
			end

			-- Iterator launcher
			-- ...: Setup arguments
			-- Returns: Iterator function, state, initial value
			function callback (...)
				assert(not active, "Iterator is already in use")

				active = true

				local state, var0 = setup(...)

				return Iter, state, var0, reclaim_func
			end
		end

		return callback(...)
	end
end

-- Iterator to return argument pairs
-- ...: Arguments
-- Returns: Iterator which supplies index, value
-------------------------------------------------
APairs = CachedCallback(function()
	local args = {}
	local count

	-- Body --
	return function(_, i)
		return i + 1, args[i + 1]
	end,

	-- Done --
	function(_, i)
		return i >= count
	end,

	-- Setup --
	function(...)
		count = CollectArgsInto(args, ...)

		return nil, 0
	end,

	-- Reclaim --
	function()
		ClearRange(args, 1, count)
	end
end)

do
	-- Iterator body
	-- Returns: Index, value
	local function Iter (t, index)
		local v = t[index - 1]

		if v ~= nil then
			return index - 1, v
		end
	end

	-- Reverse indexed iterator
	-- final: Optional final element index
	-- Returns: Iterator which supplies index, value
	-------------------------------------------------
	function IPairsR (t, final)
		return Iter, t, (final or #t) + 1
	end
end

-- Iterator to return given item, followed by indexed elements
-- item: Item to supply
-- t: Table to iterate with ipairs
-- Returns: Iterator which supplies index, value; index for item = false
-------------------------------------------------------------------------
ItemThenIPairs = CachedCallback(function()
	local value, aux, state, var

	-- Body --
	return function()
		-- After the first iteration, return the current result from ipairs.
		if var then
			return var, value

		-- Otherwise, prime ipairs and return the first value.
		else
			aux, state, var = ipairs(state)

			return false, value
		end
	end,

	-- Done --
	function()
		-- After the first iteration, do one ipairs iteration per invocation.
		if var then
			var, value = aux(state, var)

			return not var
		end
	end,

	-- Setup --
	function(item, t)
		value = item
		state = t
	end,

	-- Reclaim --
	function()
		value, aux, state, var = nil
	end
end)

-- Iterator to return indexed elements, followed by given item
-- t: Table to iterate with ipairs
-- item: Item to supply
-- Returns: Iterator which supplies index, value; index for item = false
-------------------------------------------------------------------------
IPairsThenItem = CachedCallback(function()
	local ivalue, value, aux, state, var

	-- Body --
	return function()
		return var or false, value
	end,

	-- Done --
	function()
		-- If ipairs is still going, grab another element. If it has completed, clear
		-- the table state and do the item.
		if var then
			var, value = aux(state, var)

			if not var then
				value, aux, state, var = nil
			end

		-- Quit after the item has been returned.
		else
			return true
		end
	end,

	-- Setup --
	function(t, item)
		aux, state, var = ipairs(t)

		ivalue = item
	end,

	-- Reclaim --
	function()
		ivalue, value, aux, state, var = nil
	end
end)

-- Iterator to simulate a one-element iteration
-- item: Item to supply
-- done: On second pass, triggers quit
-- Returns: 1, item
------------------------------------------------
function One (item, done)
	if done == nil then
		return 1, item
	end
end