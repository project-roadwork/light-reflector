--!strict
--!native
-- USAGE: vehicle-reflector-handler.client.luau
-- Vehicle handler and initializer for Light Reflector

--[[
    SPDX-FileCopyrightText: NONE

    SPDX-License-Identifier: CC0-1.0 OR Unlicense
]]
-- Variables
local ReplicatedStorage = game:GetService("ReplicatedStorage")
local LightReflector = require(ReplicatedStorage.Packages.lightreflector)
local Cars = workspace.Cars


-- Functions
local function determineIntensity(car:Instance)
  local finalIntensity = 1
-- logic to see if high beams are enabled or not (thus increase the intensity)
  return finalIntensity
end

local function CheckForRegLightValue(car:Model)
	local Body = car.Body
	local Headlight = Body:FindFirstChild("Headlight")

	if Headlight then
		return Headlight.on -- Smeers light handler compatiblity
	end

	-- split since some A-Chassis cars apparently may not have a Vehicle seat once initialized, erroring the entire function
	local DriveSeat = car:FindFirstChildOfClass("VehicleSeat")

	assert(DriveSeat, `:: LightReflectorHandler :: Failed to find VehicleSeat in {car.Name}; halting execution. Please investigate!`)

	local LightValues = DriveSeat:FindFirstChild("LightValues")
	local Lights = if DriveSeat:FindFirstChild("Values") then DriveSeat.Values:FindFirstChild("Lights") else nil

	if LightValues and LightValues:FindFirstChild("LB") then
		return LightValues.LB -- Aura Deios compatibility
	elseif Lights and Lights:FindFirstChild("LightStage") then
		return Lights.LightStage -- Saragati Lagrande EXC compatibility
	else
		warn(`:: LightReflectorHandler :: Failed to find headlight values for car {car.Name}, resorting to boolean "true"`)
		return true
	end
end

LightReflector.config.applyOverrides({
	SignConfig = {
		SignsFolders = {workspace.Signs}
	}
})

LightReflector.start()

task.wait(2)

for i, car in Cars:GetChildren() do
    if car:IsA("Model") and (car:FindFirstChildOfClass("VehicleSeat") or car:WaitForChild("DriveSeat",5)) then
		print("Indexed Vehicle")
		LightReflector.register.addVehicle(car, CheckForRegLightValue(car), determineIntensity)
	end
end

Cars.ChildAdded:Connect(function(car)
	task.wait() -- a-chassis init reasons
	if car:IsA("Model") and (car:FindFirstChildOfClass("VehicleSeat") or car:WaitForChild("DriveSeat",5)) then
		print("Indexed Vehicle")
		LightReflector.register.addVehicle(car, CheckForRegLightValue(car), determineIntensity)
	end
end)

workspace.Cars.ChildRemoved:Connect(function(car)
	if car:IsA("Model") and (car:FindFirstChildOfClass("VehicleSeat") or car:WaitForChild("DriveSeat",5)) then
		LightReflector.register.removeVehicle(car)
	end
end)

print(`:: vehicle-reflector-handler :: Loaded successfully!`)
