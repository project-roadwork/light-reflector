--!native
--!strict
-- USAGE: lightreflector/client/register.luau
-- Registry of vehicles, signs, a grid, and reflectors for Light Reflector.

--[[

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at https://mozilla.org/MPL/2.0/.

]]

-- IMPORTANT: Services
const CollectionService: CollectionService = game:GetService("CollectionService")
const RunService: RunService = game:GetService("RunService")

-- IMPORTANT: Debugger
const debugger: types.Debugger = require("../shared/debugger")

-- IMPORTANT: Modules
const types = require("../shared/types")
const jecs: types.JecsModule = require("../shared/jecs")
const config: types.Configuration = require("../shared/config")
const utils: types.Utils = require("./utils")
const sources: types.SourcesModule = require("./sources")
const grid: types.GridModule = require("./grid")

-- Reflector Grid
const reflectorGrid: types.Grid = grid.newGrid(1900)

-- SurfaceGui Object Pool
const surfaceGuiPool: types.Pool = utils.initPool()

-- Configuration
const baseConfig: types.BaseConfig = config.getConfig()
const constraints: types.Constraints = baseConfig.Constraints
const signConfig: types.SignConfig = baseConfig.SignConfig

-- Variables
const scriptConnections: { [RBXScriptConnection]: boolean } = {}
const trackedAnsestryInstances: { [Instance]: boolean } = {}

-- Debug Box Setup
const debugBoxTemplate:BasePart = Instance.new("Part") -- forced to do instance.new instead of nil or else the type solver is going into a panic attack
local debugFolder: Folder?

-- Miscellaneous
const abs: (number) -> number = math.abs
const world: jecs.World = jecs.world()
const instanceToEntityId: {[Instance]: jecs.Entity} = {}

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
	ReflectorStates = world:query(components.ReflectorState):cached(),
	Vehicles = world:query(components.VehicleInstance):cached(),
}
-- Raycast Setup
const overlapDetectionParams: OverlapParams = OverlapParams.new()

overlapDetectionParams.FilterType = Enum.RaycastFilterType.Include
overlapDetectionParams.FilterDescendantsInstances = signConfig.signsFolders :: {Instance}

