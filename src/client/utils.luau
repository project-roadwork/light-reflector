--!native
--!strict
-- USAGE: lightreflector/client/utils.luau
-- Utilities for Light Reflector

--[[

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at https://mozilla.org/MPL/2.0/.

]]

-- Services
local RunService:RunService = game:GetService("RunService")

-- Types module
local types = require("../shared/types")

-- Debugger
local debugger = require("../shared/debugger")

-- Sources
local sources = require("./sources")

-- Configuration
local config: types.Configuration = require("../shared/config")

-- Variables
local PreRender: RBXScriptSignal = RunService.PreRender

-- Valid faces for Enum.NormalId
local validFaces: { [string]: boolean }  =  {
	Top = true,
	Bottom = true,
	Left = true,
	Right = true,
	Front = true,
	Back = true
}

-- Variables
local INV_30 = 1 / 50
local MPH_SCALE = config.Constraints.MPH_SCALE

local sourcesCheckEnabled = false
local lastSources = sources.getAllActive()
local currentSources = lastSources

-- Public: Waits via RunService.PreRender rather than RunService.Heartbeat
local function renderWait(waitTime: number?): number
	if waitTime ~= nil then
		local total:number = 0

		while total < waitTime do
			total += PreRender.Wait(PreRender) -- I think .Function(self) (explicit) is faster than :Function() (implicit)?
		end

		return total
	else
		return PreRender.Wait(PreRender)
	end
end

-- Public: Tracks a part and calls a callback if it leaves workspace
local function trackAnsestryRemoval(instance: Instance, callback: (Instance) -> ()): RBXScriptConnection
	debugger.assert(typeof(instance) == "Instance", "onRemovedFromWorkspace: 'instance' must be a Roblox Instance")
	debugger.assert(typeof(callback) == "function", "onRemovedFromWorkspace: 'callback' must be a function")

	if not instance:IsDescendantOf(workspace) then
		pcall(callback, instance) -- no yield
	end

	local conn: RBXScriptConnection
	conn = instance.AncestryChanged:Connect(function(_, parent)
		if not instance:IsDescendantOf(workspace) then
			pcall(callback, instance)
			conn:Disconnect()
		end
	end)

	return conn
end

-- Public: Deep merges two dictionaries
local function deepMerge(defaults: types.Dict, overrides: types.Dict, path: string?): ()
	path = path or ""

	for key, value in next, overrides do
		if typeof(key) == "string" and defaults[key] == nil then
			local fullPath = path ~= "" and (`{path}.{key}`) or tostring(key)
			debugger.warn(
				"Warning",
				`Unknown configuration key: -> {fullPath} <-; are you sure it is spelled or capitalized correctly?`
			)
		end

		if typeof(value) == "table" and typeof(defaults[key]) == "table" then
			local nextPath = path ~= "" and (`{path}.{key}`) or tostring(key)
			deepMerge(defaults[key], value, nextPath)
		else
			defaults[key] = value
		end
	end
end


-- Public: Assigns config via deep merge
local function configure(userConfig): types.Configuration
	if typeof(userConfig) ~= "table" then
		return config
	end

	if userConfig["Constraints"] and config.Constraints.LOCKED then
		debugger.warn("Warning", "CONSTRAINTS is locked; cannot update configuration. Please remove CONSTRAINTS and try again.")
		return config
	end

	deepMerge(config :: types.Dict, userConfig)

	return config
end

-- Public: Gets speed in MPH via respective MPH scale
local function getSpeedMPH(DriveSeat: VehicleSeat): number
	local v = DriveSeat.AssemblyLinearVelocity
	-- converts studs to MPH based on the mphScale config

	return (v.X*v.X + v.Y*v.Y + v.Z*v.Z)^0.5 * MPH_SCALE -- maybe faster than .Magnitude?
end

-- Public: Adaptive wait time based on vehicle speed
local function adaptiveWait(waitFunction: (number?) -> number, minFPS: number, maxFPS: number, DriveSeat: VehicleSeat?): (number, number)
	-- faster VehicleSeat velocity = more FPS and vice versa
	if not DriveSeat then
		return waitFunction(1 / maxFPS), 50
	end

	local speedMph = getSpeedMPH(DriveSeat)

	local targetFPS = math.clamp(speedMph * INV_30 * maxFPS, minFPS, maxFPS)

	return waitFunction(1 / targetFPS), speedMph
end

-- Public: Gets the fastest VehicleSeat in a vehicle map table
local function getFastestDriveSeat(Vehicles: types.VehicleMap)
	-- ^ since the package is no longer tailored towards one vehicle, it needs to get the fastest drive seat out of all of the
	--    vehicles
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

