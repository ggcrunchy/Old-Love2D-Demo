-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local getmetatable = getmetatable
local ipairs = ipairs
local newproxy = newproxy
local pairs = pairs
local setmetatable = setmetatable
local type = type

-- Imports --
local Copy = table_ex.Copy
local IsCallable = varops.IsCallable
local Weak = table_ex.Weak
local WithBoundTable = table_ex.WithBoundTable
local WithResource = funcops.WithResource

-- Cached routines --
local IsInstance_
local IsType_

-- Instance / type mappings --
local Instances = Weak("k")

-- Class definitions --
local Defs = {}

-- Unique hidden type value --
local u_Hidden = {}

-- Built-in type set --
local BuiltIn = table_ex.MakeSet{ "boolean", "function", "nil", "number", "string", "table", "thread", "userdata" }

-- Metamethod set --
local Metamethods = table_ex.MakeSet{
	"__index", "__newindex",
	"__eq", "__le", "__lt",
	"__add", "__div", "__mul", "__sub",
	"__mod", "__pow", "__unm",
	"__call", "__concat", "__gc", "__len"
}

-- Export class namespace.
module "class"

-- Gets a type name, with hiding support
-- itype: Instance type
-- Returns: Type name, or hidden value
local function GetType (itype)
	return Defs[itype].bHidden and u_Hidden or itype
end

