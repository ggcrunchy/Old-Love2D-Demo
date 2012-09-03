-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local format = string.format
local insert = table.insert
local ipairs = ipairs
local pairs = pairs
local rawget = rawget
local sort = table.sort
local tostring = tostring
local type = type

-- Imports --
local HasMeta = varops.HasMeta
local IsCallable = varops.IsCallable
local IsInteger = varops.IsInteger
local SubTablesOnDemand = table_ex.SubTablesOnDemand

-- Export the vardump namespace.
module "vardump"

-- Default output function --
local DefaultOutf

-- Ordered list of type names --
local Names = { "integer", "string", "number", "boolean", "function", "table", "thread", "userdata" }

-- Key formats --
local KeyFormats = { integer = "%s[%i] = %s", number = "%s[%f] = %s", string = "%s%s = %s" }

-- v: Value to format
-- guard: Cycle guard
-- Returns: Type name, pretty print form of value
local function Pretty (v, guard)
	local vtype = type(v)

	if vtype == "number" and IsInteger(v) then
		return "integer", format("%i", v)
	elseif vtype == "string" then
		return "string", format("\"%s\"", v)
	elseif vtype == "table" then
		if guard[v] then
			return "cycle", format("CYCLE, %s", tostring(v))
		else
			return "table", "{"
		end
	else
		return vtype, tostring(v)
	end
end

-- Returns: If true, k1 < k2
local function KeyComp (k1, k2)
	return tostring(k1) < tostring(k2)
end

-- Prints a table level
-- t: Current table
-- outf: Formatted output routine
-- indent: Current indentation
-- guard: Cycle guard
local function PrintLevel (t, outf, indent, guard)
	local lists = SubTablesOnDemand()
	local member_indent = indent .. "   "

	-- Mark this table to guard against cycles.
	guard[t] = true

	-- Collect fields into tables.
	for k in pairs(t) do
		local ktype = type(k)

		if ktype == "number" and IsInteger(k) then
			ktype = "integer"
		end

		insert(lists[ktype], k)
	end

	-- Iterate over types with elements.
	for _, name in ipairs(Names) do
		local subt = rawget(lists, name)
		local kformat = KeyFormats[name]

		if subt then
			sort(subt, not kformat and KeyComp or nil)

			for _, k in ipairs(subt) do
				local v = rawget(t, k)
				local vtype, vstr

				-- Print out the current line. If the value has string conversion, use
				-- that, ignoring its type. Otherwise, if this is a table, this will open
				-- it up; proceed to recursively dump the table itself.
				if HasMeta(v, "__tostring") then
					vstr = tostring(v)
				else
					vtype, vstr = Pretty(v, guard)
				end

				outf(kformat or "%s[%s] = %s", member_indent, kformat and k or tostring(k), vstr)

				if vtype == "table" then
					PrintLevel(v, outf, member_indent, guard)
				end
			end
		end
	end

	-- Close this table.
	outf("%s} (%s)", indent, tostring(t))
end

--- Pretty prints a variable.
-- @param var Variable to print.
-- @param outf Formatted output routine, i.e. with an interface like <b>string.format</b>;
-- if absent, the default output function is used.
-- @param indent Initial indent string; if absent, the empty string.<br><br>
-- If the variable is a table, this is prepended to each line of the printout.
-- @see SetDefaultOutf
function Print (var, outf, indent)
	outf = outf or DefaultOutf
	indent = indent or ""

	assert(IsCallable(outf), "Invalid output function")

	if HasMeta(var, "__tostring") then
		outf("%s%s", indent, tostring(var))

	elseif type(var) == "table" then
		outf("%stable: {", indent)

		PrintLevel(var, outf, indent, {})

	else
		local vtype, vstr = Pretty(var)

		-- Output the pretty form of the variable. With some types, forgo prefacing them
		-- with their type name, since prettying will make it redundant.
		if vtype == "function" or vtype == "nil" or vtype == "thread" or vtype == "userdata" then
			outf("%s%s", indent, vstr)
		else
			outf("%s%s: %s", indent, vtype, vstr)
		end
	end
end

--- Sets the default output function used by <b>Print</b>.
-- @param outf Output function to assign, or <b>nil</b> to clear the default.
-- @see Print
function SetDefaultOutf (outf)
	assert(outf == nil or IsCallable(outf), "Invalid output function")

	DefaultOutf = outf
end