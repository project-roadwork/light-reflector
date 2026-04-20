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

-- Types Module
const types = require("../shared/types")

-- Configuration
const config: types.Configuration = require("../shared/config")

-- Debugger
const debugger: types.Debugger = require("../shared/debugger")

-- Services
const Lighting:Lighting = game:GetService("Lighting")
const ReplicatedStorage:ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dark weathers (TTP / Redon Tech weather system compatibility)
const darkWeathers: types.DarkWeathers = {
	["Heavy Rain"] = true,
	["Thunderstorms"] = true,
	["Strong Thunderstorms"] = true,
	["Heavy Rain / Snow"] = true
}

-- Variables
local AlreadyPrinted: boolean = false

--[=[
	Public: Dark conditional function

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
return function(): boolean -- Additionally includes TTP / Redon Tech weather compatibility. Expand should you wish.
	local canCount: boolean = false

	const General = config.getConfig().General

	const clockTime: number = Lighting.ClockTime
	const Weather: Folder? = ReplicatedStorage:FindFirstChild("WeatherResources") :: Folder?
	const DarkClockTimeStart: number = General.darkClockTimeStart
	const DarkClockTimeEnd: number = General.darkClockTimeEnd

	if Weather then
		const WeatherFolder: Folder? = Weather:FindFirstChild("Weather") :: Folder?
		if WeatherFolder then
			const CurrentFolder: Folder? = WeatherFolder:FindFirstChild("Current") :: Folder?

			if CurrentFolder then
				const WeatherValue: StringValue? = CurrentFolder:FindFirstChild("Weather") :: StringValue?
				if WeatherValue and darkWeathers[WeatherValue.Value] then
					canCount = true
				end
			end
		end
	elseif AlreadyPrinted == false then
		AlreadyPrinted = true
		debugger.print("Info","Unable to find Weather System")
	end

	return (clockTime >= DarkClockTimeStart or clockTime < DarkClockTimeEnd)
		or canCount
end
