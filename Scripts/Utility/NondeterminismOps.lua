-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local ipairs = ipairs
local type = type
local yield = coroutine.yield

-- Imports --
local Create = coroutine_ex.Create
local IsCallable = varops.IsCallable

-- Export the nondeterminism_ops namespace.
module "nondeterminism_ops"

do
	-- Choose body
	-- func: Callback on choices
	-- choice: Current choice
	local function Iter (func, choice)
		func(choice)

		yield(true)
	end

	--- Implements a single-choice nondeterminstic choose.<br><br>
	-- The guesses are iterated, in order, each being passed as argument to the callback.
	-- The callback is run inside the body of an extended coroutine; the callback can be
	-- aborted with <b>coroutine_ex.Reset</b>.<br><br>
	-- If the callback finishes, the guess is returned as the choice.<br><br>
	-- If no choice is made, the fail logic is called, without arguments.
	-- @param guesses Array of guesses.
	-- @param func Callback on guesses.
	-- @param fail Fail logic.
	-- @return Choice, if available. Otherwise, nothing.
	function Choose (guesses, func, fail)
		assert(type(guesses) == "table", "Invalid guess set")
		assert(IsCallable(func), "Uncallable function")
		assert(IsCallable(fail), "Uncallable fail")

		local iter = Create(Iter)

		-- Try each guess. Supply the choice if the iterator does not reset.
		for _, choice in ipairs(guesses) do
			if iter(func, choice) then
				return choice
			end
		end

		-- If no choice is available, fail.
		fail()
	end
end

do
	-- ChooseMulti body
	-- func: Callback on choices
	-- choice: Current choice
	-- results: Store for good choices
	local function Iter (func, choice, results)
		func(choice)

		results[#results + 1] = choice
	end

	--- Multi-choice variant of <b>Choose</b>.<br><br>
	-- Instead of returning, as in <b>Choose</b>, choices are added to an array that
	-- is returned at the end.
	-- @param guesses Array of guesses.
	-- @param func Callback on choices.
	-- @param fail Fail logic.
	-- @return Array of choices, if any were available. Otherwise, nothing.
	-- @see Choose
	function ChooseMulti (guesses, func, fail)
		assert(type(guesses) == "table", "Invalid guess set")
		assert(IsCallable(func), "Uncallable function")
		assert(IsCallable(fail), "Uncallable fail")

		local iter = Create(Iter)

		-- Try each guess. Accumulate any result when the iterator does not reset.
		local results = {}

		for _, choice in ipairs(guesses) do
			iter(func, choice, results)
		end

		-- If no choices are available, fail. 
		if #results > 0 then
			return results
		else
			fail()
		end
	end
end