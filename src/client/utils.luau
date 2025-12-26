--!native
--!strict
-- USAGE: lightreflector/client/utils.luau
-- Utilities for Light Reflector

-- Types module
local types = require("../shared/types")

-- Configuration
local config: types.Configuration = require("../shared/config")

-- Public: Deep merges two dictionaries
local function deepMerge(defaults: types.Dict, overrides: types.Dict): ()
	for key, value in pairs(overrides) do
		if typeof(value) == "table" and typeof(defaults[key]) == "table" then
			deepMerge(defaults[key], value)
		else
			defaults[key] = value
		end
	end
end

-- Public: Assigns config via deep merge
local function assignConfig(userConfig): types.Configuration
	if typeof(userConfig) ~= "table" then
		return config
	end

	deepMerge(config :: types.Dict, userConfig)
	return config
end

-- Public: Gets speed in MPH via respective MPH scale
local function getSpeedMPH(DriveSeat: VehicleSeat): number
	return DriveSeat.AssemblyLinearVelocity.Magnitude * config.MphScale
end

-- Public: Adaptive wait time based on vehicle speed
local function adaptiveWait(minFPS: number, maxFPS: number, DriveSeat: VehicleSeat?): number
	if not DriveSeat then
		return 1 / maxFPS
	end

	local speedMph = getSpeedMPH(DriveSeat)
	local targetFPS = math.clamp((speedMph / 80) * maxFPS, minFPS, maxFPS)
	return 1 / targetFPS
end

-- Public: Gets the fastest VehicleSeat in a vehicle map table
local function getFastestDriveSeat(Vehicles: types.VehicleMap)
	local fastestSeat = nil
	local maxSpeed = 0

	for car in Vehicles do
		local seat = car:FindFirstChildOfClass("VehicleSeat")
		if seat then
			local speed = seat.AssemblyLinearVelocity.Magnitude
			if speed > maxSpeed then
				maxSpeed = speed
				fastestSeat = seat
			end
		end
	end

	return fastestSeat
end

-- Public: Determines if a part is a reflector
local function isPavementReflector(part: BasePart): boolean
	return config.ReflectorConfig.Enabled
		and part:IsA("BasePart")
		and part.Name == config.ReflectorConfig.PartName
end

-- Public: Fixes the orientation of a sign part
local function fixPartOrientation(part: BasePart, decal: Decal)
	local isFixed: boolean? = part:GetAttribute("IsFixed")
	if isFixed == true then return end

	if decal.Face == Enum.NormalId.Top then
		part.CFrame *= CFrame.Angles(0, math.rad(-90), math.rad(-90))

		local size = part.Size
		part.Size = Vector3.new(size.Y, size.Z, size.X)
		decal.Face = Enum.NormalId.Left

		for i,decal in part:GetChildren() do
			if decal:IsA("Decal") and decal.Face == Enum.NormalId.Bottom then
				decal.Face = Enum.NormalId.Right
			end
		end
		part:SetAttribute("IsFixed", true)
	end
end

-- Public: Normalizes the base color of a part
local function normalizeBaseColor(part: BasePart): Color3
	local color = part.Color
	if part:GetAttribute("BaseColor") then return color end

	local maxComponent = math.max(color.R, color.G, color.B)

	local threshold = 0.9
	local targetMax = 0.6

	if maxComponent > threshold then
		local scale = targetMax / maxComponent
		color = Color3.new(color.R * scale, color.G * scale, color.B * scale)
	end

	part:SetAttribute("BaseColor", color)

	return color
end

return table.freeze({
	Name = "utils",
	deepMerge = deepMerge,
	assignConfig = assignConfig,
	getSpeedMPH = getSpeedMPH,
	adaptiveWait = adaptiveWait,
	getFastestDriveSeat = getFastestDriveSeat,
	isPavementReflector = isPavementReflector,
	fixPartOrientation = fixPartOrientation,
	normalizeBaseColor = normalizeBaseColor
})
