--!native
--!strict
-- USAGE: lightreflector/client/detect.luau
-- Detects parts and calculates light reflector behavior for Light Reflector.

--[[
    SPDX-FileCopyrightText: 2025-2026 Illinois_Roadbuff <illinois_roadbuff@proton.me>
    SPDX-FileCopyrightText: 2025-2026 Project Roadwork and Contributors

    SPDX-License-Identifier: MPL-2.0

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at https://mozilla.org/MPL/2.0/.

]]

-- IMPORTANT: Services
const ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
const CollectionService: CollectionService = game:GetService("CollectionService")

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
const jecs: types.JecsModule = require("../shared/jecs")
const constraints = config.getConfig().Constraints

-- IMPORTANT: Register Variables
const world: jecs.World,
	components: types.Components,
	instancetoEntityId: {[Instance]: jecs.Entity},
	cachedQueries: types.CachedQueries = register.getWorldUtils()

const reflectorGrid: types.Grid = register.reflectorGrid
const surfaceGuiPool: types.Pool = register.surfaceGuiPool
const scriptConnections: { [RBXScriptConnection]: boolean } = register.scriptConnections
const activeReflectorEntities: { [jecs.Entity]: boolean } = {}

-- IMPORTANT: Module Public and Private Variables
local currentDetectedParts: { [BasePart]: boolean } = {}
local _detectedPartsThisFrame: { [BasePart]: boolean } = {}
local _runnerThread: thread?

