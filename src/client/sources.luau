--!native
--!strict
-- USAGE: lightreflector/client/sources.luau
-- Sources registry for Light Reflector

--[[
    SPDX-FileCopyrightText: 2025-2026 Illinois_Roadbuff <illinois_roadbuff@proton.me>
    SPDX-FileCopyrightText: 2025-2026 Project Roadwork and Contributors

    SPDX-License-Identifier: MPL-2.0

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at https://mozilla.org/MPL/2.0/.

]]

-- Types module
const types = require("../shared/types")

-- Array of sources
const list : types.SourceList = {}

-- Public: Creates a source
const function create(car: Instance | types.Vehicle,
	getPosition: () -> Vector3,
	getDirection: () -> Vector3,
	getEnabled: (() -> boolean | () -> number),
	intensity: ((Instance) -> number)?
): types.LightSource

	return {
		Owner = car :: Instance,
		getPosition = getPosition,
		getDirection = getDirection,
		isActive = getEnabled or function() return true end,
		getIntensity = if intensity then intensity else function(car) return 1 end,
	}
end

-- Public: Adds a source
const function add(source: types.LightSource): types.LightSource
	table.insert(list, source)
	return source
end

-- Public: Cretes and adds a source
const function register(car: Instance | types.Vehicle,
	getPosition: () -> Vector3,
	getDirection: () -> Vector3,
	getEnabled: () -> boolean | () -> number,
	intensity: ((Instance) -> number)?
): types.LightSource

	return add(create(car, getPosition, getDirection, getEnabled, intensity))
end

-- Public: Checks if any source is active
const function anyActive(): boolean
	for _, source in list do
		if source.isActive() then
			return true
		end
	end
	return false
end

const function getAllActive(): {types.LightSource}
	const activeSources = {}
	for _, source in list do
		if source.isActive() then
			table.insert(activeSources, source)
		end
	end
	return activeSources
end

return table.freeze({
	Name = "sources",
	list = list,
	create = create,
	add = add,
	anyActive = anyActive,
	register = register,
	getAllActive = getAllActive,
}) :: types.SourcesModule -- must add this since table.freeze destroys my strict typing >:(