local function startSeparateSourcesCheck()

	if sourcesCheckEnabled then
		return
	end

	sourcesCheckEnabled = true

	while true do
			local updatedSources = sources.getAllActive()
			local changed = false

			if #updatedSources ~= #currentSources then
				changed = true
			else
				for i = 1, #updatedSources do
					if updatedSources[i] ~= currentSources[i] then
						changed = true
						break
					end
				end
			end

			if changed then
				currentSources = updatedSources
			end

			task.wait(1/15)
	end

end

-- Public: Adaptive wait with override if sources change
local function adaptiveWaitWithSourcesOverride(
	waitFunction: (number?) -> number,
	minFPS: number,
	maxFPS: number,
	DriveSeat: VehicleSeat
	--onSourcesChanged: (types.SourceList) -> ()
): (number, number)

	task.defer(startSeparateSourcesCheck)

	local elapsed, speedMph = task.wait(1/59), 0

	local changed = false
	if #currentSources ~= #lastSources then
		changed = true
	else
		for i = 1, #currentSources do
			if currentSources[i] ~= lastSources[i] then
				changed = true
				break
			end
		end
	end

	if changed then
		--elapsed = waitFunction(0)
		speedMph = if DriveSeat then getSpeedMPH(DriveSeat) else 50
		lastSources = currentSources
	else
		elapsed, speedMph = adaptiveWait(waitFunction, minFPS, maxFPS, DriveSeat)
	end

	return elapsed, speedMph
end

-- Public: Fixes the orientation of a sign part
local function fixPartOrientation(part: BasePart, decal: Decal): ()
	-- ^ this function is needed since the top face in Decals and SurfaceGuis are NOT in the same orientation
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

-- Public: Normalizes the base color of a part if it is too low or too high
local function normalizeBaseColor(part: BasePart, isNormalizeEnabled: boolean): Color3
	-- if a reflector color is too low, it would barely light up at all. If it is too high, it would blind one's eyes
	local color = part.Color
	if part:GetAttribute("BaseColor") then return color end

	if isNormalizeEnabled == false then
		part:SetAttribute("BaseColor", color)
		return color
	end

	local maxComponent = math.max(color.R, color.G, color.B)
	local minTarget = 0.78
	local maxTarget = 0.8

	if maxComponent < minTarget then
		local scale = minTarget / maxComponent
		color = Color3.new(
			math.clamp(color.R * scale, 0, 1),
			math.clamp(color.G * scale, 0, 1),
			math.clamp(color.B * scale, 0, 1)
		)
	elseif maxComponent > maxTarget then
		local scale = maxTarget / maxComponent
		color = Color3.new(
			math.clamp(color.R * scale, 0, 1),
			math.clamp(color.G * scale, 0, 1),
			math.clamp(color.B * scale, 0, 1)
		)
	end

	part:SetAttribute("BaseColor", color)
	return color
end

-- Public: pcall retry function
local function pcallRetry(func: (...any) -> (...any), maxRetries: number, ...): (boolean, string?)
	-- mainly due to pool errors, better to try again instead of erroring the entire function
	local args = {...}
	local attempt = 0
	local success, result

	repeat
		attempt += 1
		success, result = pcall(func, table.unpack(args))
		if not success then
			debugger.warn("Warning", `pcallRetry: {result} | {maxRetries - attempt} attemps remaining`)
		end
	until success or attempt >= maxRetries

	if not success then
		debugger.warn("Warning", `pcallRetry: {result} All attempts exhausted.`)
	end

	return success, result
end

-- Public: determines if the provided Color3's are equal
local function areColorsEqual(colorA:Color3, colorB:Color3, epsilon: number)
	-- ^ needed since Color3's have floating points
	local epsilon = epsilon or 0.001

	if math.abs(colorA.R - colorB.R) > epsilon then
		return false
	end

	if math.abs(colorA.G - colorB.G) > epsilon then
		return false
	end

	if math.abs(colorA.B - colorB.B) > epsilon then
		return false
	end

	return true
end


return table.freeze({
	Name = "utils",
	deepMerge = deepMerge,
	trackAnsestryRemoval = trackAnsestryRemoval,
	configure = configure,
	getSpeedMPH = getSpeedMPH,
	adaptiveWait = adaptiveWait,
	adaptiveWaitWithSourcesOverride = adaptiveWaitWithSourcesOverride,
	getFastestDriveSeat = getFastestDriveSeat,
	fixPartOrientation = fixPartOrientation,
	normalizeBaseColor = normalizeBaseColor,
	pcallRetry = pcallRetry,
	areColorsEqual = areColorsEqual,
	validFaces = validFaces,
	renderWait = renderWait
})
