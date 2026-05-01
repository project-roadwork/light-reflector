--!native
--!strict
-- USAGE: lightreflector/client/register.luau
-- Registry of vehicles, signs, a grid, and reflectors for Light Reflector.

--[[

    SPDX-FileCopyrightText: 2025-2026 Illinois_Roadbuff (Rogue Jr) <illinois_roadbuff@proton.me>
    SPDX-FileCopyrightText: 2025-2026 Project Roadwork and Contributors

    SPDX-License-Identifier: MPL-2.0

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at https://mozilla.org/MPL/2.0/.

]]

-- IMPORTANT: Services
const CollectionService: CollectionService = game:GetService("CollectionService")

-- IMPORTANT: Debugger
const debugger = require("../shared/debugger")

-- IMPORTANT: Modules
const types = require("../shared/types")
const jecs: types.JecsModule = require("../shared/jecs")
const config: types.Configuration = require("../shared/config")
const utils: types.Utils = require("./utils")
const sources: types.SourcesModule = require("./sources")
const grid: types.GridModule = require("./grid")
const states: types.StatesModule = require("./states")

-- IMPORTANT: Configuration Variables
local baseConfig: types.BaseConfig = config.getConfig()
local constraints: types.Constraints = baseConfig.Constraints
local reflectorConfig: types.ReflectorConfig = baseConfig.ReflectorConfig
local generalConfig: types.GeneralConfig = baseConfig.General
local signConfig: types.SignConfig = baseConfig.SignConfig

-- Grids
const reflectorGrid: types.Grid = grid.newGrid(1900)
const signGrid: types.Grid = grid.newGrid(1900)

-- SurfaceGui Object Pool
const surfaceGuiPool: types.Pool<types.SurfaceGuiTemplate> = utils.initPool()

-- Variables
const scriptConnections: { [RBXScriptConnection]: boolean } = {}
const trackedAncestryInstances: { [Instance]: boolean } = {}
const instanceToEntityId: {[Instance]: jecs.Entity} = {}
local hasInit: boolean = false

-- Debug Box Setup
const debugBoxTemplate:BasePart = Instance.new("Part") -- forced to do instance.new instead of nil or else the type solver is going into a panic attack
local debugFolder: Folder?

-- Miscellaneous
const abs: (number) -> number = math.abs
const world: jecs.World = jecs.world()

-- Components
const components: types.Components = {
	VehicleInstance = world:component() :: jecs.Id<Instance>,
	VehicleDebugBox = world:component() :: jecs.Id<BasePart>,
	Reflector = world:component() :: jecs.Id<BasePart>,
	Sign = world:component() :: jecs.Id<Instance>,
	ReflectorState = world:component() :: jecs.Id<types.ReflectorState>,
	SignState = world:component() :: jecs.Id<types.SignEntity>,
	SignInRange = world:component() :: jecs.Id<types.RangeType> ,
}

const cachedQueries: types.CachedQueries = {
	VehicleInstances = world:query(components.VehicleInstance):cached(),
	Signs = world:query(components.Sign, components.SignInRange):cached(),
	Reflectors = world:query(components.Reflector, components.ReflectorState):cached(),
	SignStates = world:query(components.SignState):cached(),
	SignsPartsStates = world:query(components.Sign, components.SignState):cached(),
	ReflectorStates = world:query(components.ReflectorState):cached()
}
-- Raycast Setup
const overlapDetectionParams: OverlapParams = OverlapParams.new()

overlapDetectionParams.FilterType = Enum.RaycastFilterType.Include

