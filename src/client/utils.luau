--!native
--!strict
-- USAGE: lightreflector/client/utils.luau
-- Utilities for Light Reflector

--[[
    SPDX-FileCopyrightText: 2025-2026 Illinois_Roadbuff (Rogue Jr) <illinois_roadbuff@proton.me>
    SPDX-FileCopyrightText: 2025-2026 Project Roadwork and Contributors

    SPDX-License-Identifier: MPL-2.0

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at https://mozilla.org/MPL/2.0/.

]]

-- IMPORTANT: Services
const RunService:RunService = game:GetService("RunService")
const ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
const Debris: Debris = game:GetService("Debris")

-- IMPORTANT: Modules
const types = require("../shared/types")
const jecs: types.JecsModule = require("../shared/jecs")
const debugger: types.Debugger = require("../shared/debugger")
const sources: types.SourcesModule = require("./sources")
const config: types.Configuration = require("../shared/config")
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

-- Configuration Values
local baseConfig: types.BaseConfig = config.getConfig()
local constraints: types.Constraints = baseConfig.Constraints
local isConfigTracked: boolean = false

-- Private Variables
const _PreRender: RBXScriptSignal = RunService.PreRender
const _INV: number = 1 / config.getConfig().Constraints.MAX_MPH
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
	Private: Printing function for `trackAncestryRemoval`
	@private

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function _trackAncestryRemovalPrint(message: string): ()
	if config.FLAGS.TRACK_ANCESTRY_CONNECTIONS then
		print(`:: TrackAncestryRemoval :: {message}`) -- using luau print
	end
end

