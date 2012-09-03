----------------------------
-- Standard library imports
----------------------------
local assert = assert
local type = type

-- Export the settings namespace.
module "settings"

--------------------
-- Current language
--------------------
local Language

-- Returns: Current language
-----------------------------
function GetLanguage ()
	return assert(Language, "Language setting unavailable")
end

-- language: Name of language to assign
----------------------------------------
function SetLanguage (language)
	assert(type(language) == "string", "Invalid language")

	Language = language
end