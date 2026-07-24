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

-- IMPORTANT: Modules
const types = require("../shared/types")
const config: types.Configuration = require("../shared/config")

-- IMPORTANT: Configuration Variables
local baseConfig: types.BaseConfig = config.getConfig()
local constraints: types.Constraints = baseConfig.Constraints
local generalConfig: types.GeneralConfig = baseConfig.General

local PROFILING: boolean = constraints.PROFILING
local hasInit: boolean = false
const list : types.SourceList = {}

--[=[
	Public: Creates a source

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function create(source: BasePart,
    model: Model?,
	getPosition: () -> Vector3,
	getDirection: () -> Vector3,
	getEnabled: ((BasePart) -> boolean),
	intensity: ((BasePart) -> number)?,
	getColor: ((BasePart) -> vector)?
): types.LightSource

    const getIntensity: (BasePart) -> number = if intensity then intensity else function(source) return 1 end

	return {
		Owner = source,
		Model = model,
		getPosition = getPosition,
		getDirection = getDirection,
		Position = getPosition(),
        Direction = getDirection(),
        Intensity = getIntensity(source),
		isActive = getEnabled,
		getIntensity = getIntensity,
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
    model: Model?,
	getPosition: () -> Vector3,
	getDirection: () -> Vector3,
	getEnabled: (BasePart) -> boolean,
	intensity: ((BasePart) -> number)?,
    getColor: ((BasePart) -> vector)?
): types.LightSource

	return add(create(source, model, getPosition, getDirection, getEnabled, intensity, getColor))
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

--[=[
	Public: Updates the CFrame and position of all sources

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function updateSourceCache(): ()
    if PROFILING then
        debug.profilebegin("updateSourceTransforms")
    end

    for _: number, lightSource: types.LightSource in list do
        const sourceCFrame: CFrame = lightSource.Owner.CFrame

        lightSource.Position = sourceCFrame.Position + generalConfig.vehicleSeatOffset
        lightSource.Direction = sourceCFrame.LookVector
        lightSource.Intensity = lightSource.getIntensity(lightSource.Owner)
    end

    if PROFILING then
        debug.profileend()
    end
end

--[=[
	Public: Initialize

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function init(): ()
	if hasInit then
		return
	end

	config.onChange(function(NEW_CONFIG: types.BASE_CONFIG)
		baseConfig = NEW_CONFIG
		constraints = NEW_CONFIG.Constraints
		generalConfig = NEW_CONFIG.General

		PROFILING = constraints.PROFILING
	end)

	hasInit = true
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
	updateSourceCache = updateSourceCache,
	init = init
})
