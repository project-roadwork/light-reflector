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
const RunService:RunService = game:GetService("RunService")
const ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")

-- Types module
const types: {} = require("../shared/types")

-- Debugger
const debugger: types.Debugger = require("../shared/debugger")

-- Sources
const sources: types.SourcesModule = require("./sources")

-- Configuration
const config: types.Configuration = require("../shared/config")

-- Pool
const pool: types.PoolModule = require("./pool")

-- Valid faces for Enum.NormalId
const validFaces: { [string]: boolean }  =  {
	Top = true,
	Bottom = true,
	Left = true,
	Right = true,
	Front = true,
	Back = true
}

-- Private Variables
const _PreRender: RBXScriptSignal = RunService.PreRender
const _INV_50: number = 1 / 50
const _MPH_SCALE: number = config.getConfig().Constraints.MPH_SCALE

local _lastSources: {types.LightSource} = sources.getAllActive()
local _sourcesCheckEnabled: boolean = false
local _currentSources: {types.LightSource} = _lastSources

-- Functions
--[=[
	Public: Waits via RunService._PreRender rather than RunService.Heartbeat

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function renderWait(waitTime: number?): number
	if waitTime ~= nil then
		local total:number = 0

		while total < waitTime do
			total += _PreRender.Wait(_PreRender) -- I think .Function(self) (explicit) is faster than :Function() (implicit)?
		end

		return total
	else
		return _PreRender.Wait(_PreRender)
	end
end

--[=[
	Public: Tracks a part and calls a callback if it leaves workspace

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function trackAnsestryRemoval(instance: Instance, callback: (Instance) -> ()): RBXScriptConnection
	debugger.assert(typeof(instance) == "Instance", "onRemovedFromWorkspace: 'instance' must be a Roblox Instance")
	debugger.assert(typeof(callback) == "function", "onRemovedFromWorkspace: 'callback' must be a function")

	if instance.Parent == nil or not instance:IsDescendantOf(workspace) then
		pcall(callback, instance) -- no yield
	end

	local conn: RBXScriptConnection
	conn = instance.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			conn:Disconnect()
			pcall(callback, instance)
			return
		end

		if not instance:IsDescendantOf(workspace) then
			pcall(callback, instance)
			conn:Disconnect()
		end
	end)

	return conn
end

--[=[
	Public: Gets speed in MPH via respective MPH scale

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function getSpeedMPH(DriveSeat: VehicleSeat): number
	const v: Vector3 = DriveSeat.AssemblyLinearVelocity
	-- converts studs to MPH based on the mphScale config

	return (v.X*v.X + v.Y*v.Y + v.Z*v.Z)^0.5 * _MPH_SCALE -- maybe faster than .Magnitude?
end

--[=[
	Public: Adaptive wait time based on vehicle speed

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function adaptiveWait(waitFunction: (number?) -> number, minFPS: number, maxFPS: number, DriveSeat: VehicleSeat?): (number, number)
	-- faster VehicleSeat velocity = more FPS and vice versa
	if not DriveSeat then
		return waitFunction(1 / maxFPS), 50
	end

	const speedMph: number = getSpeedMPH(DriveSeat)

	const targetFPS: number = math.clamp(speedMph * _INV_50 * maxFPS, minFPS, maxFPS)

	return waitFunction(1 / targetFPS), speedMph
end

--[=[
	Public: Gets the fastest VehicleSeat in a vehicle map table

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function getFastestDriveSeat(Vehicles: types.VehicleMap): VehicleSeat?
	-- ^ since the package is no longer tailored towards one vehicle, it needs to get the fastest drive seat out of all of the
	--    vehicles
	local fastestSeat: VehicleSeat? = nil
	local maxSpeed: number = 0

	for car: Instance?, _ in Vehicles do

		if not car then continue end

		const seat: VehicleSeat? = car:FindFirstChildOfClass("VehicleSeat")
		if seat then
			const speed: number = seat.AssemblyLinearVelocity.Magnitude
			if speed > maxSpeed then
				maxSpeed = speed
				fastestSeat = seat
			end
		end
	end

	return fastestSeat
end

--[=[
	Private: Starts separate sources check in 1/15 seconds

	@private
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function _startSeparateSourcesCheck(): ()
	if _sourcesCheckEnabled then
		return
	end

	_sourcesCheckEnabled = true

	while true do
		const updatedSources: {types.LightSource} = sources.getAllActive()
		local changed: boolean = false

		if #updatedSources ~= #_currentSources then
			changed = true
		else
			for i = 1, #updatedSources do
				if updatedSources[i] ~= _currentSources[i] then
					changed = true
					break
				end
			end
		end

		if changed then
			_currentSources = updatedSources
		end

		task.wait(1/15)
	end

end

--[=[
	Public: Adaptive wait with override if sources change

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function adaptiveWaitWithSourcesOverride(
	waitFunction: (number?) -> number,
	minFPS: number,
	maxFPS: number,
	DriveSeat: VehicleSeat?
	--onSourcesChanged: (types.SourceList) -> ()
): (number, number)

	task.defer(_startSeparateSourcesCheck)

	local elapsed: number, speedMph: number = task.wait(1/59), 0

	local changed: boolean = false
	if #_currentSources ~= #_lastSources then
		changed = true
	else
		for i = 1, #_currentSources do
			if _currentSources[i] ~= _lastSources[i] then
				changed = true
				break
			end
		end
	end

	if changed then
		--elapsed = waitFunction(0)
		speedMph = if DriveSeat then getSpeedMPH(DriveSeat) else 50
		_lastSources = _currentSources
	else
		elapsed, speedMph = adaptiveWait(waitFunction, minFPS, maxFPS, DriveSeat)
	end

	return elapsed, speedMph
end

--[=[
	Public: Fixes the orientation of a sign part

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function fixPartOrientation(part: BasePart, decal: Decal): ()
	-- ^ this function is needed since the top face in Decals and SurfaceGuis are NOT in the same orientation
	const isFixed: boolean? = part:GetAttribute("IsFixed")
	if isFixed == true then return end

	if decal.Face == Enum.NormalId.Top then

		part.CFrame *= CFrame.Angles(0, math.rad(-90), math.rad(-90))

		const size = part.Size
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

--[=[
	Public: Normalizes the base color of a part if it is too low or too high

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function normalizeBaseColor(part: BasePart, isNormalizeEnabled: boolean): Color3
	-- if a reflector color is too low, it would barely light up at all. If it is too high, it would blind one's eyes
	local color: Color3 = part.Color

	if part:GetAttribute("BaseColor") then return color end

	if isNormalizeEnabled == false then
		part:SetAttribute("BaseColor", color)
		return color
	end

	const maxComponent: number = math.max(color.R, color.G, color.B)
	const minTarget: number = 0.78
	const maxTarget: number = 0.8

	if maxComponent < minTarget then
		const scale: number = minTarget / maxComponent
		color = Color3.new(
			math.clamp(color.R * scale, 0, 1),
			math.clamp(color.G * scale, 0, 1),
			math.clamp(color.B * scale, 0, 1)
		)
	elseif maxComponent > maxTarget then
		const scale: number = maxTarget / maxComponent
		color = Color3.new(
			math.clamp(color.R * scale, 0, 1),
			math.clamp(color.G * scale, 0, 1),
			math.clamp(color.B * scale, 0, 1)
		)
	end

	part:SetAttribute("BaseColor", color)
	return color
end

--[=[
	Public: Pcall retry function

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function pcallRetry(func: (...any) -> (...any), maxRetries: number, ...): (boolean, string?)
	-- mainly due to pool errors, better to try again instead of erroring the entire function
	const args: {any} = {...}

	local attempt: number = 0
	local success: boolean, result: string?

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

--[=[
	Public: Determines if the provided Color3's are equal

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function areColorsEqual(colorA: Color3, colorB: Color3, epsilon: number): boolean
	-- ^ needed since Color3's have floating points
	epsilon = if epsilon then epsilon else 0.001

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

--[=[
	Public: Resets and returns SurfaceGui with pool check

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function resetSurfaceGui(SurfaceGuiPool: types.Pool, gui: types.SurfaceGuiTemplate): ()
	if not gui then return end

	--if gui:GetAttribute("InPool") == true then return end

	if gui.Parent == nil and gui.Enabled == false then
		return
	end

	gui.Enabled = false
	gui.Adornee = nil
	gui.Parent = nil

	gui.Brightness = 0
	gui.LightInfluence = 1
	gui.ImageLabel.ImageTransparency = 1
	-- ^ reset the template so that signs do not flicker once indexed

	--gui:SetAttribute("InPool", true) -- InPool attribute is unreliable

	const success:boolean, response:string? = SurfaceGuiPool:ReturnObject(gui)
	-- in the pool module, I made it so that :ReturnObject has similar returns as a pcall

	if not success then
		gui:Destroy() -- destroy the gui instead
		debugger.warn("Warning", response)
	end
end

--[=[
	Public: Initializes and returns the SurfaceGui pool

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function initPool(): types.Pool
	const config = config.getConfig()

	local surfaceGuiTemplate:Instance? = ReplicatedStorage:FindFirstChild("ReflectorTemplate")

	if not surfaceGuiTemplate then
		debugger.warn("InitWarning","SurfaceGui template does not exist! Using safety net and creating SurfaceGui template...")
		surfaceGuiTemplate = Instance.new("Folder")
		surfaceGuiTemplate.Name = "ReflectorTemplate"
		surfaceGuiTemplate.Parent = ReplicatedStorage
	end

	local templateGui: SurfaceGui? = if surfaceGuiTemplate then surfaceGuiTemplate:FindFirstChildOfClass("SurfaceGui") else nil -- forced to do this or else the type solver would get into a panick attack

	if not templateGui then
		debugger.warn("InitWarning","SurfaceGui does not exist in the template! Using safety net and creating SurfaceGui...")

		const surfaceGui:SurfaceGui = Instance.new("SurfaceGui")
		surfaceGui.Name = "SurfaceGui"
		surfaceGui.Brightness = 0
		surfaceGui.LightInfluence = 1
		surfaceGui.ZOffset = 3

		const imageLabel:ImageLabel = Instance.new("ImageLabel")
		imageLabel.Size = UDim2.fromScale(1,1)
		imageLabel.BackgroundTransparency = 1
		imageLabel.ImageTransparency = 1
		imageLabel.Parent = surfaceGui

		surfaceGui.Parent = surfaceGuiTemplate
		templateGui = surfaceGui
	end

	return pool.new(templateGui::SurfaceGui,
		function(template: Instance): Instance
			const clone = template:Clone()
			return clone
		end,

		function(template: Instance)

		end, config.Constraints.SURFACE_GUI_MIN_POOL_SIZE, config.Constraints.SURFACE_GUI_MAX_POOL_SIZE) -- pool will warn ONCE if active parts exceed 350
end

-- Return public variables and API
return table.freeze({
	Name = "utils",
	trackAnsestryRemoval = trackAnsestryRemoval,
	getSpeedMPH = getSpeedMPH,
	adaptiveWait = adaptiveWait,
	adaptiveWaitWithSourcesOverride = adaptiveWaitWithSourcesOverride,
	getFastestDriveSeat = getFastestDriveSeat,
	fixPartOrientation = fixPartOrientation,
	normalizeBaseColor = normalizeBaseColor,
	pcallRetry = pcallRetry,
	areColorsEqual = areColorsEqual,
	validFaces = validFaces,
	renderWait = renderWait,
	resetSurfaceGui = resetSurfaceGui,
	initPool = initPool,
}) :: types.Utils