--[=[
	Public: Removes a vehicle
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function unregisterVehicle(car: (types.Vehicle & Instance)): ()
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
const function registerVehicle(car: Instance & types.Vehicle, isEnabled: (Instance) -> boolean, getIntensity: (Instance) -> number): ()
	const config: types.BaseConfig = config.getConfig()
	-- could have asserted but would flood the output with errors

	if car == nil then
		debugger.warn("Warning", "Vehicle (1st argument) CANNOT be nil.")
		return
	end

	--if registeredVehicles[car] then
	--	debugger.warn("Warning", "Vehicle already indexed in vehicle map.")
	--	return
--	end

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

	--registeredVehicles[car] = true
	const entity: jecs.Entity<nil> = world:entity()

	world:set(entity, components.VehicleInstance, car)
	instanceToEntityId[car] = entity

	sources.register(
		car,
		function() return seat.Position + config.General.vehicleSeatOffset end,
		function() return seat.CFrame.LookVector end,
		function()
			if typeof(isEnabled) == "Instance" and isEnabled:IsA("ValueBase") then
				const v: any = isEnabled.Value
				return (type(v) == "boolean" and v) or (type(v) == "number" and v > 0)
			else
				return (type(isEnabled) == "boolean" and isEnabled) or (type(isEnabled) == "number" and isEnabled > 0)
			end
		end, getIntensity
	)

	if not trackedAnsestryInstances[car] then
		const connection: RBXScriptConnection = utils.trackAncestryRemoval(car, function()
			trackedAnsestryInstances[car] = nil
			unregisterVehicle(car)
		end)

		scriptConnections[connection] = true
		trackedAnsestryInstances[car] = true
	end
end

--[=[
	Public: Processes reflectors and normalizes base color
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function registerReflector(part: Instance)
	const config: types.BaseConfig = config.getConfig()
	const reflectorConfig: types.ReflectorConfig = config.ReflectorConfig

	if part:GetAttribute(reflectorConfig.hybridCloneAttributeName) then
		return
	end

	if (reflectorConfig.isReflector(part) or part:HasTag(reflectorConfig.tagName)) and part:IsA("BasePart") then

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

		if reflectorConfig.isHybridEnabled and part:GetAttribute(reflectorConfig.hybridAttributeName) then
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
			--registeredReflectors[clone] = true
			utils.normalizeBaseColor(clone, false) -- setting the second argument to false just sets the baseColor attribute

			if not trackedAnsestryInstances[clone] then
				const connection: RBXScriptConnection = utils.trackAncestryRemoval(clone, function()
					const state: types.ReflectorState? = world:get(entity, components.ReflectorState)

					if state then
						grid.remove(reflectorGrid,entity, state.CFrame.Position)
					else
						grid.remove(reflectorGrid,entity, part.Position)
					end

					instanceToEntityId[part] = nil
					trackedAnsestryInstances[part] = nil
					world:delete(entity)
				end)

				scriptConnections[connection] = true
				trackedAnsestryInstances[clone] = true
			end

			grid.spawn(reflectorGrid, entity, clone.Position)
		else
			const entity: jecs.Entity<nil> = world:entity()

			world:set(entity, components.Reflector, part)
			instanceToEntityId[part] = entity

			--registeredReflectors[part] = true
			utils.normalizeBaseColor(part, true)

			if not trackedAnsestryInstances[part] then
				const connection: RBXScriptConnection = utils.trackAncestryRemoval(part, function()
					const state: types.ReflectorState? = world:get(entity, components.ReflectorState)

					if state then
						grid.remove(reflectorGrid,entity, state.CFrame.Position)
					else
						grid.remove(reflectorGrid,entity, part.Position)
					end

					instanceToEntityId[part] = nil
					trackedAnsestryInstances[part] = nil
					world:delete(entity)

				end)

				scriptConnections[connection] = true
				trackedAnsestryInstances[part] = true
			end


			grid.spawn(reflectorGrid, entity, part.Position)
		end
	end
end


--[=[
	Public: Removes reflectors from the reflector rable
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function unregisterReflector(part:BasePart): ()
	const config: types.BaseConfig = config.getConfig()
	const reflectorConfig: types.ReflectorConfig = config.ReflectorConfig

	if reflectorConfig.isReflector(part) or part:HasTag(reflectorConfig.tagName) then
		if instanceToEntityId[part] then
			const entity: jecs.Entity<nil> = instanceToEntityId[part]

			if world:contains(entity) then
				const state: types.ReflectorState? = world:get(entity, components.ReflectorState)

				if state then
					grid.remove(reflectorGrid,entity, state.CFrame.Position)
				else
					grid.remove(reflectorGrid,entity, part.Position)
				end

				world:delete(entity)
			end

			if trackedAnsestryInstances[part] then
				trackedAnsestryInstances[part] = nil
			end

			instanceToEntityId[part] = nil
		end

		--registeredReflectors[part] = nil

		if part:GetAttribute(reflectorConfig.hybridCloneAttributeName) then
			part:Destroy()
		end
	end
end

const function registerSign(part:Instance, rangeType: string?): ()
	--registeredSigns[part::any] = if rangeType ~= nil then rangeType else "near" -- near and far range types does not really make a difference
	if instanceToEntityId[part] then
		return
	end

	const entity: jecs.Entity<nil> = world:entity()

	world:set(entity, components.Sign, part)
	world:set(entity, components.SignInRange, (if rangeType ~= nil then rangeType else "near"):: types.RangeType)
	instanceToEntityId[part] = entity

	if part:IsA("BasePart") then
		if not trackedAnsestryInstances[part] then
			const connection: RBXScriptConnection = utils.trackAncestryRemoval(part, function()
				trackedAnsestryInstances[part] = nil

				world:delete(entity)
				instanceToEntityId[part] = nil
			end)

			scriptConnections[connection] = true
			trackedAnsestryInstances[part] = true
		end
	end

end

const function unregisterSign(part:Instance): ()
	if instanceToEntityId[part] then
		const entity: jecs.Entity<nil>? = instanceToEntityId[part]
		if entity and world:contains(entity) then
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
	const config: types.BaseConfig = config.getConfig()

	const isTagsEnabled: boolean = config.SignConfig.isTagsEnabled
	const tagName: string = config.SignConfig.tagName

	if isTagsEnabled then
		for _, part: BasePart in CollectionService:GetTagged(tagName) do
			registerSign(part)
		end

		if config.Constraints.IS_STREAMING_ENABLED then
			const instanceAddedSignal:RBXScriptConnection = CollectionService:GetInstanceAddedSignal(tagName):Connect(registerSign)

			const instanceRemovedSignal:RBXScriptConnection = CollectionService:GetInstanceRemovedSignal(tagName):Connect(unregisterSign)

			scriptConnections[instanceAddedSignal] = true
			scriptConnections[instanceRemovedSignal] = true
		end

	else
		for _: number, folder: Folder in config.SignConfig.signsFolders :: {Folder} do
			for _: number, part:BasePart in folder:GetDescendants() do
				registerSign(part)
			end

			if config.Constraints.IS_STREAMING_ENABLED then
				const descendantAddedSignal:RBXScriptConnection = folder.DescendantAdded:Connect(function(part)
					registerSign(part) -- cannot do :Connect(registerSign) or else it would cause type issues
				end)

				const descendantRemovingSignal:RBXScriptConnection = folder.DescendantRemoving:Connect(function(part)
					unregisterSign(part)
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
	const config: types.BaseConfig = config.getConfig()
	const partsDictionary: {[BasePart]: types.RangeType} = {}

	for entity: jecs.Entity<nil>, car:Instance in cachedQueries.VehicleInstances do
		const DriveSeat: VehicleSeat? = car:FindFirstChildOfClass("VehicleSeat")

		if not DriveSeat then continue end

		const seatCF: CFrame = DriveSeat.CFrame
		const boxCF: CFrame = seatCF * config.SignConfig.raycastBoxOffset

		if config.SignConfig.isDebugBoxEnabled then
			local vehicleDebugBox: BasePart? = world:get(entity, components.VehicleDebugBox)

			if not vehicleDebugBox then
				vehicleDebugBox = debugBoxTemplate:Clone()
				world:set(entity, components.VehicleDebugBox, vehicleDebugBox)
			end

			if not vehicleDebugBox then continue end -- have to add this because of type checker

			vehicleDebugBox.CFrame = boxCF
			vehicleDebugBox.Transparency = config.SignConfig.debugBoxTransparency
			vehicleDebugBox.Parent = debugFolder

		end

		for _: number, part: BasePart in config.General.GetPartsInBox(workspace, seatCF * config.SignConfig.raycastBoxOffsetNear, config.SignConfig.raycastBoxSizeNear, overlapDetectionParams) do
			registerSign(part, "near")
		end

		for _: number, part: BasePart in config.General.GetPartsInBox(workspace, seatCF * config.SignConfig.raycastBoxOffsetFar, config.SignConfig.raycastBoxSizeFar, overlapDetectionParams) do
			--if not partsDictionary[part] then partsDictionary[part] = "far" end
			registerSign(part, "far")
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
	const config: types.BaseConfig = config.getConfig()
	const reflectorConfig: types.ReflectorConfig = config.ReflectorConfig

	if reflectorConfig.isTagsEnabled then
		for _: number, part:Instance in CollectionService:GetTagged(reflectorConfig.tagName) do
			registerReflector(part)
		end

		const instanceAddedSignal:RBXScriptConnection = CollectionService:GetInstanceAddedSignal(reflectorConfig.tagName):Connect(registerReflector)
		const instanceRemovedSignal:RBXScriptConnection = CollectionService:GetInstanceRemovedSignal(reflectorConfig.tagName):Connect(unregisterReflector)

		scriptConnections[instanceAddedSignal] = true
		scriptConnections[instanceRemovedSignal] = true
	else
		for _: number, Folder: any in reflectorConfig.reflectorsFolder do
			for _: number, part:Instance in Folder:GetDescendants() do
				registerReflector(part)
			end

			const descendantAddedSignal:RBXScriptConnection = Folder.DescendantAdded:Connect(registerReflector::any)
			const DescendantRemovingSignal:RBXScriptConnection = Folder.DescendantRemoving:Connect(unregisterReflector::any)

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
	const config: types.BaseConfig = config.getConfig()

	if config.SignConfig.isDebugBoxEnabled then
		debugFolder = config.SignConfig.debugBoxFolder
			or Instance.new("Folder")
		debugFolder.Parent = workspace

		if not config.SignConfig.debugBoxFolder then debugFolder.Name = "LR-DebugFolder" end

		debugBoxTemplate.Anchored = true
		debugBoxTemplate.CanCollide = false
		debugBoxTemplate.CastShadow = false
		debugBoxTemplate.Transparency = config.SignConfig.debugBoxTransparency
		debugBoxTemplate.Color = config.SignConfig.debugBoxColor
		debugBoxTemplate.Material = config.SignConfig.debugBoxMaterial
		debugBoxTemplate.Name = config.SignConfig.debugBoxName
		debugBoxTemplate.Size = config.SignConfig.raycastBoxSizeNear
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
	Public: Disconnects the connections in the table 'scriptConnections'
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function clearConnections(): ()
	for scriptSignal:RBXScriptSignal, boolean:boolean in scriptConnections do
		if not scriptSignal then
			continue
		end

		scriptSignal:Disconnect()
		scriptConnections[scriptSignal] = nil
	end

	table.clear(scriptConnections)
end

const function start(): ()
	const config: types.BaseConfig = config.getConfig()

	_initDebugBox()

	if not config.Constraints.IS_RAYCAST_ENABLED then
		_cacheSigns()
	end

    _cacheReflectors()
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

	local toDelete: {jecs.Entity} = {}

	for entity: jecs.Entity in world:query() do
		table.insert(toDelete, entity)
	end

	for _: number, entity: jecs.Entity in toDelete do
		world:delete(entity)
	end

	table.clear(trackedAnsestryInstances)
	table.clear(instanceToEntityId)
end

-- Return API and variables
return table.freeze({
	Name = "register",

	start = start,

	reflectorGrid = reflectorGrid,

	debugBoxTemplate = debugBoxTemplate,
	surfaceGuiPool = surfaceGuiPool,

	getWorldUtils = getWorldUtils,

	registerVehicle = registerVehicle,
	unregisterVehicle = unregisterVehicle,
	registerReflector = registerReflector,
	unregisterReflector = unregisterReflector,

	clearConnections = clearConnections,
	reset = reset,

	scriptConnections = scriptConnections,
	getPartsByRaycast = getPartsByRaycast,

}) :: types.Register
