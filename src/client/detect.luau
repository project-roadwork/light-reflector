--!native
--!strict
-- USAGE: lightreflector/client/detect.luau
-- Detects parts and calculates light reflector behavior for Light Reflector.

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
const debugger: types.Debugger = require("../shared/debugger")
const config: types.Configuration = require("../shared/config")
const utils: types.Utils = require("./utils")
const dark: () -> boolean = require("./dark")
const equations: types.Equations = require("./equations")
const sources: types.SourcesModule = require("./sources")
const grid: types.GridModule = require("./grid")
const register: types.Register  = require("./register")
const states: types.StatesModule = require("./states")
const jecs: types.JecsModule = require("../shared/jecs")

-- IMPORTANT: Register Variables
const world: jecs.World, components: types.Components,
    _instancetoEntityId: {[Instance]: jecs.Entity},
	cachedQueries: types.CachedQueries = register.getWorldUtils()

const reflectorGrid: types.Grid = register.reflectorGrid
const signGrid: types.Grid = register.signGrid
const surfaceGuiPool: types.Pool<types.SurfaceGuiTemplate> = register.surfaceGuiPool
const activeReflectorEntities: { [jecs.Entity]: boolean } = {}

-- IMPORTANT: Configuration Variables
local baseConfig: types.BaseConfig = config.getConfig()
local constraints: types.Constraints = baseConfig.Constraints
local reflectorConfig: types.ReflectorConfig = baseConfig.ReflectorConfig
local signConfig: types.SignConfig = baseConfig.SignConfig

-- IMPORTANT: Module Public and Private Variables
local currentDetectedEntities: { [jecs.Entity]: boolean } = {}
local areStatesDeactivated: boolean = false
local _detectedEntitiesThisFrame: { [jecs.Entity]: boolean } = {}
local _runnerThread: thread?
local _frameId: number = 0
local hasInit: boolean = false
const min: (number, number) -> number = math.min

-- Miscellaneous
const clamp: (number, number, number) -> number = math.clamp

