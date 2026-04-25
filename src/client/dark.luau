--!strict
--!native
-- USAGE: lightreflector/client/dark.luau
-- Dark conditions for Light Reflector (fully typed)

--[[
    SPDX-FileCopyrightText: 2025-2026 Illinois_Roadbuff <illinois_roadbuff@proton.me>
    SPDX-FileCopyrightText: 2025-2026 Project Roadwork and Contributors

    SPDX-License-Identifier: MPL-2.0

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at https://mozilla.org/MPL/2.0/.

]]

-- IMPORTANT: Services
const Lighting: Lighting = game:GetService("Lighting")
const ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

-- IMPORTANT: Modules
const types = require("../shared/types")
const config: types.Configuration = require("../shared/config")

-- Configuration Variables
local baseConfig: types.BASE_CONFIG = config.getConfig()
local generalConfig: types.GeneralConfig = baseConfig.General
local darkStart: number = generalConfig.darkClockTimeStart
local darkEnd: number = generalConfig.darkClockTimeEnd

-- Dark weathers table (TTP / Redon Tech weather system compatibility)
const darkWeathers: types.DarkWeathers = {
	["Heavy Rain"] = true,
	["Thunderstorms"] = true,
	["Strong Thunderstorms"] = true,
	["Heavy Rain / Snow"] = true
}
-- Variables
local _isConfigTracked: boolean = false
local _weatherValue: StringValue? = nil
local _isWeatherDark: boolean = false
local _clockTime: number = Lighting.ClockTime

--[=[
	Private: Resolves weather
	@private

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function _resolveWeather(): ()  -- Includes TTP / Redon Tech weather compatibility. Expand should you wish.
	const Weather: Instance? = ReplicatedStorage:WaitForChild("WeatherResources", 10)
	if not Weather then return end

	const WeatherFolder: Instance? = Weather:FindFirstChild("Weather")
	if not WeatherFolder then return end

	const CurrentFolder: Instance? = WeatherFolder:FindFirstChild("Current")
	if not CurrentFolder then return end

	const Value: Instance? = CurrentFolder:FindFirstChild("Weather")
	if Value and Value:IsA("StringValue") then
		_weatherValue = Value
		_isWeatherDark = darkWeathers[Value.Value] or false
		Value:GetPropertyChangedSignal("Value"):Connect(function()
			_isWeatherDark = darkWeathers[Value.Value] or false
		end)
	end
end

-- Start config tracking
config.waitForLock(function(): ()
	if _isConfigTracked == false then
		config.onChange(function(NEW_CONFIG: types.BASE_CONFIG)
			baseConfig = NEW_CONFIG
			generalConfig = NEW_CONFIG.General
			darkStart = generalConfig.darkClockTimeStart
			darkEnd = generalConfig.darkClockTimeEnd
		end)

		task.defer(_resolveWeather)

		Lighting:GetPropertyChangedSignal("ClockTime"):Connect(function()
			_clockTime = Lighting.ClockTime
		end)

		_isConfigTracked = true
	end
end)

--[=[
	Public: Dark conditional function

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
return function(): boolean
	const isNight: boolean = (_clockTime >= darkStart or _clockTime < darkEnd)

	return isNight or _isWeatherDark
end