-- Class hierarchy linearizations --
local Linearizations = setmetatable({}, {
    __index = function(t, ctype)
        local types = {}

        local function walker (index, check)
            if index == t then
                return #types

            elseif index ~= nil then
                local type = types[index]

                if type then
                    return check and type or GetType(type)
                end
            end
        end

        t[ctype] = walker

        repeat
            types[#types + 1] = ctype

			ctype = Defs[ctype].base
        until ctype == nil

        return walker
    end
})

do
	-- Per-class data for default allocations --
	local ClassData = setmetatable({}, {
		__index = function(t, meta)
			local datum = newproxy(true)

			WithBoundTable(getmetatable(datum), Copy, meta)

			t[meta] = datum

			return datum
		end
	})

	-- Per-instance data for default allocations --
	local InstanceData = Weak("k")

	-- Default instance allocator
	local function DefaultAlloc (meta)
		local I = newproxy(ClassData[meta])

		InstanceData[I] = {}

		return I
	end

	-- Default indirect __index metamethod
	local function DefaultIndex (I, key)
		return InstanceData[I][key]
	end

	-- Default indirect __newindex metamethod
	local function DefaultNewIndex (I, key, value)
		InstanceData[I][key] = value
	end

	-- Common __index body
	-- I: Instance handle
	-- key: Lookup key
	local function Index (I, key)
		local defs = Defs[Instances[I]]
		local index = defs.__index

		-- Pass the search along for the value.
		local value

		if IsCallable(index) then
			value = index(I, key)
		else
			value = index[key]
		end

		-- If the value was not found, try the members. Return the final result.
		if value ~= nil then
			return value
		else
			return defs.members[key]
		end
	end

	-- Common __newindex body
	-- I: Instance handle
	-- key: Lookup key
	-- value: Value to assign
	local function NewIndex (I, key, value)
		local newindex = Defs[Instances[I]].__newindex

		-- Pass along the assignment.
		if IsCallable(newindex) then
			newindex(I, key, value)
		else
			newindex[key] = value
		end
	end

	--- Defines a new class.
	-- @param ctype Class type name.
	-- @param members Members to add.<br><br>
	-- This may be a table, in which case each (name, member) pair is read out directly<br><br>
	-- Alternatively, this can be a function which takes a table as its argument; in that case,
	-- a fresh table is provided to the function, and after it has been called, its (name,
	-- member) entries are loaded.<br><br>
	-- Entries with names corresponding to metamethods will be installed as such.
	-- @param cons Constructor function, called each time class is instantiated.
	-- @param params Configuration parameters.<br><br>
	-- @see GetMember
	-- @see New
	-- @see NewArray
	function Define (ctype, members, cons, params)
		assert(ctype ~= nil, "Define: ctype == nil")
		assert(ctype == ctype, "Define: ctype is NaN")
		assert(ctype ~= u_Hidden, "Define: ctype == class.Hidden")
		assert(not BuiltIn[ctype], "Define: ctype refers to built-in type")
		assert(not Defs[ctype], "Class already defined")
		assert(type(members) == "table" or type(members) == "function", "Non-table/function members")
		assert(IsCallable(cons), "Uncallable constructor")

		-- Prepare the definition.
		local def = {
			alloc = DefaultAlloc,
			cons = cons,
			members = {},
			meta = {},
			__index = DefaultIndex,
			__newindex = DefaultNewIndex
		}

		-- Configure the definition according to the input parameters.
		if params then
			assert(type(params) == "table", "Non-table parameters")

			local alloc = params.alloc

			-- Flag hidden nature, if requested.
			def.bHidden = not not params.bHidden

			-- Inherit from base class, if provided.
			if params.base ~= nil then
				local base_info = assert(Defs[params.base], "Base class does not exist")

				-- Inherit base class metamethods.
				WithBoundTable(def.meta, Copy, base_info.meta)

				def.__index = base_info.__index
				def.__newindex = base_info.__newindex

				-- Inherit base class members.
				def.members.__index = base_info.members

				setmetatable(def.members, def.members)

				-- Inherit the allocator if one was not specified.
				if alloc == nil then
					alloc = base_info.alloc
				end

				-- Store the base class name.
				def.base = params.base
			end

			-- Assign any custom allocator.
			if alloc ~= nil then
				assert(IsCallable(alloc), "Uncallable allocator")

				def.alloc = alloc
			end
		end

		-- If the caller loads the members in a function, regularize this to the table case,
		-- using the table that gets filled.
		if type(members) == "function" then
			local results = {}

			members(results)

			members = results
		end

		-- Install members and metamethods.
		for k, member in pairs(members) do
			local mtable = def.members

			-- If a metamethod is specified, target that table instead. For __index and
			-- __newindex, target their indirect methods.
			if Metamethods[k] then
				if k == "__index" or k == "__newindex" then
					local mtype = type(member)

					assert(IsCallable(member) or mtype == "table" or mtype == "userdata", "Invalid __index / __newindex")

					mtable = def

				else
					assert(IsCallable(member), "Uncallable metamethod")

					mtable = def.meta
				end
			end

			-- Install the member.
			mtable[k] = member
		end

		-- Install master lookup metamethods and lock the metatable.
		def.meta.__index = Index
		def.meta.__newindex = NewIndex
		def.meta.__metatable = true

		-- Register the class.
		Defs[ctype] = def
	end
end

-- ctype: Type name
-- Returns: If true, type exists
---------------------------------
function Exists (ctype)
	assert(ctype ~= nil, "Exists: ctype == nil")

	return Defs[ctype] ~= nil
end

-- ctype: Type name
-- member: Member name
-- Returns: Member
-----------------------
function GetMember (ctype, member)
	assert(ctype ~= nil, "GetMember: ctype == nil")
	assert(member ~= nil, "GetMember: member == nil")

	return assert(Defs[ctype], "Type not found").members[member]
end

-- Returns: If true, item is a class instance
----------------------------------------------
function IsInstance (item)
	return (item and Instances[item]) ~= nil
end

-- what: Type to test
-- Returns: If true, item is of given type
-------------------------------------------
function IsType (item, what)
    assert(what ~= nil, "IsType: what == nil")

    -- Begin with the instance type. Progress upward until a match or the top.
    if IsInstance_(item) and not BuiltIn[what] then
        local walker = Linearizations[Instances[item]]

        for i = 1, walker(Linearizations) do
            if walker(i, Linearizations) == what then
                return true
            end
        end

        return false	

    -- For non-instances, check the built-in type.
    else
        return type(item) == what
    end
end

-- Gets a type's linearization
-- ctype: Type name
-- Returns: Linearization size, function
-----------------------------------------
function Linearization (ctype)
    assert(ctype ~= nil, "Linearization: ctype == nil")
    assert(Defs[ctype], "Type not found")

    local walker = Linearizations[ctype]

    return walker(Linearizations), walker
end

do
	-- Stack of instances in construction --
	local ConsStack = {}

	-- Invokes a superclass constructor
	-- I: Instance handle
	-- stype: Superclass type name
	-- ...: Constructor arguments
	------------------------------------
	function SuperCons (I, stype, ...)
		assert(I ~= nil, "SuperCons: I == nil")
		assert(stype ~= nil, "SuperCons: stype == nil")
		assert(ConsStack[#ConsStack] == I, "Invoked outside of constructor")
		assert(Instances[I] ~= stype, "Instance already of superclass type")
		assert(IsType_(I, stype), "Superclass not found")

		-- Invoke the constructor.
		Defs[stype].cons(I, ...)
	end

	-- Resource usage
	-- cons: Constructor
	-- I: Instance handle
	-- ctype: Type name
	-- ...: Constructor arguments
	local function Use (cons, I, ctype, ...)
		local itype = type(I)

		assert(itype == "table" or itype == "userdata", "Bad instance allocation")
		assert(Instances[I] == nil, "Instance already exists")

		ConsStack[#ConsStack + 1] = I

		Instances[I] = ctype

		-- Invoke the constructor.
		cons(I, ...)
	end

	-- Resource release
	local function Release ()
		ConsStack[#ConsStack] = nil
	end

	-- Instantiates a class
	-- ctype: Type name
	-- ...: Constructor arguments
	-- Returns: Instance handle
	------------------------------
	function New (ctype, ...)
		assert(ctype ~= nil, "New: ctype == nil")

		local type_info = assert(Defs[ctype], "Type not found")
		local I = type_info.alloc(type_info.meta)

		WithResource(nil, Use, Release, type_info.cons, I, ctype, ...)

		return I
	end

	-- Instantiates an array from a class
	-- ctype: Type name
	-- count: Instantiation count
	-- ...: Constructor arguments
	-- Returns: Array of instance handles
	--------------------------------------
	function NewArray (ctype, count, ...)
		assert(ctype ~= nil, "NewArray: ctype == nil")
		assert(type(count) == "number" and count >= 0, "Invalid count")

		-- Cache common properties.
		local type_info = assert(Defs[ctype], "Type not found")
		local alloc = type_info.alloc
		local cons = type_info.cons
		local meta = type_info.meta

		-- Construct the instances.
		local array = {}

		for i = 1, count do
			array[i] = alloc(meta)

			WithResource(nil, Use, Release, cons, array[i], ctype, ...)
		end

		return array
	end
end

-- ctype: Type name
-- Returns: Superclass names
-----------------------------
function Supers (ctype)
	assert(ctype ~= nil, "Supers: ctype == nil")

	local base = assert(Defs[ctype], "Type not found").base

	if base ~= nil then
		return GetType(base)
	end
end

-- item: Item, which might be a class instance
-- Returns: Item's class or primitive type, and instance boolean
-----------------------------------------------------------------
function Type (item)
	if IsInstance_(item) then
		return GetType(Instances[item]), true
	else
		return type(item), false
	end
end

-- Export the hidden value type.
Hidden = u_Hidden

-- Cache some routines.
IsInstance_ = IsInstance
IsType_ = IsType