--[=[
	Private: Deactivates all states
	@private

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function _deactivateAllStates(): ()
	for entity: jecs.Entity<nil>, signState: types.SignEntity in cachedQueries.SignStates do
		if signState.partRenderMode == "SurfaceGui" then
			const state: types.SurfaceGuiState? = signState.surfaceGuiState

			if state then
				state.targetTransparency = 1
				state.targetBrightness = 0
				state.targetLightInfluence = 1
			end
		elseif signState.partRenderMode == "Decal" then
			const state: types.DecalState? = signState.decalState

			if state then
				state.targetBrightness = 0
			end
		end
	end

	for entity: jecs.Entity<nil>, part:BasePart, state: types.ReflectorState in cachedQueries.Reflectors do
		state.targetIntensity = 0
		state.isActive = false

		if state.baseColor then
			part.Color = state.baseColor
			part.Material = reflectorConfig.inactiveMaterial
		end
	end
end

--[=[
	Private: Processes a reflector
	@private

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function _processReflector(entity: jecs.Entity, source: types.LightSource, MPH: number)
	const part: BasePart? = world:get(entity, components.Reflector)

	if not part then
		debugger.warn("Entity is missing a Reflector component")
		return
	end

	activeReflectorEntities[entity] = true

	local state: types.ReflectorState? = world:get(entity, components.ReflectorState)

	if not state then
		state = states.acquireReflectorState(part, baseConfig, reflectorGrid)

		if not state then
		    return -- have to add this because of type checker thinking state is still nil
		end

		world:set(entity, components.ReflectorState, state)
	end

	if not state then
		return -- have to add this because of type checker
	end

	if state.lastFrame ~= _frameId then
        state.colorAccum = vector.zero
        state.intensityAccum = 0
        state.lastFrame = _frameId
    end

	if state.doesReflectorMove then
		const newCFrame: CFrame = part.CFrame

		const oldX: number, oldZ: number = state.cellKey[1], state.cellKey[2]
		const newX: number?, newZ: number? = grid.getCellKey(reflectorGrid, newCFrame.Position)

		if newX and newZ then
			if oldX ~= newX or oldZ ~= newZ then
				grid.remove(reflectorGrid, entity) -- old cell
				grid.spawn(reflectorGrid, entity, newCFrame.Position) -- new cell
				state.cellKey = {newX, newZ}
			end
		end

		state.CFrame = part.CFrame

		const slopeNormalWorld: Vector3? = if state.isWedge then part.CFrame:VectorToWorldSpace(Vector3.new(0,1,-1).Unit) else nil

		local faceNormalWorld: Vector3?
		if state.faceAttributeName and utils.validFaces[state.faceAttributeName] then
			faceNormalWorld = newCFrame:VectorToWorldSpace(Vector3.FromNormalId(Enum.NormalId[state.faceAttributeName]))
		end

		state.slopeNormalWorld = slopeNormalWorld
		state.faceNormalWorld = faceNormalWorld
	end

	const intensity: number, transparency: number = equations.computeReflectorIntensity(part, state, source, MPH, baseConfig)

	const color: vector = source.getColor(source.Owner)

	state.colorAccum += color * intensity
	state.intensityAccum += intensity

	if transparency < 0 then
		return
	end -- A negative number would mean that the function returned mid-way because the source was not facing the reflector

	state.targetIntensity += intensity
	if state.isHybrid then
		state.targetTransparency = min(state.targetTransparency, transparency)
	end

    if state.intensityAccum > 0 then
        const avg: vector = state.colorAccum / state.intensityAccum
        state.neutralizedColor = Color3.new(avg.x, avg.y, avg.z)
    else
        state.neutralizedColor = state.baseColor
    end
end

--[=[
	Private: Processes a sign
	@private

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function _processSign(entity: jecs.Entity, source: types.LightSource)
	const part: Instance? = world:get(entity, components.Sign)

	if not part then
		return
	end

	if not part:IsA("BasePart") then
		debugger.warn("Warning", `[Detect] Entity: {entity} | Sign part {part.Name} at {part:GetFullName()} is NOT a BasePart`)
		return
	end

	local finalTransparency: number = 1
	local finalBrightness: number = 0
	local finalLightInfluence: number = 1

	local signState: types.SignEntity? = world:get(entity, components.SignState)

	if not signState then
		signState = states.acquireSignState(part, baseConfig)

		if signState.partRenderMode == "Decal" and part.Material == Enum.Material.Metal then
            debugger.warn("Warning", `[Detect] ⚠️ Sign "{part.Name}" at {part:GetFullName()} has the decal renderer enabled, but the sign's material is METAL. The decal renderer will NOT work properly with the METAL material. Unless this is intentional, please change the sign's material to a different material like Plastic. Please note that you only need to change the material of the part that the decal is parented to.`)
		end

		world:set(entity, components.SignState, signState)
	end

	if not signState then
		return -- have to add this because of type checker
	end

	if signState.doesSignMove then
		const newCFrame: CFrame = part.CFrame

		const oldX: number, oldZ: number = signState.cellKey[1], signState.cellKey[2]
		const newX: number?, newZ: number? = grid.getCellKey(signGrid, newCFrame.Position)

		if newX and newZ then
			if oldX ~= newX or oldZ ~= newZ then
				grid.remove(signGrid, entity) -- old cell
				grid.spawn(signGrid, entity, newCFrame.Position) -- new cell
				signState.cellKey = {newX, newZ}
			end
		end

		signState.CFrame = newCFrame
		signState.Size = part.Size
	end

	local mainDecal: Decal? = signState.mainDecal

	if not mainDecal then
	    const name: string = signConfig.mainDecalName

		const found: Instance? = part:FindFirstChild(name)

		mainDecal = if found and found:IsA("Decal") then found else nil
		-- ^ unfortunately one cannot set instances as attributes
		if not mainDecal then
			for _:number, decal:Instance in part:GetChildren() do
				if decal:IsA("Decal") then
					if signConfig.isMainDecal(decal) then
						mainDecal = decal
						decal.Name = name
						break
					end
				end
			end
		end

		signState.mainDecal = mainDecal
	end

	if not mainDecal then return end

	const isRenderModeSurfaceGui: boolean = signState.partRenderMode == "SurfaceGui"

	-- 2.2.0 patch: add this if-statement immediately before `.computeSignIntensity()` is called, or else it would have the wrong CFrames and size
	if isRenderModeSurfaceGui then
		if part:GetAttribute("IsFixed") ~= true then
			utils.fixPartOrientation(part, mainDecal)
			signState.CFrame = part.CFrame
			signState.Size = part.Size
		end
	end

	const signData: {brightness: number, lightInfluence: number, transparency: number, hasActiveLight: boolean} = equations.computeSignIntensity(part, signState, source, mainDecal, "near", baseConfig)

	if signData.transparency < 0 then
		return
	end

	if signData.hasActiveLight then
		finalTransparency = min(finalTransparency, signData.transparency)
		finalBrightness += signData.brightness
		finalLightInfluence = min(finalLightInfluence, signData.lightInfluence)

		const color: vector = source.getColor(source.Owner)

        signState.colorAccum += color * signData.brightness
        signState.intensityAccum += signData.brightness
	else
		finalTransparency = 1
		finalBrightness = 0
		finalLightInfluence = 1
	end

	finalTransparency = clamp(finalTransparency  , 0, 1)
	finalBrightness   = clamp(finalBrightness * signState.baseIntensity , 0, 5)
	finalLightInfluence = clamp(finalLightInfluence   , 0, 1)

	if finalTransparency >= signConfig.inactiveTransparencyThreshold  then
		return
	end

	if isRenderModeSurfaceGui then
		local state: types.SurfaceGuiState? = signState.surfaceGuiState

		if not state then
			state = states.acquireSurfaceGuiState()
			signState.surfaceGuiState = state
		end

		if not state then return end -- have to add this due to type weird errors

		local gui: types.SurfaceGuiTemplate? = state.gui

		if not gui then
			gui = surfaceGuiPool:GetObject()

			if gui == nil then
			    debugger.warn("Warning", "Pool contains nil instances.")
			    return
			end

			gui.Face = mainDecal.Face
			gui.Adornee = part
			gui.Parent = part
			gui.Enabled = true
			gui.ImageLabel.Image = mainDecal.Texture
			gui.ImageLabel.ImageTransparency = mainDecal.Transparency
			state.gui = gui
		end

		if gui and gui.Parent == nil then
			gui.Face = mainDecal.Face
			gui.Parent = part
			gui.Adornee = part
			gui.Enabled = true
			gui.ImageLabel.Image = mainDecal.Texture
			gui.ImageLabel.ImageTransparency = mainDecal.Transparency
		end

		state.targetTransparency = finalTransparency
		state.targetBrightness = finalBrightness
		state.targetLightInfluence = finalLightInfluence

		_detectedEntitiesThisFrame[entity] = true
	end

	if signState.partRenderMode == "Decal" then
		local state: types.DecalState? = signState.decalState

		if not state then
			local baseColor: Color3 = Color3.fromRGB(255, 255, 255)
			const attribute: Color3? = mainDecal:GetAttribute("BaseColor")

			if attribute then
				baseColor = attribute
			else
				baseColor = mainDecal.Color3
				mainDecal:SetAttribute("BaseColor", baseColor)
			end

			state = states.acquireDecalState()
			state.baseColor = baseColor
			signState.decalState = state
		end

		if not state then return end -- have to add this line again due to type errors

		state.targetBrightness = finalBrightness - (finalTransparency * 2)

		_detectedEntitiesThisFrame[entity] = true
	end

	if signState.intensityAccum > 0 then
        const avg: vector = signState.colorAccum / signState.intensityAccum
        signState.neutralizedColor = Color3.new(avg.x, avg.y, avg.z)
    end
end

--[=[
	Public: Initializes the detection module

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function init(): ()
	if hasInit then
		return
	end

	config.onChange(function(NEW_CONFIG: types.BASE_CONFIG)
		baseConfig = NEW_CONFIG
		constraints = NEW_CONFIG.Constraints
		reflectorConfig = NEW_CONFIG.ReflectorConfig
		signConfig = NEW_CONFIG.SignConfig
	end)

	equations.buildSamplePoints(constraints.OCCLUSION_RAYCAST_QUALITY)

	hasInit = true
end

--[=[
	Public: Starts zone detection/boundary loop

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function start() : ()
	_runnerThread = constraints.SPAWN(utils.pcallRetry, function()
		-- Start config tracking
		while true do

			const deltaTime: number, MPH: number = utils.adaptiveWaitWithSourcesOverride(task.wait, constraints.BOUNDARY_MIN_FPS,
				constraints.BOUNDARY_MAX_FPS, utils.getFastestDriveSeat(cachedQueries.VehicleInstances))
			-- task.wait uses .Heartbeat if I remember correctly, so I don't need a separate module
			-- ^ adaptive waiting based on vehicle speed. This only indexes parts in the area rather than renders,
			--    so the FPS numbers should be low

			-- This loop SHOULD run slower than the `runRenderLoop()`

			table.clear(_detectedEntitiesThisFrame)
			table.clear(activeReflectorEntities)

			const debugBoxTemplate: BasePart = register.debugBoxTemplate

			if not sources.anyActive() or not dark() then
				if debugBoxTemplate then
					debugBoxTemplate.Transparency = 0.95
				end

				if areStatesDeactivated ~= true then
					_deactivateAllStates()
					areStatesDeactivated = true
				end
				continue
			end

			areStatesDeactivated = false

			if constraints.IS_RAYCAST_INDEXING_ENABLED then
				register.getPartsByRaycast()
			end

			const activeSources: {types.LightSource} = sources.getAllActive()

			if reflectorConfig.isEnabled then
				for entity: jecs.Entity<nil>, state: types.ReflectorState in cachedQueries.ReflectorStates do

					if state then
						if state.targetIntensity ~= 0 then
							state.targetIntensity = 0
						end

						if state.targetTransparency ~= 1 then
							state.targetTransparency = 1
						end

		                if not activeReflectorEntities[entity] then
							state.colorAccum = vector.zero
                            state.intensityAccum = 0
                            state.neutralizedColor = state.baseColor
						end
					end
				end
			end

			for _: number, source: types.LightSource in activeSources do
				const pos: Vector3 = source.getPosition()

				if reflectorConfig.isEnabled then
					const nearbyReflectors: {jecs.Entity<nil>}? = grid.query(reflectorGrid, pos)

					if not nearbyReflectors then
						continue
					end

					for i = 1, #nearbyReflectors do
						const entity: jecs.Entity<nil> = nearbyReflectors[i]

						if not entity then
							continue
						end

						_processReflector(entity, source, MPH)
					end
				end

				if signConfig.isEnabled then
					const nearbySigns: {jecs.Entity<nil>}? = grid.query(signGrid, pos)

					if not nearbySigns then
						continue
					end

					for i = 1, #nearbySigns do
						const entity: jecs.Entity<nil> = nearbySigns[i]

						if not entity then
							continue
						end

						_processSign(entity, source)
					end
				end
			end

			if signConfig.isEnabled then
				for entity: jecs.Entity<nil>, signState: types.SignEntity in cachedQueries.SignStates do
					if not signState then
						continue
					end

	                if not _detectedEntitiesThisFrame[entity] then
                        signState.colorAccum = vector.zero
                        signState.intensityAccum = 0
                        signState.neutralizedColor = Color3.fromRGB(255,255,255)
                    end

					const surfaceGuiState: types.SurfaceGuiState? = signState.surfaceGuiState

					if surfaceGuiState and surfaceGuiState.isPendingRemoval and surfaceGuiState.gui then
						utils.resetSurfaceGui(surfaceGuiPool, surfaceGuiState.gui)

						surfaceGuiState.gui = nil
						signState.surfaceGuiState = nil
						signState.mainDecal = nil
					end
				end
			end

			local _tempDetectedEntities = currentDetectedEntities
			currentDetectedEntities = _detectedEntitiesThisFrame
			_detectedEntitiesThisFrame = _tempDetectedEntities
		end
	end, constraints.MAX_PCALL_RETRIES)
end

--[=[
	Public: Gets the current detected parts

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function getDetectedEntities(): {[jecs.Entity]: boolean}
	return currentDetectedEntities
end

--[=[
	Public: Safe cancels the runner thread

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function safeCancelThread(): (boolean, string? | any)
	if not _runnerThread then
		return false, "There is no running thread"
	end

	if typeof(_runnerThread) ~= "thread" then
		return false, "Runner thread is not a thread"
	end

	const threadToCancel: thread = _runnerThread -- have to add this due to pcall issues

	const success: boolean, result: string? | any = pcall(function() -- pcall typing is broken, cannot fix
		task.cancel(threadToCancel)
	end)

	return success, result
end

--[=[
	Public: Clears detector tables

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function reset(): ()
	table.clear(activeReflectorEntities)
	table.clear(currentDetectedEntities)
end

-- Return public API
return table.freeze({
	name = "detect",
	currentDetectedEntities = currentDetectedEntities,
	activeReflectorEntities = activeReflectorEntities,
	init = init,
	start = start,
	reset = reset,
	getDetectedEntities = getDetectedEntities,
	safeCancelThread = safeCancelThread
})
