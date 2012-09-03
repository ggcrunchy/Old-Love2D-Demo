-- See TacoShell Copyright Notice in main folder of distribution

----------------------------
-- Standard library imports
----------------------------
local assert = assert
local ipairs = ipairs
local pairs = pairs
local rawequal = rawequal

-----------
-- Imports
-----------
local CollectArgsInto = varops.CollectArgsInto
local Weak = table_ex.Weak

----------------------
-- Unique member keys
----------------------
local _forbids = {}
local _is_blacklist = {}
local _key = {}
local _permissions = {}

-----------------------------
-- Sealable class definition
-----------------------------
class.Define("Sealable", function(MT)
	-- Looks up a permissions list
	-- S: Sealable handle
	-- id: Lookup ID
	-- Returns: List, if available
	-------------------------------
	local function GetPermissionsList (S, id)
		assert(id ~= nil, "id == nil")

		local permissions = S[_permissions]

		return permissions and permissions[id]
	end

	-- Indicates whether a client has a given permission
	-- id: Lookup ID
	-- what: Permission to query
	-- Returns: If true, client has permission
	-----------------------------------------------------
	function MT:HasPermission (id, what)
		assert(what ~= nil, "what == nil")

		local permissions = assert(GetPermissionsList(self, id), "Invalid client ID")

		-- If no changes have yet been made, the client has full permissions. Otherwise,
		-- search for the query among the permissions. In blacklist mode, permission is
		-- granted if the query fails; in whitelist mode, the query must succeed.
		return permissions == "" or permissions[_is_blacklist] == not permissions[what]
	end

	-- key: Key to test
	-- Returns: If true, key is the access key
	-------------------------------------------
	function MT:MatchesKey (key)
		return rawequal(self[_key], key)
	end

	-- Cache methods for internal use.
	local HasPermission = MT.HasPermission
	local MatchesKey = MT.MatchesKey

	-- Adds a new client with configurable permissions
	-- key: Access key, for validation
	-- Returns: Lookup ID
	---------------------------------------------------
	function MT:AddClient (key)
		assert(MatchesKey(self, key), "Key mismatch")

		-- Install a client list if this is the first one. Generate a unique ID.
		local permissions = self[_permissions] or Weak("k")
		local id = {}

		-- Load the client. Give it full permissions by default.
		self[_permissions] = permissions

		permissions[id] = ""

		return id
	end

	----------------------------
	-- Valid permission options
	----------------------------
	local Options = table_ex.MakeSet{ "blacklist", "whitelist", "+", "-" }

	-- Changes a client's permissions
	-- key: Access key, for validation
	-- id: Lookup ID
	-- how: Type of change to apply
	-- ...: Changes to apply
	-----------------------------------
	function MT:ChangePermissions (key, id, how, ...)
		assert(MatchesKey(self, key), "Key mismatch")
		assert(how ~= nil and Options[how], "Invalid permission option")

		-- Validate the changes.
		local count, changes = CollectArgsInto(nil, ...)

		for i = 1, count do
			assert(changes[i] ~= nil, "Nil change")
			assert(changes[i] == changes[i], "NaN change")
		end

		-- If a new whitelist or blacklist is requested, build it. New clients have full
		-- permissions, and thus implicitly have empty blacklists; if additions or removals
		-- are to be made, make this explicit.
		local permissions = assert(GetPermissionsList(self, id), "Invalid client ID")

		if permissions == "" or how == "blacklist" or how == "whitelist" then
			permissions = { [_is_blacklist] = how ~= "whitelist" }

			-- Replace the old list.
			self[_permissions][id] = permissions
		end

		-- For additions/removals, the following holds:
		-- > Add: Add to whitelist or remove from blacklist
		-- > Remove: Add to blacklist or remove from whitelist
		local should_add = true

		if how == "+" or how == "-" then
			should_add = (how == "+" ~= permissions[_is_blacklist]) or nil
		end

		-- Apply the changes. A removal will clear an entry.
		for _, change in ipairs(changes) do
			permissions[change] = should_add
		end
	end

	-- id: Lookup id
	-- Returns: Blacklist boolean, list
	------------------------------------
	function MT:GetPermissions (id)
		local permissions = assert(GetPermissionsList(self, id), "Invalid client ID")
		local is_blaclist = true
		local t = {}

		if permissions ~= "" then
			is_blaclist = permissions[_is_blacklist]

			for k in pairs(permissions) do
				t[#t + 1] = k
			end
		end

		return is_blaclist, t
	end

	-- what: Property to test
	-- Returns: If true, property change is allowed
	------------------------------------------------
	function MT:IsAllowed (what)
		assert(what ~= nil, "what == nil")

		local forbids = self[_forbids]

		return (forbids and forbids[what]) == nil
	end

	-- id: Lookup ID
	-- Returns: If true, lookup ID belongs to a client
	---------------------------------------------------
	function MT:IsClient (id)
		return id ~= nil and GetPermissionsList(self, id) ~= nil
	end

	-- Sets allowance for future changes to a property
	-- what: Property change (requires corresponding permission)
	-- id_or_key: Lookup ID or access key, for validation
	-- bAllow: If true, allow future changes
	-------------------------------------------------------------
	function MT:SetAllowed (what, id_or_key, bAllow)
		assert(what == what, "what is NaN")
		assert(MatchesKey(self, id_or_key) or HasPermission(self, id_or_key, what), "Key mismatch or forbidden client")

		local forbids = self[_forbids]

		if not bAllow then
			forbids = forbids or {}

			self[_forbids] = forbids

			forbids[what] = true

		elseif forbids then
			forbids[what] = nil
		end
	end

	-- new: Access key to assign
	-- old: Current key, for validation
	-- Returns: If true, key was set
	------------------------------------
	function MT:SetKey (new, old)
		local is_match = MatchesKey(self, old)

		if is_match then
			self[_key] = new
		end

		return is_match
	end
end,

-- Constructor
---------------
funcops.NoOp)