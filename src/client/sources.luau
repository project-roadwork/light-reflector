--!native
--!strict
-- USAGE: lightreflector/client/sources.luau
-- Sources registry for Light Reflector

-- Types module
local types = require("../shared/types")

-- Array of sources
local list : types.SourceList = {}

-- Public: Creates a source
local function create(car: Instance | types.Vehicle,
	getPosition: () -> Vector3,
	getDirection: () -> Vector3,
	getEnabled: (() -> boolean | () -> number),
	intensity: number?
): types.LightSource

	return {
		Owner = car,
		getPosition = getPosition,
		getDirection = getDirection,
		isActive = getEnabled or function() return true end,
		Intensity = intensity or 1
	}
end

-- Public: Adds a source
local function add(source: types.LightSource)
	table.insert(list, source)
	return source
end

-- Public: Cretes and adds a source
local function register(car: Instance | types.Vehicle,
	getPosition: () -> Vector3,
	getDirection: () -> Vector3,
	getEnabled: () -> boolean | () -> number,
	intensity: number?
): types.LightSource

	return add(create(car, getPosition, getDirection, getEnabled, intensity))
end

-- Public: Checks if any source is active
local function anyActive(): boolean
	for _, source in list do
		if source.isActive() then
			return true
		end
	end
	return false
end

return table.freeze({
	Name = "sources",
	list = list,
	create = create,
	add = add,
	anyActive = anyActive,
	register = register
})
