-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local error = error
local pcall = pcall
local rawset = rawset
local setmetatable = setmetatable

-- Imports --
local IsCallable = varops.IsCallable

-- Cached routines --
local Identity_
local NoOp_

-- Export the callops namespace.
module "funcops"

--- Calls a function with the given arguments.
-- @param func Function to call.
-- @param ... Arguments.
-- @return Call results.
function Call (func, ...)
	return func(...)
end

--- Calls an instance's method with the given arguments.
-- @param I Instance handle.
-- @param name Method name.
-- @param ... Arguments.
-- @return Call results.
function CallMethod (I, name, ...)
	local method = I[name]

	return method(I, ...)
end

--- If the value is callable, it is called and its value returned. Otherwise, returns it.
-- @param value Value to call or get.
-- @param ... Call arguments.
-- @return Call results or value.
function CallOrGet (value, ...)
	if IsCallable(value) then
		return value(...)
	end

	return value
end

--- Returns its arguments.
-- @param ... Arguments.
-- @return Arguments.
function Identity (...)
	return ...
end

--- Returns its arguments, minus the first.
-- @param _ Unused.
-- @param ... Arguments #2 and up.
-- @return Arguments #2 and up.
function Identity_1 (_, ...)
	return ...
end

--- No operation.
function NoOp () end

--- Builds a proxy allowing for get / set overrides, e.g. as <b>__index</b> / <b>__newindex
-- </b> metamethods for a table.<br><br>
-- This return a binder function, with signature<br><br>
-- &nbsp&nbsp&nbsp<i><b>binder(key, getter, setter)</b></i>,<br><br>
-- where <i>key</i> is the key to bind, <i>getter</i> is a function which takes no
-- arguments and returns a value for the key, and <i>setter</i> is a function which takes
-- the value to set as an argument and does something with it. Either <i>getter</i> or
-- <i>setter</i> may be <b>nil</b>: in the case of <i>getter</i>, <b>nil</b> will be
-- returned for the key; the response to <i>setter</i> being <b>nil</b> is explained below.
-- @param on_no_setter Behavior when no setter is available.<br><br>
-- If this is <b>"error"</b>, it is an error.<br><br>
-- If this is <b>"rawset"</b>, the object is assumed to be a table and the value will be
-- set at the key.<br><br>
-- Otherwise, the set is ignored.
-- @return <b>__index</b> function.
-- @return <b>__newindex</b> function.
-- @return Binder function.
function Proxy (on_no_setter)
	local get = {}
	local set = {}

	return function(_, key)
		return (get[key] or NoOp_)()
	end, function(object, key, value)
		local func = set[key]

		if func ~= nil then
			func(value)
		elseif on_no_setter == "error" then
			error("Unhandled set")
		elseif on_no_setter == "rawset" then
			rawset(object, key, value)
		end
	end, function(key, getter, setter)
		assert(getter == nil or IsCallable(getter), "Uncallable getter")
		assert(setter == nil or IsCallable(setter), "Uncallable setter")

		get[key] = getter
		set[key] = setter
	end
end

-- Resource processing and cleanup --
do
	-- Uses a resource
	-- use: Resource usage routine
	-- resource: Resource handle
	-- ...: Usage parameters
	-- Returns: Resource handle, success boolean, message
	local function UseResource (use, resource, ...)
		local success = true
		local message

		-- On acquisition, use the resource. Trap any error to ensure a proper release.
		if resource ~= nil then
			success, message = pcall(use, resource, ...)
		end

		return resource, success, message
	end

	--- Acquires, uses, and releases a resource. If an error occurred during usage, the
	-- resource is still released, and the error propagated.<br><br>
	-- It is assumed that the release logic cannot itself trigger an error.
	-- @param acquire Resource acquire logic.<br><br>
	-- It should return the resource, followed by any additional values to pass on to
	-- <i>use</i>.<br><br>
	-- If the resource is <b>nil</b>, the acquisition has failed and no further steps
	-- are taken.<br><br>
	-- @param use Resource use logic, which takes the results of <i>acquire</i> as
	-- arguments.
	-- @param release Resource release logic, which takes the resource as argument.
	-- @param ... <i>acquire</i> arguments.<br><br>
	-- If <i>acquire</i> is <b>nil</b>, these are instead interpreted as its results
	-- @return If true, the resource was acquired.
	function WithResource (acquire, use, release, ...)
		local resource, success, message = UseResource(use, (acquire or Identity_)(...))

		-- If a resource was acquired, release it.
		if resource ~= nil then
			release(resource)

			-- Propagate any usage error.
			if not success then
				error(message, 2)
			end
		end

		-- Indicate acquisition success.
		return resource ~= nil
	end
end

-- Time lapse handling --
do
	-- Default time lapse
	local function Default ()
		return 0
	end

	-- Time lapse routines --
	local TimeLapse = setmetatable({}, {
		__index = function()
			return Default
		end
	})

	--- Gets the time lapse function for a given category.
	-- @param name Category name, or <b>nil</b> for default.
	-- @return Time lapse function.
	-- @see SetTimeLapseFunc
	function GetTimeLapseFunc (name)
		return TimeLapse[name ~= nil and name or TimeLapse]
	end

	--- Sets the time lapse function for a given category.
	-- @param name Category name, or <b>nil</b> for default.
	-- @param func Function to assign.
	-- @see GetTimeLapseFunc
	function SetTimeLapseFunc (name, func)
		if name == nil then
			assert(IsCallable(func), "SetTimeLapseFunc: Uncallable default time lapse function")

			Default = func

		else
			assert(func == nil or IsCallable(func), "Uncallable time lapse function")

			TimeLapse[name] = func
		end
	end
end

-- Cache some routines.
Identity_ = Identity
NoOp_ = NoOp