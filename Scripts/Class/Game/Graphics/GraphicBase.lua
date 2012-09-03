-- See TacoShell Copyright Notice in main folder of distribution

-- Standard library imports --
local assert = assert
local type = type
local unpack = unpack

-- Imports --
local GetColorRGBA = graphics.GetColorRGBA
local setBlendMode = love.graphics.setBlendMode
local setColor = love.graphics.setColor
local setColorMode = love.graphics.setColorMode
local TypeName = loveclasses.TypeName

-- Unique member keys --
local _blend_mode_keep = {}
local _blend_mode_policy = {}
local _color_keep = {}
local _color_policy = {}
local _color_mode_keep = {}
local _color_mode_policy = {}

-- Color options --
local Color = table_ex.MakeSet{ "default", "current" }

-- Blend mode getter, setter, options --
local BlendMode = {
	normal = love.blend_normal,
	additive = love.blend_additive,
	current = true,

	-- The array part gets unpacked by SetMode.
	love.graphics.getBlendMode, setBlendMode
}

-- Color mode getter, setter, options --
local ColorMode = {
	normal = love.color_normal,
	modulate = love.color_modulate,
	current = true,

	-- The array part gets unpacked by SetMode.
	love.graphics.getColorMode, setColorMode
}

-- GraphicBase class definition --
class.Define("GraphicBase", function(MT)
	-- Helper for setting and restoring mode
	-- B: Base handle
	-- name: Mode name
	-- modes: Mode lookup set
	-- policy_key: Key used to lookup default mode name
	-- keep_key: Key used to lookup keep status
	local function SetMode (B, name, modes, policy_key, keep_key)
		name = name or B[policy_key]

		if name ~= "current" then
			local get, set = unpack(modes)
			local cur = get()

			if modes[name] ~= cur then
				set(modes[name])

				return not B[keep_key] and cur
			end
		end
	end

	-- props: Draw properties
	-- func: Wrapped function
	-- ...: Function arguments
	---------------------------
	function MT:WithProperties (props, func, ...)
		-- When called for, switch the color. If this change should not be kept, cache the
		-- current color to restore afterward.
		local color = props.color or self[_color_policy]
		local R, G, B, A

		if color ~= "current" then
			if not self[_color_keep] then
				R, G, B, A = GetColorRGBA("current")
			end

			-- Given a color object, apply that directly. Otherwise, do a lookup with the
			-- color name and apply the results.
			if TypeName(color) == "Color" then
				setColor(color)
			else
				setColor(GetColorRGBA(color))
			end
		end

		-- When called for, switch the blend and / or color mode. If a change is not to be
		-- kept, cache the current setting for that mode to restore afterward.
		local bmode = SetMode(self, props.blend_mode, BlendMode, _blend_mode_policy, _blend_mode_keep)
		local cmode = SetMode(self, props.color_mode, ColorMode, _color_mode_policy, _color_mode_keep)

		-- Invoke the function.
		func(props, ...)

		-- Restore the original value in each case where a change occurred and keeping the
		-- new value was not requested.
		if R then
			setColor(R, G, B, A)
		end

		if bmode then
			setBlendMode(bmode)
		end

		if cmode then
			setColorMode(cmode)
		end
	end

	-- Install policy setters
	--------------------------
	for k, func in pairs{
		SetColor = { Color, _color_policy, _color_keep, "Unsupported color policy" },
		SetBlendMode = { BlendMode, _blend_mode_policy, _blend_mode_keep, "Unsupported blend mode policy" },
		SetColorMode = { ColorMode, _color_mode_policy, _color_mode_keep, "Unsupported color mode policy" }
	} do
		local set, policy_key, keep_key, error = unpack(func)

		MT[k .. "Policy"] = function(B, policy)
			assert(type(policy) == "string" and set[policy], error)

			B[policy_key] = policy
		end

		MT[k .. "Keep"] = function(B, keep)
			B[keep_key] = not not keep
		end
	end
end,

-- Constructor
---------------
function(B)
	B[_color_policy], B[_color_keep] = "default", false
	B[_blend_mode_policy], B[_blend_mode_keep] = "normal", false
	B[_color_mode_policy], B[_color_mode_keep] = "normal", false
end)