-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local error = error
local yield = coroutine.yield

-- Imports --
local GetTimeLapseFunc = funcops.GetTimeLapseFunc
local IsCallable = varops.IsCallable
local NoOp = funcops.NoOp

-- Export the coroutineops namespace.
module "coroutineops"

-- Common actor logic body
-- update: Optional update logic
-- body: Body logic
-- done: Loop completion logic
-- finish: Finish logic
-- yvalue: Optional value to yield
-- Returns: If true, success
local function Body (update, body, done, finish, yvalue)
	update = update or NoOp
	body = body or NoOp

	local is_done = false

	while true do
		is_done = not not done()

		-- Update any user-defined logic. Break on a true result.
		if is_done or update() then
			break
		end

		-- Update body logic.
		body()

		-- Yield, using any provided value.
		yield(yvalue)
	end

	-- Do any cleanup.
	(finish or NoOp)()

	-- Report success.
	return is_done
end

-- Waits for a duration to pass
-- duration: Time to wait
-- update: Optional update logic
-- data: Update logic data
-- yvalue: Optional value to yield
-- Returns: If true, duration completed
----------------------------------------
function Wait (duration, update, data, yvalue)
	local lapse = GetTimeLapseFunc("coroutineops")
	local time = 0

	-- Wait for the duration to pass.
	return Body(update and function()
		return update(time, duration, data)
	end, function()
		time = time + lapse()
	end, function()
		return time > duration
	end, nil, yvalue)
end

-- Waits for signals to reach a certain state
-- signals: Optional signal object or callback
-- count: Signal count
-- how: Signal test operation
-- update: Optional update logic
-- data: Update logic data
-- yvalue: Optional value to yield
-- Returns: If true, signals reached the state
-----------------------------------------------
function WaitForMultipleSignals (signals, count, how, update, data, yvalue)
	local func, test

	-- If the signals are not callable, build an indexing function. Build a table if
	-- nothing is provided.
	func = IsCallable(signals) and signals or function(index)
		return signals[index]
	end
	signals = signals or {}

	-- Build the test operation.
	if how == "any" then
		function test ()
			for i = 1, count do
				if func(i) then
					return true
				end
			end
		end

	elseif how == "every" then
		 function test ()
			for i = 1, count do
				if not func(i) then
					return
				end
			end

			return true
		end

	else
		error("Unsupported operation")
	end

	-- Wait for the operation to succeed.
	return Body(update and function()
		return update(signals, count, data)
	end, nil, test, nil, yvalue)
end

-- Waits for a single signal to fire
-- signals: Optional signal object or callback
-- what: Signal to watch
-- update: Optional update logic
-- data: Update logic data
-- yvalue: Optional value to yield
-- Returns: If true, signal fired
-----------------------------------------------
function WaitForSignal (signals, what, update, data, yvalue)
	signals = signals or {}

	-- Wait for the signal to fire.
	return Body(update and function()
		return update(signals, what, data)
	end, nil, IsCallable(signals) and signals or function()
		return signals[what]
	end, nil, yvalue)
end

-- Waits for a condition to be fulfilled
-- test: Condition test
-- update: Optional update logic
-- data: Update logic data
-- yvalue: Optional value to yield
-- Returns: If true, condition was fulfilled
---------------------------------------------
function WaitUntil (test, update, data, yvalue)
	return Body(update and function()
		return update(data)
	end, nil, test and function()
		return test(data)
	end or NoOp, nil, yvalue)
end

-- Waits for a test method to be fulfilled
-- object: Object with method
-- method: Test method
-- update: Optional update logic
-- data: Update logic data
-- yvalue: Optional value to yield
-- Returns: If true, test method was fulfilled
-----------------------------------------------
function WaitUntil_Method (object, method, update, data, yvalue)
	method = object[method]

	return Body(update and function()
		return update(data)
	end, nil, function()
		return method(object, data)
	end, nil, yvalue)
end

-- Waits for a condition to stop
-- test: Condition test
-- update: Optional update logic
-- data: Update logic data
-- yvalue: Optional value to yield
-- Returns: If true, condition stopped
---------------------------------------
function WaitWhile (test, update, data, yvalue)
	return Body(update and function()
		return update(data)
	end, nil, test and function()
		return not test(data)
	end or NoOp, nil, yvalue)
end

-- Waits for a test method to stop
-- object: Object with method
-- method: Test method
-- update: Optional update logic
-- data: Update logic data
-- yvalue: Optional value to yield
-- Returns: If true, test method stopped
-----------------------------------------
function WaitWhile_Method (object, method, update, data, yvalue)
	method = object[method]

	return Body(update and function()
		return update(data)
	end, nil, function()
		return not method(object, data)
	end, nil, yvalue)
end