--[=[
	Public: Starts zone detection/boundary loop

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function start() : ()
	const baseConfig: types.BaseConfig = config.getConfig()

	const constraints: types.Constraints = baseConfig.Constraints
	const reflectorConfig: types.ReflectorConfig = baseConfig.ReflectorConfig
	const generalConfig: types.GeneralConfig = baseConfig.General
	const signConfig: types.SignConfig = baseConfig.SignConfig

	_runnerThread = constraints.SPAWN(utils.pcallRetry, function()

	const debugBoxTemplate: BasePart = register.debugBoxTemplate
		-- pcall replaced with pcallRetry used in the Start function
		--	local partsDictionary: {[BasePart]: types.RangeType}

	--	if not constraints.IS_RAYCAST_ENABLED then
		--	partsDictionary = {} -- no longer rneeded b/c of Jecs
			-- OLD REFERENCE: partsDictionary = registeredSigns
			-- ^ Cacheparts is a weak table, so probably better to clone everything to create an interm (temp) strong ref?
		--end

		while true do
			const deltaTime: number, MPH: number = utils.adaptiveWaitWithSourcesOverride(task.wait, constraints.BOUNDARY_MIN_FPS,
				constraints.BOUNDARY_MAX_FPS, utils.getFastestDriveSeat(cachedQueries.Vehicles))
			-- task.wait uses .Heartbeat if I remember correctly, so I don't need a separate module
			-- ^ adaptive waiting based on vehicle speed. This only indexes parts in the area rather than renders,
			--    so the FPS numbers should be low

			-- This loop SHOULD run slower than the `runRenderLoop()`
			table.clear(_detectedPartsThisFrame)
			table.clear(activeReflectorEntities)

			--for entity in world:query(components.Reflector):with(components.ActiveReflector) do
			--	world:remove(entity, components.ActiveReflector)
			--end

			const isSourceActive: boolean = sources.anyActive()
			const isDark: boolean = dark()

			--if constraints.IS_RAYCAST_ENABLED == false then
			--	table.clear(partsDictionary)
			--	for part: BasePart, range: types.RangeType in registeredSigns do
			--		partsDictionary[part] = range
			--	end

			if constraints.IS_RAYCAST_ENABLED then
				register.getPartsByRaycast()
			end

			if not isSourceActive or not isDark then
				if debugBoxTemplate then debugBoxTemplate.Transparency = 0.95 end

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
				--	state.currentIntensity = 0
					state.targetIntensity = 0
					state.isActive = false

					if state.baseColor then
						part.Color = state.baseColor
						part.Material = reflectorConfig.inactiveMaterial
					end
				end

				if not isDark then
				--	task.wait(15)
				end

				continue
			end

			const activeSources: {types.LightSource} = sources.getAllActive()

			if reflectorConfig.isEnabled then
				--	grid.clear()

				for entity: jecs.Entity<nil>, state: types.ReflectorState in cachedQueries.ReflectorStates do
					--const state: types.ReflectorState = reflectorStatesByPart[part]
					if state then
						state.targetIntensity = 0
						state.targetTransparency = 1
					end


				end

				for _: number, source: types.LightSource in activeSources do
					const pos: Vector3 = source.getPosition()
					const nearbyReflectors: {jecs.Entity<nil>}? = grid.query(reflectorGrid, pos) :: {jecs.Entity<nil>}

					if not nearbyReflectors then continue end

					for i = 1, #nearbyReflectors do

						const entity: jecs.Entity<nil> = nearbyReflectors[i]

						if not entity then continue end

						const part: BasePart? = world:get(entity, components.Reflector)

						if not part then
							debugger.warn("Entity is missing a Reflector component")
							continue
						end

						activeReflectorEntities[entity] = true
						--world:add(entity, components.ActiveReflector)
						--local state: types.ReflectorState = reflectorStatesByPart[part]
						local state: types.ReflectorState? = world:get(entity, components.ReflectorState)

						if not state then -- Cache values
							const partCFrame: CFrame = part.CFrame

							const cellX: number?, cellZ: number? = grid.getCellKey(reflectorGrid, partCFrame.Position)

							const isHybrid: boolean = if reflectorConfig.isHybridEnabled then part:GetAttribute(reflectorConfig.hybridAttributeName) else false
							const hybridTransparencyAttribute: number? = if isHybrid then part:GetAttribute(reflectorConfig.hybridTransparencyAttribute) else nil
							const hybridCanKeepColorsAttribute: boolean? = if isHybrid then part:GetAttribute(reflectorConfig.hybridKeepColorsAttribute) else nil

							const useWedge: boolean = reflectorConfig.useWedgeFacingDetection
							const isWedge: boolean = useWedge and (part:IsA("WedgePart") or (part:IsA("Part") and part.Shape == Enum.PartType.Wedge))

							const slopeNormalWorld: Vector3? = if isWedge then partCFrame:VectorToWorldSpace(Vector3.new(0,1,-1).Unit) else nil

							const faceAttributeName: string = part:GetAttribute(reflectorConfig.faceAttributeName)

							local faceNormalWorld: Vector3?
							if faceAttributeName and utils.validFaces[faceAttributeName] then
								faceNormalWorld = partCFrame:VectorToWorldSpace(Vector3.FromNormalId(Enum.NormalId[faceAttributeName]))
							end

							state = {
								isActive = false,

								currentIntensity = 0,
								lastIntensity = 0.1,
								targetIntensity = 0,
								targetTransparency = 1,
								currentTransparency = 1,
								lastTransparency = 0,

								cellKey = {cellX or 0, cellZ or 0},

								baseColor = part:GetAttribute("BaseColor"),
								lastColor = Color3.fromRGB(1,2,3),
								lastMaterial = Enum.Material.Rock,

								isWedge = isWedge,
								isHybrid = isHybrid,
								CFrame = partCFrame,
								baseIntensity = part:GetAttribute(constraints.BASE_INTENSITY_ATTRIBUTE) or 1,

								hybridFadeRange = if isHybrid then
									(part:GetAttribute(reflectorConfig.hybridMaxDistanceAttribute) or reflectorConfig.defaultHybridMaxDistance) else nil,

								hybridMinDistance = if isHybrid then
									(part:GetAttribute(reflectorConfig.hybridMinDistanceAttribute) or reflectorConfig.defaultHybridMinDistance) else nil,

								hybridTransparencyMultiplier = if typeof(hybridTransparencyAttribute) == "number" then hybridTransparencyAttribute else
									reflectorConfig.defaultHybridTransparencyMultiplier,

								canHybridKeepColors = if typeof(hybridCanKeepColorsAttribute) == "boolean" then hybridCanKeepColorsAttribute
									else reflectorConfig.defaultCanHybridKeepColors,

								faceAttributeName = faceAttributeName,
								slopeNormalWorld = slopeNormalWorld,
								faceNormalWorld = faceNormalWorld,

								doesReflectorMove = part:GetAttribute(generalConfig.movingPartAttribute),
							}:: types.ReflectorState
							--reflectorStatesByPart[part] = state

							world:set(entity, components.ReflectorState, state)
						end

						--print(world:get(entity, components.ReflectorState))

						if not state then
							continue -- have to add this because of type checker
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

						const intensity: number | boolean, transparency: number | boolean = equations.computeReflectorIntensity(part, state, source, MPH)

						if typeof(intensity) == "boolean" or typeof(transparency) == "boolean" then continue end

						state.targetIntensity += intensity
						if state.isHybrid then
							state.targetTransparency = math.min(state.targetTransparency, transparency)
						end

						--print( state.currentIntensity)
					end
				end
			end

			if signConfig.isEnabled then
				for entity: jecs.Entity<nil>, part: Instance, rangeType: types.RangeType in cachedQueries.Signs do
					if not isSourceActive or not isDark then
						continue
					end

					if part == nil then
						debugger.warn(`Sign part is nil for entity: {entity}`)
						continue
					end

					if not part:IsA("BasePart") then
						debugger.warn(`Sign part is NOT a BasePart for entity: {entity}`)
						continue
					end
					--local entity: types.SignEntity = signEntitiesByPart[part]
					local signState: types.SignEntity? = world:get(entity, components.SignState)

					if not signState then
						local partRenderMode: "Decal" | "SurfaceGui" = part:GetAttribute(signConfig.partRenderModeAttributeName)
						partRenderMode = partRenderMode or constraints.SIGNS_PRIMARY_RENDER_MODE :: "Decal" | "SurfaceGui"

						signState = {
							CFrame = part.CFrame,
							Size = part.Size,
							partVeryReflective = part:GetAttribute("VeryReflective"),

							doesSignMove = part:GetAttribute(generalConfig.movingPartAttribute),

							partRenderMode = partRenderMode,

							surfaceGuiState = nil,
							decalState = nil,

							mainDecal = nil,
						} :: types.SignEntity

						world:set(entity, components.SignState, signState)
					end

					if not signState then
						continue -- have to add this because of type checker
					end

					if signState.doesSignMove then
						signState.CFrame = part.CFrame
						signState.Size = part.Size
					end

					local mainDecal: Decal? = signState.mainDecal

					if not mainDecal then
						mainDecal = part:FindFirstChild(signConfig.mainDecalName) :: Decal?
						-- ^ unfortunately one cannot set instances as attributes
						if not mainDecal then
							for _, decal in part:GetChildren() do
								if decal:IsA("Decal") then
									const name = decal.Name

									if signConfig.isMainDecal(decal) then
										mainDecal = decal
										decal.Name = signConfig.mainDecalName
										break
									end
								end
							end
						end

						signState.mainDecal = mainDecal
					end

					if not mainDecal then continue end

					const signData: {brightness: number, lightInfluence: number, transparency: number} = equations.computeSignIntensity(signState, part, mainDecal, "near", activeSources)

					if signData.transparency >= signConfig.inactiveTransparencyThreshold  then
						continue
					end

					if signState.partRenderMode == "SurfaceGui" then
						if part:GetAttribute("IsFixed") ~= true then
							utils.fixPartOrientation(part, mainDecal)
						end

						local state: types.SurfaceGuiState? = signState.surfaceGuiState

						if not state then
							state = {
								gui = nil,
								currentTransparency = 1,
								currentBrightness = 0,
								currentLightInfluence = 1,
								isActive = true,
								isPendingRemoval = false,
								lastTransparency = 1,
								lastBrightness = 0,
								lastLightInfluence = 1,

								targetTransparency = 1,
								targetBrightness = 0,
								targetLightInfluence = 1,
								--	renderMode = "SurfaceGui",
							}:: types.SurfaceGuiState -- forced to do this or else type errors
							signState.surfaceGuiState = state
						end

						if not state then continue end -- have to add this due to type weird errors

						local gui: types.SurfaceGuiTemplate? = state.gui

						if not gui then
							gui = surfaceGuiPool:GetObject() :: types.SurfaceGuiTemplate

							if gui == nil then debugger.warn("Warning", "Pool contains nil instances.") continue end

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

						state.targetTransparency = signData.transparency
						state.targetBrightness = signData.brightness
						state.targetLightInfluence = signData.lightInfluence

						_detectedPartsThisFrame[part] = true
					end

					if signState.partRenderMode == "Decal" then
						local baseColor: Color3 = Color3.fromRGB(255, 255, 255)
						const attribute: Color3? = mainDecal:GetAttribute("BaseColor")

						if attribute then
							baseColor = attribute
						else
							baseColor = mainDecal.Color3
							mainDecal:SetAttribute("BaseColor", baseColor)
						end

						local state: types.DecalState? = signState.decalState

						if not state then
							state = {
								currentBrightness = 0,
								targetBrightness = 0,
								baseColor = baseColor,
							} :: types.DecalState
							signState.decalState = state
						end

						if not state then continue end -- have to add this line again due to type errors

						state.targetBrightness = signData.brightness

						_detectedPartsThisFrame[part] = true
					end
				end
			end

			for entity: jecs.Entity<nil>, signState: types.SignEntity in cachedQueries.SignStates do
				--[[if not part:IsDescendantOf(workspace) then
					signEntitiesByPart[part] = nil
					continue
				end]]

				if not signState then
					continue
				end

				const surfaceGuiState: types.SurfaceGuiState? = signState.surfaceGuiState

				if surfaceGuiState and surfaceGuiState.isPendingRemoval and surfaceGuiState.gui then
					utils.resetSurfaceGui(surfaceGuiPool, surfaceGuiState.gui)

					surfaceGuiState.gui = nil
					signState.surfaceGuiState = nil
					signState.mainDecal = nil
				end
			end

			local temp = currentDetectedParts
			currentDetectedParts = _detectedPartsThisFrame
			_detectedPartsThisFrame = temp
		end
	end, constraints.MAX_PCALL_RETRIES)
end

--[=[
	Public: Gets the current detected parts

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function getDetectedParts(): {[BasePart]: boolean}
	return currentDetectedParts
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
	table.clear(currentDetectedParts)
end

-- Return public API
return table.freeze({
	currentDetectedParts = currentDetectedParts,
	activeReflectorEntities = activeReflectorEntities,
	start = start,
	reset = reset,
	getDetectedParts = getDetectedParts,
	safeCancelThread = safeCancelThread
}) :: types.Detect
