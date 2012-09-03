-- Modules --
local la = love.audio
local lf = love.filesystem
local lg = love.graphics
local lp = love.physics

-- Type bindings --
local Types = table_ex.Weak("k")

-- Helper to build new function
-- type: Type to associate
-- func: Function to wrap
-- Returns: Wrapped function
local function Wrap (type, func)
	return function(...)
		local instance = func(...)

		Types[instance] = type

		return instance
	end
end

-- Override the functions.
local funcs_types = {
	-- Audio --
	la, "newMusic", "Music",
	la, "newSound", "Sound",

	-- File system --
	lf, "newFile", "File",

	-- Graphics --
	lg, "newAnimation", "Animation",
	lg, "newColor", "Color",
	lg, "newFont", "Font",
	lg, "newImageFont", "Font",
	lg, "newImage", "Image",
	lg, "newParticleSystem", "ParticleSystem",

	-- Physics --
	lp, "newBody", "Body",
	lp, "newCircleShape", "CircleShape",
	lp, "newDistanceJoint", "DistanceJoint",
	lp, "newMouseJoint", "MouseJoint",
	lp, "newPolygonShape", "PolygonShape",
	lp, "newRectangleShape", "PolygonShape",
	lp, "newPrismaticJoint", "PrismaticJoint",
	lp, "newRevoluteJoint", "RevoluteJoint",
	lp, "newWorld", "World"
}

for i = 1, #funcs_types, 3 do
	local module, name, type = unpack(funcs_types, i, i + 2)

	module[name] = Wrap(type, module[name])
end

-- Export the loveclasses namespace.
module "loveclasses"

---------------------------------------------------------------
-- @param instance Instance to check for type name.
-- @return Love instance type name, or nil if not an instance.
function TypeName (instance)
	return Types[instance or 0]
end