--[=[
	Public: Removes a vehicle

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function removeVehicle(car: (types.Vehicle & Instance)): ()
	const entityId: jecs.Entity<nil>? = instanceToEntityId[car]

	if not entityId then
		debugger.warn("Warning", "Cannot find vehicle in vehicle map.")
		return
	end

	const vehicle: Instance? = world:get(entityId, components.VehicleInstance)
	--	local instance = world:get(entityId, components.Instance)

	if car and typeof(car) == "Instance" and car ~= vehicle then
		debugger.warn("Warning", "Cannot find vehicle in vehicle map.")
		return
	end

	const sourcesList: types.SourceList = sources.list
	--registeredVehicles[car] = nil

	for i = #sourcesList, 1, -1 do
		if sourcesList[i].Owner == vehicle then
			debugger.print("Info", "Found car")
			table.remove(sourcesList, i)
			break
		end
	end

	const box: BasePart? = world:get(entityId, components.VehicleDebugBox)
	if box then
		box:Destroy()
		--vehicleDebugBoxes[car] = nil
	end

	world:delete(entityId)

	if typeof(car) == "Instance" then
		instanceToEntityId[car] = nil
	end
end

--[=[
	Public: Adds a vehicle

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function addVehicle(car: Instance & types.Vehicle, isEnabled: (Instance) -> boolean, getIntensity: (Instance) -> number, getColor: (Instance) -> vector): ()
	-- could have asserted but would flood the output with errors

	if car == nil then
		debugger.warn("Warning", "Vehicle (1st argument) CANNOT be nil.")
		return
	end

	if instanceToEntityId[car] then
		debugger.warn("Warning", "Vehicle already indexed in vehicle map.")
		return
	end

	const seat: VehicleSeat? = car:FindFirstChildOfClass("VehicleSeat")

	if not seat then
		debugger.warn("Warning", "Failed to find VehicleSeat in vehicle (1st argument). Did you ensure that the VehicleSeat instance exists before calling RegisterVehicle?")
		return
	end

	if isEnabled == nil then
		debugger.warn("Warning", "Enabled (2nd argument) CANNOT be nil.")
		return
	end

	if type(isEnabled) ~= "boolean"
		and type(isEnabled) ~= "number"
		and not (typeof(isEnabled) == "Instance" and isEnabled:IsA("ValueBase")) then

		debugger.warn("Warning", "Enabled (2nd argument) MUST be a boolean, number, or a ValueBase like IntValue, etc.")
		return
	end

	const entity: jecs.Entity<nil> = world:entity()

	world:set(entity, components.VehicleInstance, car)
	instanceToEntityId[car] = entity

	sources.register(
		car,
		function() return seat.Position + generalConfig.vehicleSeatOffset end,
		function() return seat.CFrame.LookVector end,
		function()
			if typeof(isEnabled) == "Instance" and isEnabled:IsA("ValueBase") then
				const v: any = isEnabled.Value
				return (type(v) == "boolean" and v) or (type(v) == "number" and v > 0)
			else
				return (type(isEnabled) == "boolean" and isEnabled) or (type(isEnabled) == "number" and isEnabled > 0)
			end
		end, getIntensity, getColor
	)

	if not trackedAncestryInstances[car] then
		const connection: RBXScriptConnection = utils.trackAncestryRemoval(car, function()
			trackedAncestryInstances[car] = nil
			removeVehicle(car)
		end)

		scriptConnections[connection] = true
		trackedAncestryInstances[car] = true
	end
end

--[=[
	Public: Processes reflectors and normalizes base color

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function addReflector(part: Instance)
	const attributes: {[string]: any} = part:GetAttributes()

	if attributes[reflectorConfig.hybridCloneAttributeName] then
		return
	end

	if not part:IsA("BasePart") then
		return
	end

	const hasTag: boolean = reflectorConfig.isTagsEnabled and part:HasTag(reflectorConfig.tagName)
	const isReflector_nontag: boolean? = reflectorConfig.isTagsEnabled == false and reflectorConfig.isReflector(part)

	if not hasTag or isReflector_nontag  then
		return
	end

	if part:IsA("MeshPart") then
		const canKeepTexturesAttribute:boolean? = part:GetAttribute(reflectorConfig.canKeepTexturesAttribute)

		const canKeepTextureProperty: boolean =
			if typeof(canKeepTexturesAttribute) == "boolean"
			then canKeepTexturesAttribute
			else reflectorConfig.defaultCanKeepTextures

		if canKeepTextureProperty == false then
			if part.TextureID then
				part.TextureID = ""
			end
		end
	end

	const isHybrid: boolean = reflectorConfig.isHybridEnabled and attributes[reflectorConfig.hybridAttributeName]

	if isHybrid then
		const clone: BasePart = part:Clone()

		clone:SetAttribute(reflectorConfig.hybridCloneAttributeName, true)
		CollectionService:RemoveTag(clone, reflectorConfig.tagName)

		if clone:IsA("MeshPart") then
			const canKeepTexturesAttribute:boolean? = clone:GetAttribute(reflectorConfig.canHybridKeepTexturesAttribute)

			const canKeepTextureProperty: boolean =
				if typeof(canKeepTexturesAttribute) == "boolean"
				then canKeepTexturesAttribute
				else reflectorConfig.defaultHybridCanKeepTextures

			if not canKeepTexturesAttribute then
				if clone.TextureID then
					clone.TextureID = ""
				end
			end
		end

		const hybridCanKeepColorsAttribute: boolean? = part:GetAttribute(reflectorConfig.hybridKeepColorsAttribute)

		const canHybridKeepColors: boolean =
			if typeof(hybridCanKeepColorsAttribute) == "boolean"
			then hybridCanKeepColorsAttribute
			else reflectorConfig.defaultCanHybridKeepColors


		if part:IsA("UnionOperation") and canHybridKeepColors == false then part.UsePartColor = true end

		if reflectorConfig.isHybridFaceOffsetEnabled then
			const offset: number = reflectorConfig.hybridOffset

			const face: string? = part:GetAttribute("LRFace")
			if face and utils.validFaces[face] then
				const faceNormalconst: Vector3 = Vector3.FromNormalId(Enum.NormalId[face])
				const faceNormalWorld: Vector3 = part.CFrame:VectorToWorldSpace(faceNormalconst)

				const offsetDistance: number = abs(faceNormalWorld.X) > 0 and offset
					or abs(faceNormalWorld.Y) > 0 and offset
					or offset

				clone.CFrame = part.CFrame + faceNormalWorld * (offsetDistance)
			end
		end -- an offset may be needed or else the neon clone and non-neon clone may overlap and flicker

		clone.Name = reflectorConfig.hybridCloneName
		clone.Transparency = 1
		clone.CanCollide = false
		clone.CanTouch = false
		clone.CanQuery = false
		clone.Parent = part.Parent

		const entity: jecs.Entity<nil> = world:entity()

		world:set(entity, components.Reflector, clone)
		instanceToEntityId[clone] = entity

		utils.normalizeBaseColor(clone, false) -- setting the second argument to false just sets the baseColor attribute

		if not trackedAncestryInstances[clone] then
			const connection: RBXScriptConnection = utils.trackAncestryRemoval(clone, function()
				const state: types.ReflectorState? = world:get(entity, components.ReflectorState)

				if state then
					grid.remove(reflectorGrid, entity)
					states.returnReflectorState(state)
				else
					grid.remove(reflectorGrid, entity)
				end

				instanceToEntityId[part] = nil
				trackedAncestryInstances[part] = nil
				world:delete(entity)
			end)

			scriptConnections[connection] = true
			trackedAncestryInstances[clone] = true
		end

		grid.spawn(reflectorGrid, entity, clone.Position)
	else
		const entity: jecs.Entity<nil> = world:entity()

		world:set(entity, components.Reflector, part)
		instanceToEntityId[part] = entity

		utils.normalizeBaseColor(part, true)

		if not trackedAncestryInstances[part] then
			const connection: RBXScriptConnection = utils.trackAncestryRemoval(part, function()
				const state: types.ReflectorState? = world:get(entity, components.ReflectorState)

				if state then
					grid.remove(reflectorGrid, entity)
					states.returnReflectorState(state)
				else
					grid.remove(reflectorGrid, entity)
				end

				instanceToEntityId[part] = nil
				trackedAncestryInstances[part] = nil
				world:delete(entity)

			end)

			scriptConnections[connection] = true
			trackedAncestryInstances[part] = true
		end


		grid.spawn(reflectorGrid, entity, part.Position)
	end
end

--[=[
	Public: Removes reflectors from the reflector rable

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function removeReflector(part:BasePart): ()
	if reflectorConfig.isReflector(part) or part:HasTag(reflectorConfig.tagName) then
		if instanceToEntityId[part] then
			const entity: jecs.Entity<nil> = instanceToEntityId[part]

			if world:contains(entity) then
				const state: types.ReflectorState? = world:get(entity, components.ReflectorState)

				if state then
					grid.remove(reflectorGrid, entity)
					states.returnReflectorState(state)
				else
					grid.remove(reflectorGrid, entity)
				end

				world:delete(entity)
			end

			if trackedAncestryInstances[part] then
				trackedAncestryInstances[part] = nil
			end

			instanceToEntityId[part] = nil
		end

		if part:GetAttribute(reflectorConfig.hybridCloneAttributeName) then
			part:Destroy()
		end
	end
end

--[=[
	Public: Adds a sign

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function addSign(part:Instance, rangeType: string?): ()
	if instanceToEntityId[part] then
		return
	end

	const entity: jecs.Entity<nil> = world:entity()

	world:set(entity, components.Sign, part)
	world:set(entity, components.SignInRange, (if rangeType ~= nil then rangeType else "near"):: types.RangeType)
	instanceToEntityId[part] = entity

	if not part:IsA("BasePart") then
        return
	end

	const hasTag: boolean = reflectorConfig.isTagsEnabled and part:HasTag(signConfig.tagName)
	const isSign_nontag: boolean? = signConfig.isTagsEnabled == false and signConfig.isSign(part)

	if hasTag or isSign_nontag then
		if not trackedAncestryInstances[part] then
			const connection: RBXScriptConnection = utils.trackAncestryRemoval(part, function()
				trackedAncestryInstances[part] = nil

				world:delete(entity)
				instanceToEntityId[part] = nil
				grid.remove(signGrid, entity)
			end)

			scriptConnections[connection] = true
			trackedAncestryInstances[part] = true
		end
		grid.spawn(signGrid, entity, part.Position)
	end
end

--[=[
	Public: Removes a sign

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function removeSign(part:Instance): ()
	if instanceToEntityId[part] then
		const entity: jecs.Entity<nil>? = instanceToEntityId[part]
		if entity and world:contains(entity) then
			const signState: types.SignEntity? = world:get(entity, components.SignState)

			if signState then
				const surfaceGuiState: types.SurfaceGuiState? = signState.surfaceGuiState
				const decalState: types.DecalState? = signState.decalState

				states.returnSignState(signState, surfaceGuiPool)
			end

			grid.remove(signGrid, entity)
			world:delete(entity)
		end
		instanceToEntityId[part] = nil
	end
end

--[=[
	Private: Builds Part Cache

	@private
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function _cacheSigns():  ()
	const isTagsEnabled: boolean = signConfig.isTagsEnabled
	const tagName: string = signConfig.tagName

	if isTagsEnabled then
		for _, part: Instance in CollectionService:GetTagged(tagName) do
			addSign(part)
		end

		if constraints.IS_STREAMING_ENABLED then
			const instanceAddedSignal:RBXScriptConnection = CollectionService:GetInstanceAddedSignal(tagName):Connect(addSign)

			const instanceRemovedSignal:RBXScriptConnection = CollectionService:GetInstanceRemovedSignal(tagName):Connect(removeSign)

			scriptConnections[instanceAddedSignal] = true
			scriptConnections[instanceRemovedSignal] = true
		end

	else
		for _: number, folder: Instance in signConfig.signsFolders do
			for _: number, part:Instance in folder:GetDescendants() do
				addSign(part)
			end

			if constraints.IS_STREAMING_ENABLED then
				const descendantAddedSignal:RBXScriptConnection = folder.DescendantAdded:Connect(function(part)
					addSign(part) -- cannot do :Connect(addSign) or else it would cause type issues
				end)

				const descendantRemovingSignal:RBXScriptConnection = folder.DescendantRemoving:Connect(function(part)
					removeSign(part)
				end)

				scriptConnections[descendantAddedSignal] = true
				scriptConnections[descendantRemovingSignal] = true
			end
		end
	end
end

--[=[
	Private: Inserts parts into a table via raycast

	@private
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function getPartsByRaycast(): {[BasePart]: types.RangeType}
	const partsDictionary: {[BasePart]: types.RangeType} = {}

	for entity: jecs.Entity<nil>, car:Instance in cachedQueries.VehicleInstances do
		const DriveSeat: VehicleSeat? = car:FindFirstChildOfClass("VehicleSeat")

		if not DriveSeat then continue end

		const seatCF: CFrame = DriveSeat.CFrame
		const boxCF: CFrame = seatCF * signConfig.raycastBoxOffset

		if signConfig.isDebugBoxEnabled then
			local vehicleDebugBox: BasePart? = world:get(entity, components.VehicleDebugBox)

			if not vehicleDebugBox then
				vehicleDebugBox = debugBoxTemplate:Clone()
				world:set(entity, components.VehicleDebugBox, vehicleDebugBox)
			end

			if not vehicleDebugBox then continue end -- have to add this because of type checker

			vehicleDebugBox.CFrame = boxCF
			vehicleDebugBox.Transparency = signConfig.debugBoxTransparency
			vehicleDebugBox.Parent = debugFolder

		end

		for _: number, part: BasePart in generalConfig.GetPartsInBox(workspace, seatCF * signConfig.raycastBoxOffsetNear, signConfig.raycastBoxSizeNear, overlapDetectionParams) do
			addSign(part, "near")
		end

		for _: number, part: BasePart in generalConfig.GetPartsInBox(workspace, seatCF * signConfig.raycastBoxOffsetFar, signConfig.raycastBoxSizeFar, overlapDetectionParams) do
			--if not partsDictionary[part] then partsDictionary[part] = "far" end
			addSign(part, "far")
		end
	end

	return partsDictionary
end

--[=[
	Private: Starts reflector indexing and processing

	@private
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function _cacheReflectors(): ()
	if reflectorConfig.isTagsEnabled then
		for _: number, part:Instance in CollectionService:GetTagged(reflectorConfig.tagName) do
			addReflector(part)
		end

		const instanceAddedSignal:RBXScriptConnection = CollectionService:GetInstanceAddedSignal(reflectorConfig.tagName):Connect(addReflector)
		const instanceRemovedSignal:RBXScriptConnection = CollectionService:GetInstanceRemovedSignal(reflectorConfig.tagName):Connect(removeReflector)

		scriptConnections[instanceAddedSignal] = true
		scriptConnections[instanceRemovedSignal] = true
	else
		for _: number, Folder: any in reflectorConfig.reflectorsFolders do
			for _: number, part:Instance in Folder:GetDescendants() do
				addReflector(part)
			end

			const descendantAddedSignal:RBXScriptConnection = Folder.DescendantAdded:Connect(addReflector)
			const DescendantRemovingSignal:RBXScriptConnection = Folder.DescendantRemoving:Connect(removeReflector)

			scriptConnections[descendantAddedSignal] = true
			scriptConnections[DescendantRemovingSignal] = true
		end
	end
end

--[=[
	Public: Sets up the DebugBox
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function _initDebugBox(): ()
	if signConfig.isDebugBoxEnabled then
		debugFolder = signConfig.debugBoxFolder
			or Instance.new("Folder")
		debugFolder.Parent = workspace

		if not signConfig.debugBoxFolder then debugFolder.Name = "LR-DebugFolder" end

		debugBoxTemplate.Anchored = true
		debugBoxTemplate.CanCollide = false
		debugBoxTemplate.CastShadow = false
		debugBoxTemplate.Transparency = signConfig.debugBoxTransparency
		debugBoxTemplate.Color = signConfig.debugBoxColor
		debugBoxTemplate.Material = signConfig.debugBoxMaterial
		debugBoxTemplate.Name = signConfig.debugBoxName
		debugBoxTemplate.Size = signConfig.raycastBoxSizeNear
		debugBoxTemplate.Parent = debugFolder
	end
end
--[=[
	Public: Gets the world, components, and instanceToEntityId table
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]

const function getWorldUtils(): (jecs.World, types.Components, {[Instance]: jecs.Entity}, types.CachedQueries)
	return world, components, instanceToEntityId, cachedQueries
end

--[=[
	Public: Initializes the register

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function init(): ()
	if hasInit then
		return
	end

	if not world then
		debugger.fatal("FatalInit","[Register Module] 🔴 JECS (an Entity Component System) failed to load the world.")
	end

	config.onChange(function(NEW_CONFIG: types.BASE_CONFIG)
		baseConfig = NEW_CONFIG
		constraints = NEW_CONFIG.Constraints
		reflectorConfig = NEW_CONFIG.ReflectorConfig
		generalConfig = NEW_CONFIG.General
		signConfig = NEW_CONFIG.SignConfig

		overlapDetectionParams.FilterDescendantsInstances = signConfig.signsFolders
	end)

	overlapDetectionParams.FilterDescendantsInstances = signConfig.signsFolders

	_initDebugBox()

	hasInit = true
end

--[=[
	Public: Starts the register

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function start(): ()
	init() -- Most likely is not needed, but adding it anyway in case someone uses this module by itself

	if not constraints.IS_RAYCAST_INDEXING_ENABLED then
		_cacheSigns()
	end

	_cacheReflectors()
end

--[=[
	Public: Disconnects the connections in the table 'scriptConnections'
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function clearConnections(): ()
	for scriptSignal:RBXScriptConnection, boolean:boolean in scriptConnections do
		if not scriptSignal then
			continue
		end

		scriptSignal:Disconnect()
		scriptConnections[scriptSignal] = nil
	end

	table.clear(scriptConnections)
end

--[=[
	Public: Resets the reflectors and signs
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function reset(): ()
	const config: types.BaseConfig = config.getConfig()
	const reflectorConfig: types.ReflectorConfig = config.ReflectorConfig

	for entity: jecs.Entity<nil>, signEntity: types.SignEntity in cachedQueries.SignStates do
		const surfaceGuiState: types.SurfaceGuiState? = signEntity.surfaceGuiState
		const decalState: types.DecalState? =signEntity.decalState
		const mainDecal: Decal? = signEntity.mainDecal

		if surfaceGuiState and surfaceGuiState.gui then
			utils.resetSurfaceGui(surfaceGuiPool, surfaceGuiState.gui)
		end

		if decalState and mainDecal then
			mainDecal.Color3 = decalState.baseColor
		end
	end

	for entity: jecs.Entity<nil>, part: BasePart, state: types.ReflectorState in cachedQueries.Reflectors do
		const Material: Enum.Material = part.Material
		const Color: Color3 = part.Color

		const newColor: Color3 = state.baseColor
		const newMaterial: Enum.Material = reflectorConfig.inactiveMaterial

		if state.lastMaterial ~= newMaterial then
			part.Material = newMaterial
			state.lastMaterial = newMaterial
		end

		if Color and not utils.areColorsEqual(state.lastColor, newColor, 0.01) then
			part.Color = newColor
			state.lastColor = newColor
		end

		if part:GetAttribute(reflectorConfig.hybridCloneAttributeName) then
			part:Destroy()
		end
	end

	if not config.SignConfig.debugBoxFolder and debugFolder then
		debugFolder:Destroy()
	else
		for entity: jecs.Entity<nil>, vehicleDebugBox: BasePart in world:query(components.VehicleDebugBox) do
			if vehicleDebugBox then
				vehicleDebugBox:Destroy()
			end
		end
	end

	grid.empty(reflectorGrid)
	grid.empty(signGrid)

	local toDelete: {jecs.Entity} = {}

	for instance: Instance, entity: jecs.Entity in instanceToEntityId do
		table.insert(toDelete, entity)
	end

	for _: number, entity: jecs.Entity in toDelete do
		world:delete(entity)
	end

	table.clear(trackedAncestryInstances)
	table.clear(instanceToEntityId)
	table.clear(toDelete)
end

-- Return API and variables
return table.freeze({
	name = "register",

	init = init,
	start = start,

	reflectorGrid = reflectorGrid,
	signGrid = signGrid,

	debugBoxTemplate = debugBoxTemplate,
	surfaceGuiPool = surfaceGuiPool,

	getWorldUtils = getWorldUtils,

	addVehicle = addVehicle,
	removeVehicle = removeVehicle,
	addReflector = addReflector,
	removeReflector = removeReflector,
	addSign = addSign,
	removeSign = removeSign,

	clearConnections = clearConnections,
	reset = reset,

	getPartsByRaycast = getPartsByRaycast,

})
