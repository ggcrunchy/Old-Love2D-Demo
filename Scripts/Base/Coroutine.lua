-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local create = coroutine.create
local error = error
local pcall = pcall
local resume = coroutine.resume
local running = coroutine.running
local status = coroutine.status
local yield = coroutine.yield

-- Imports --
local IsCallable = varops.IsCallable
local NoOp = funcops.NoOp

-- List of running extended coroutines --
local Running = table_ex.Weak("kv")

-- Coroutine wrappers --
local Wrappers = table_ex.Weak("k")

-- Unique reset object --
local u_Reset = Running

-- Export the coroutine_ex namespace.
module "coroutine_ex"

-- Function wrapper
-- func: Coroutine body
local function Func (func)
	while true do
		func(yield())
	end
end

--- Creates an extended coroutine, exposed by a wrapper function. This behaves like
-- <b>coroutine.wrap</b>, though as a loop and not a one-shot call. Once the function is
-- complete, it will "rewind" and thus be back in its original state, excepting any side
-- effects.<br><br>
-- In addition, a coroutine created with this function can be reset, i.e. the body function
-- is explicitly rewound while active. To accommodate this, the reset logic is used to clean
-- up any important state.
-- @param func Coroutine body.
-- @param on_reset Function called on reset; if <b>nil</b>, this is a no-op.
-- @return Wrapper function.
-- @see Reset
function Create (func, on_reset)
	on_reset = on_reset or NoOp

	-- Validate arguments.
	assert(IsCallable(func), "Uncallable producer")
	assert(IsCallable(on_reset), "Uncallable reset response")

	-- Handles a coroutine resume, propagating any error
	-- success: If true, resume was successful
	-- res_or_error: First result of resume, or error message
	-- ...: Remaining resume results
	-- Returns: On success, any results
	local coro, in_reset

	local function Resume (success, res_or_error, ...)
		Running[coro] = nil

		-- On a reset, invalidate the coroutine and trigger any response.
		if res_or_error == u_Reset then
			in_reset = true

			coro = nil

			success, res_or_error = pcall(on_reset, ...)

			in_reset = false
		end

		-- Propagate any error.
		if not success then
			error(res_or_error, 3)

		-- Otherwise, return results if no reset occurred.
		elseif coro then
			return res_or_error, ...
		end
	end

	-- Supply a wrapped coroutine.
	local function wrapper (arg_or_reset, ...)
		assert(not in_reset, "Cannot resume during reset")

		-- On the first run or after / on a reset, build a fresh coroutine and put it into
		-- a ready-and-waiting state.
		if coro == nil or arg_or_reset == u_Reset then
			coro = create(Func)

			resume(coro, func)

			-- On a forced reset, bypass running.
			if arg_or_reset == u_Reset then
				return Resume(true, u_Reset, ...)
			end
		end

		-- Run the coroutine and return its results.
		assert(status(coro) ~= "dead", "Dead coroutine")
		assert(not Running[coro], "Coroutine already running")

		Running[coro] = wrapper

		return Resume(resume(coro, arg_or_reset, ...))
	end

	Wrappers[wrapper] = true

	return wrapper
end

--- Resets a coroutine made by <b>Create</b>.
-- @param coro Optional wrapper for coroutine to reset; if <b>nil</b>, the running coroutine
-- is used, in which case it also yields.
-- @param ... Reset arguments.
-- @see Create
function Reset (coro, ...)
	-- On a reset request, trigger an external reset if the coroutine is not running.
	local running_coro = Running[running() or 0]

	if coro and coro ~= running_coro then
		assert(Wrappers[coro], "Cannot reset argument not made with Create")

		coro(u_Reset, ...)

	-- Otherwise, yield the running coroutine.
	else
		assert(running_coro, "Invalid reset")

		yield(u_Reset, ...)
	end
end