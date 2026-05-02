--!native
--!strict
-- USAGE: lightreflector/client/sources.luau
-- Sources registry for Light Reflector

--[[
    SPDX-FileCopyrightText: 2025-2026 Illinois_Roadbuff (Rogue Jr) <illinois_roadbuff@proton.me>
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

--[=[
	Public: Creates a source

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function create(source: BasePart,
	getPosition: () -> Vector3,
	getDirection: () -> Vector3,
	getEnabled: ((BasePart) -> boolean),
	intensity: ((BasePart) -> number)?,
	getColor: ((BasePart) -> vector)?
): types.LightSource

	return {
		Owner = source,
		getPosition = getPosition,
		getDirection = getDirection,
		isActive = getEnabled,
		getIntensity = if intensity then intensity else function(source) return 1 end,
		getColor = if getColor then getColor else function(source) return vector.create(1, 1, 1) end,
	}
end

--[=[
	Public: Adds a source

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function add(lightSource: types.LightSource): types.LightSource
	table.insert(list, lightSource)
	return lightSource
end

--[=[
	Public: Creates and adds a source

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function register(source: BasePart,
	getPosition: () -> Vector3,
	getDirection: () -> Vector3,
	getEnabled: (BasePart) -> boolean,
	intensity: ((BasePart) -> number)?,
    getColor: ((BasePart) -> vector)?
): types.LightSource

	return add(create(source, getPosition, getDirection, getEnabled, intensity, getColor))
end

--[=[
	Public: Checks if any source is active

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function anyActive(): boolean
	for _: number, lightSource: types.LightSource in list do
		if lightSource.isActive(lightSource.Owner) then
			return true
		end
	end
	return false
end

--[=[
	Public: Returns all active sources

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function getAllActive(): {types.LightSource}
	const activeSources: {types.LightSource} = {}
	for _: number, lightSource: types.LightSource in list do
		if lightSource.isActive(lightSource.Owner) then
			table.insert(activeSources, lightSource)
		end
	end
	return activeSources
end

-- Return public API
return table.freeze({
	name = "sources",
	list = list,
	create = create,
	add = add,
	anyActive = anyActive,
	register = register,
	getAllActive = getAllActive,
})