--[=[
	Public: Tracks a part and calls a callback if it leaves workspace or game

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function trackAncestryRemoval(instance: Instance, callback: (Instance) -> ()): RBXScriptConnection
    const BOUNDS: Instance = constraints.BOUNDS

	if instance.Parent == nil or not instance:IsDescendantOf(BOUNDS) then
		pcall(callback, instance) -- no yield
	end

	local conn: RBXScriptConnection
	conn = instance.AncestryChanged:Connect(function(_, parent)
		if parent == nil then
			conn:Disconnect()
			pcall(callback, instance)
			_trackAncestryRemovalPrint("[🔴 REMOVE] Disconnected via AncestryChanged connection")
			return
		end

		if not instance:IsDescendantOf(BOUNDS) then
			pcall(callback, instance)
			conn:Disconnect()
			_trackAncestryRemovalPrint("[🔴 REMOVE] Disconnected via IsDescendantOf check")
			return
		end
	end)

	_trackAncestryRemovalPrint("[🟢 ADD] New connection added!")

	return conn
end

--[=[
	Public: Gets speed in MPH via respective MPH scale

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function getSpeedMPH(source: BasePart): number
	const v: Vector3 = source.AssemblyLinearVelocity
	-- converts studs to MPH based on the mphScale config

	return (v.X*v.X + v.Y*v.Y + v.Z*v.Z)^0.5 * _MPH_SCALE -- maybe faster than .Magnitude?
end

--[=[
	Public: Adaptive wait time based on vehicle speed

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function adaptiveWait(waitFunction: (number?) -> number, minFPS: number, maxFPS: number, source: BasePart?): (number, number)
	-- faster VehicleSeat velocity = more FPS and vice versa
	if not source then
		return waitFunction(1 / maxFPS), 50
	end

	const speedMph: number = getSpeedMPH(source)

	const targetFPS: number = math.clamp(speedMph * _INV * maxFPS, minFPS, maxFPS)

	return waitFunction(1 / targetFPS), speedMph
end

--[=[
	Public: Gets the fastest VehicleSeat in a vehicle map table

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function getFastestSource(sources: jecs.Cached_Query<BasePart>): BasePart?
	-- ^ since the package is no longer tailored towards one vehicle, it needs to get the fastest drive seat out of all of the
	--    vehicles
	local fastestSource: BasePart? = nil
	local maxSpeed: number = 0

	for entity, source: BasePart in sources do

		if not source then continue end

		const speed: number = source.AssemblyLinearVelocity.Magnitude
		if speed > maxSpeed then
			maxSpeed = speed
			fastestSource = source
		end
	end

	return fastestSource
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
	source: BasePart?
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
		speedMph = if source then getSpeedMPH(source) else 50
		_lastSources = _currentSources
	else
		elapsed, speedMph = adaptiveWait(waitFunction, minFPS, maxFPS, source)
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
	const existing: any? = part:GetAttribute("BaseColor")
	if typeof(existing) == "Color3" then
		return existing
	end

	local color: Color3 = part.Color

	if not isNormalizeEnabled then
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
	part:SetAttribute("OrigColor", part.Color)
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

	if config.FLAGS.PCALL then
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
	else
		local result = func(table.unpack(args))

		return true, result
	end
end

--[=[
	Public: Determines if the provided Color3's are equal

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function areColorsEqual(colorA: Color3, colorB: Color3, epsilon: number?): boolean
	epsilon = epsilon or 0.005

	const aR: number, aG: number, aB: number = colorA.R, colorA.G, colorA.B
	const bR: number, bG: number, bB: number = colorB.R, colorB.G, colorB.B

	local d: number = aR - bR
	if d > epsilon or d < -epsilon then return false end

	d = aG - bG
	if d > epsilon or d < -epsilon then return false end

	d = aB - bB
	if d > epsilon or d < -epsilon then return false end

	return true
end

--[=[
	Public: Resets and returns SurfaceGui with pool check

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function resetSurfaceGui(SurfaceGuiPool: types.Pool<types.SurfaceGuiTemplate>, gui: types.SurfaceGuiTemplate): ()
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
	Private: Builds a cone basis for a given forward vector
	@private

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function _buildBasis(forward: Vector3): (Vector3, Vector3, Vector3)
	const up: Vector3 = math.abs(forward:Dot(Vector3.yAxis)) > 0.95
		and Vector3.xAxis
		or Vector3.yAxis

	const right: Vector3 = forward:Cross(up).Unit
	const correctedUp: Vector3 = right:Cross(forward).Unit

	return right, correctedUp, forward.Unit
end

--[=[
	Private: Generates a random Vector3 within a unit radius
	@private

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function _randomConeVector(forward: Vector3, cosAngle: number): Vector3
	const u: number = math.random()
	const v: number   = math.random()

	const theta = 2 * math.pi * u

	const z: number  = v * (1 - cosAngle) + cosAngle
	const sinT: number  = math.sqrt(1 - z * z)

	const x: number  = sinT * math.cos(theta)
	const y: number  = sinT * math.sin(theta)

	const right: Vector3, up: Vector3, fwd: Vector3 = _buildBasis(forward)

	return (right * x + up * y + fwd * z).Unit
end

--[=[
	Private: Checks if a direction is within a cone
	@private

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function _isInCone(dir: Vector3, forward: Vector3, cosAngle: number): boolean
	return dir:Dot(forward) >= cosAngle
end

--[=[
	Public: Spawns a debug field

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function spawnDebugField(origin: Vector3, forward: Vector3, maxDot: number, radius: number, count: number, debugFolder: Instance): ()
	for i: number = 1, count do
		const dir: Vector3 = _randomConeVector(forward, maxDot)

		const worldPos: Vector3 = origin + dir * radius

		const dot: number = forward:Dot(dir)

		const p: Part = Instance.new("Part")
		p.Anchored = true
		p.CanCollide = false
		p.Material = Enum.Material.Neon

		const t: number = math.clamp((dot - maxDot) / (1 - maxDot), 0, 1)

		p.Color = Color3.new(
			1 - t, -- red = edge/back
			t,     -- green = forward cone
			0
		)

		p.Size = Vector3.new(0.15, 0.15, 0.15)
		p.Position = worldPos
		p.Parent = debugFolder

		Debris:AddItem(p, 5)
		-- ^ May be more performance friendly to use an alternative to DebrisService, but this is only for debug purposes.
	end
end

--[=[
	Public: Initializes and returns the SurfaceGui pool

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function initPool(): types.Pool<types.SurfaceGuiTemplate>
	local surfaceGuiTemplate:Instance? = ReplicatedStorage:FindFirstChild("ReflectorTemplate")

	if not surfaceGuiTemplate then
		surfaceGuiTemplate = Instance.new("Folder")
		surfaceGuiTemplate.Name = "ReflectorTemplate"
		surfaceGuiTemplate.Parent = ReplicatedStorage
	end

	local templateGui: SurfaceGui? = if surfaceGuiTemplate then surfaceGuiTemplate:FindFirstChildOfClass("SurfaceGui") else nil -- forced to do this or else the type solver would get into a panick attack

	if not templateGui then
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

	return pool.new(templateGui::types.SurfaceGuiTemplate,
		function(template: Instance): Instance
			const clone = template:Clone()
			return clone
		end,

		function(template: Instance)

		end, constraints.SURFACE_GUI_MIN_POOL_SIZE, constraints.SURFACE_GUI_MAX_POOL_SIZE) -- pool will warn ONCE if active parts exceed 350
end

-- Start config tracking
config.waitForLock(function(): ()
	if isConfigTracked == false then
		config.onChange(function(NEW_CONFIG: types.BASE_CONFIG)
			baseConfig = NEW_CONFIG
			constraints = NEW_CONFIG.Constraints
		end)
		isConfigTracked = true
	end
end)
--^ I will not be making a "start"/"init" function for a utilities module

-- Return public variables and API
return table.freeze({
	name = "utils",
	trackAncestryRemoval = trackAncestryRemoval,
	getSpeedMPH = getSpeedMPH,
	adaptiveWait = adaptiveWait,
	adaptiveWaitWithSourcesOverride = adaptiveWaitWithSourcesOverride,
	getFastestSource = getFastestSource,
	fixPartOrientation = fixPartOrientation,
	normalizeBaseColor = normalizeBaseColor,
	pcallRetry = pcallRetry,
	areColorsEqual = areColorsEqual,
	validFaces = validFaces,
	renderWait = renderWait,
	spawnDebugField = spawnDebugField,
	resetSurfaceGui = resetSurfaceGui,
	initPool = initPool,
})
