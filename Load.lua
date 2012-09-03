-- See TacoShell Copyright Notice in main folder of distribution

----------------------------
-- Standard library imports
----------------------------
local assert = assert
local ipairs = ipairs
local loadfile = loadfile
local setfenv = setfenv
local type = type

---------------------
-- Forward reference
---------------------
local Load

-- Get and validate directory separator.
local Separator = ...

assert(type(Separator) == "string", "Invalid separator")

-- Reinvokes the loader on a set of results
--------------------------------------------
local function LoadAgainOnItemResult (item, env, arg, ext, loader, prefix)
	if item ~= nil then
		Load(item, env, arg, ext, loader, prefix)
	end
end

-- Loads a file in a given environment
-- file: File name
-- prefix: Current base prefix for files; if present, propagate all parameters
-- Returns: If propogating, chunk results
-------------------------------------------------------------------------------
local function LoadFile (file, env, arg, ext, loader, prefix)
	local chunk = assert(loader(file .. "." .. ext))

	setfenv(chunk, env)

	if prefix then
		return chunk(prefix, env, arg, ext, loader, Load)
	end

	chunk(arg)
end

-- Load helper
---------------
local function AuxLoad (item, prefix, env, arg, ext, loader)
	local itype = type(item)

	assert(itype == "function" or itype == "string" or itype == "table", "Bad load unit type")

	-- If an item is a function, evaluate it.
	if itype == "function" then
		LoadAgainOnItemResult(item(prefix, env, arg, ext, loader, Load))

	-- If an item is a string, load the script it names.
	elseif itype == "string" then
		LoadFile(prefix .. item, env, arg, ext, loader)

	-- If an item is a table, recursively read it. Process any internal boot.
	else
		name, boot = item.name, item.boot

		assert(name == nil or type(name) == "string", "Invalid directory name")
		assert(boot == nil or type(boot) == "string", "Invalid boot string")

		if name and name ~= "" then
			prefix = prefix .. name .. Separator
		end

		if boot then
			LoadAgainOnItemResult(LoadFile(prefix .. boot, env, arg, ext, loader, prefix))
		end

		for _, entry in ipairs(item) do
			AuxLoad(entry, prefix, env, arg, ext, loader)
		end
	end
end

-- item: Item table to read
-- prefix: Current base prefix for files
-- env: Function environment
-- arg: Argument
-- ext: File extension, or "lua" if nil
-- loader: Loader, or loadfile if nil
-----------------------------------------
function Load (item, prefix, env, arg, ext, loader)
	assert(type(prefix) == "string", "Invalid prefix")
	assert(type(env) == "table", "Invalid environment")
	assert(ext == nil or type(ext) == "string", "Invalid extension")
	assert(loader == nil or type(loader) == "function", "Invalid loader")

	AuxLoad(item, prefix, env, arg, ext or "lua", loader or loadfile)
end

-- Export the loader.
return Load