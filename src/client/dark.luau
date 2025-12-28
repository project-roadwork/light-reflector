--!strict
--!native
-- USAGE: lightreflector/client/dark.luau
-- Dark conditions for Light Reflector

--[[

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at https://mozilla.org/MPL/2.0/.

]]

-- Types Module
local types = require("../shared/types")

-- Configuration
local config = require("../shared/config")

-- Debugger
local debugger = require("../shared/debugger")

-- Sevices
local Lighting:Lighting = game:GetService("Lighting")
local ReplicatedStorage:ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Dark weathers (TTP / Redon Tech weather system compatibility)
local darkWeathers: types.DarkWeathers = {
	["Heavy Rain"] = true,
	["Thunderstorms"] = true,
	["Strong Thunderstorms"] = true,
	["Heavy Rain / Snow"] = true
}

local AlreadyPrinted: boolean = false

-- Public: Dark conditional function
return function(): boolean -- Additionally includes TTP / Redon Tech weather compatibility. Expand should you wish.
	local clockTime: number = Lighting.ClockTime
	local Weather: Folder? = ReplicatedStorage:FindFirstChild("WeatherResources") :: Folder?
	local canCount = false

	local DarkClockTimeStart = config.DarkClockTimeStart
	local DarkClockTimeEnd = config.DarkClockTimeEnd

	if Weather then
		local WeatherFolder: Folder? = Weather:FindFirstChild("Weather") :: Folder?
		if WeatherFolder then
			local CurrentFolder: Folder? = WeatherFolder:FindFirstChild("Current") :: Folder?

			if CurrentFolder then
				local WeatherValue: StringValue? = CurrentFolder:FindFirstChild("Weather") :: StringValue?
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
