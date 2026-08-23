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
const types: {} = require("../shared/types")
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
const reflectorGrid: types.Grid = grid.newGrid(300)
const signGrid: types.Grid = grid.newGrid(600)

-- Object Pools
const surfaceGuiPool: types.Pool<types.SurfaceGuiTemplate> = utils.initSurfaceGuiPool()
const partPool: types.Pool<Part> = utils.initPartPool()

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
	SourceInstance = world:component() :: jecs.Id<BasePart>,
	SourceDebugBox = world:component() :: jecs.Id<BasePart>,
	Reflector = world:component() :: jecs.Id<BasePart>,
	Sign = world:component() :: jecs.Id<BasePart>,
	ReflectorState = world:component() :: jecs.Id<types.ReflectorState>,
	SignState = world:component() :: jecs.Id<types.SignEntity>,
	SignInRange = world:component() :: jecs.Id<types.RangeType> ,
}

const cachedQueries: types.CachedQueries = {
	SourceInstances = world:query(components.SourceInstance):cached(),
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
const function removeSource(source: BasePart): ()
    if not source then
        return
    end

	const entityId: jecs.Entity<nil>? = instanceToEntityId[source]

	if not entityId then
		debugger.warn("Warning", "[REGISTER] Cannot find source in source map.")
		return
	end

	const sourceEntity: BasePart? = world:get(entityId, components.SourceInstance)

	if not sourceEntity then
		debugger.warn("Warning", "[REGISTER] Cannot find matching source in source map.")
		return
	end

	if source ~= sourceEntity then
		debugger.warn("Warning", "[REGISTER] Cannot find matching source in source map.")
		return
	end

	const sourcesList: types.SourceList = sources.list

	for i = #sourcesList, 1, -1 do
		if sourcesList[i].Owner == sourceEntity then
			table.remove(sourcesList, i)
			if generalConfig.showRegisteredPrints == true then
			    debugger.shortPrint(`[REGISTER] Unregistered {sourceEntity:GetFullName()}`)
			end
			break
		end
	end

	if constraints.LOOK_VECTOR_VISUALS then
	    const coneHandle: Instance? = source:FindFirstChild("_LR_DEBUG_CONE")

	    if coneHandle then
			coneHandle:Destroy()
		end
	end

	const box: BasePart? = world:get(entityId, components.SourceDebugBox)

	if box then
		box:Destroy()
	end

	world:delete(entityId)

	instanceToEntityId[sourceEntity] = nil

	return
end

--[=[
    Checks if the source is registered, and then returns its entity ID.

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function isSourceRegistered(source: BasePart): (boolean, jecs.Entity<nil>?)
    const entity: jecs.Entity<nil>? = instanceToEntityId[source]

    return entity ~= nil, entity
end

--[=[
	Public: Adds a vehicle

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function addSource(source: BasePart, model: Model?, isEnabled: (BasePart) -> boolean, getIntensity: (BasePart) -> number, getColor: (BasePart) -> vector, trackAncestry: boolean?): ()
	-- could have asserted but would flood the output with errors
	if source == nil then
		debugger.warn("Warning", "Vehicle (1st argument) CANNOT be nil.")
		return
	end

	if source and not source:IsA("BasePart") then
        debugger.warn("Warning", `[REGISTER] Source MUST be an BasePart; got {source.ClassName}`)
        return
	end

	if not source then
        return -- have to add this again because of type checker
	end

	if instanceToEntityId[source] then
		debugger.warn("Warning", "Vehicle already indexed in vehicle map.")
		return
	end

	if isEnabled == nil then
		debugger.warn("Warning", "Enabled (2nd argument) CANNOT be nil.")
		return
	end

	const entity: jecs.Entity<nil> = world:entity()

	world:set(entity, components.SourceInstance, source)
	instanceToEntityId[source] = entity

	sources.register(
		source,
		model,
		function() return source.Position + generalConfig.vehicleSeatOffset end,
		function() return source.CFrame.LookVector end,
		isEnabled, getIntensity, getColor
	)

	if constraints.LOOK_VECTOR_VISUALS then
	    const coneHandle: ConeHandleAdornment = Instance.new("ConeHandleAdornment")

		coneHandle.CFrame = CFrame.new(0, 0, -1)
		coneHandle.Height = 2
		coneHandle.AdornCullingMode = Enum.AdornCullingMode.Automatic
		coneHandle.Adornee = source
		coneHandle.Radius = 0.75
		coneHandle.Parent = source
		coneHandle.Name = "_LR_DEBUG_CONE"
	end

	if trackAncestry and trackAncestry == true then
	    if not trackedAncestryInstances[source] then
		    const connection: RBXScriptConnection = utils.trackAncestryRemoval(source, function()
			    trackedAncestryInstances[source] = nil
			    removeSource(source)
		    end)

		    scriptConnections[connection] = true
			trackedAncestryInstances[source] = true
	    end
	end

	if generalConfig.showRegisteredPrints == true then
	    debugger.shortPrint(`[REGISTER] Registered {source:GetFullName()}`)
	end

	return
end

--[=[
	Private: Clones a hybrid part
	@private

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function _cloneHybrid(part: BasePart): BasePart?
    local clone:BasePart? = nil

    if part:IsA("Part") then
        clone = partPool.Get() :: Part
        utils.copyPartProps(part, clone)
    else
        clone = part:Clone()
    end

    if not clone then return nil end

    clone:SetAttribute(reflectorConfig.hybridCloneAttributeName, true)

    CollectionService:RemoveTag(clone, reflectorConfig.tagName)

    if part:IsA("MeshPart") then
        const canKeepTexturesAttribute: boolean? = clone:GetAttribute(reflectorConfig.canHybridKeepTexturesAttribute)

        const canKeepTextureProperty: boolean =
            if typeof(canKeepTexturesAttribute) == "boolean"
                then canKeepTexturesAttribute
                else reflectorConfig.defaultHybridCanKeepTextures

        if not canKeepTextureProperty then
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

    if clone:IsA("UnionOperation") and canHybridKeepColors == false then
       clone.UsePartColor = true
    end

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

	utils.normalizeBaseColor(clone, false)
	return clone
end

--[=[
	Private: Handles a marking
	@private

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function _handleMarking(part: BasePart, noSplit: boolean?): ()
    local maxSize: number = reflectorConfig.maxMarkingPartSize
    const partSize: Vector3 = part.Size

    if reflectorConfig.splitMarkings == false or (noSplit ~= nil and noSplit == true) then
        const clone:BasePart? = _cloneHybrid(part)

        if not clone then return end

        clone.Name = reflectorConfig.hybridCloneName
        clone.Size = part.Size
        clone.CFrame = part.CFrame
        clone.Parent = part.Parent

        const entity: jecs.Entity<nil> = world:entity()

        world:set(entity, components.Reflector, clone)

        instanceToEntityId[clone] = entity

        grid.spawn(reflectorGrid, entity, clone.Position)
        return
    end

    const splitX: number, splitY: number, splitZ: number =
        math.max(1, math.ceil(partSize.X / maxSize)),
        math.max(1, math.ceil(partSize.Y / maxSize)),
        math.max(1, math.ceil(partSize.Z / maxSize))

	const segmentSize: Vector3 = Vector3.new(
		partSize.X / splitX,
		partSize.Y / splitY,
		partSize.Z / splitZ
	)

    for x: number = 1, splitX do
        for y: number = 1, splitY do
            for z: number = 1, splitZ do
                const clone:BasePart? = _cloneHybrid(part)

                if not clone then return end

                clone.Size = segmentSize * Vector3.new(1.1,1.1,1.1)

				const offsetX: number, offsetY: number, offsetZ: number =
			        (-partSize.X / 2) + (segmentSize.X / 2) + ((x - 1) * segmentSize.X),
					(-partSize.Y / 2) + (segmentSize.Y / 2) + ((y - 1) * segmentSize.Y),
					(-partSize.Z / 2) + (segmentSize.Z / 2) + ((z - 1) * segmentSize.Z)

				clone.Name = reflectorConfig.hybridCloneName
				clone.CFrame = part.CFrame * CFrame.new(offsetX, offsetY, offsetZ)
				clone.Parent = part.Parent

				const entity: jecs.Entity<nil> = world:entity()

				world:set(entity, components.Reflector, clone)

				instanceToEntityId[clone] = entity

				grid.spawn(reflectorGrid, entity, clone.Position)
            end
        end
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

	if not hasTag or isReflector_nontag then
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
	    const isMarking: boolean = reflectorConfig.isMarkingEnabled
			and attributes[reflectorConfig.markingAttributeName]

		if isMarking then
            _handleMarking(part, attributes[reflectorConfig.markingNoSplitAttribute])
		else
		    const clone:BasePart? = _cloneHybrid(part)

			if not clone then return end

			clone.Name = reflectorConfig.hybridCloneName
			clone.Transparency = 1
			clone.CanCollide = false
			clone.CanTouch = false
			clone.CanQuery = false
			clone.Parent = part.Parent

			const entity: jecs.Entity<nil> = world:entity()

			world:set(entity, components.Reflector, clone)
			instanceToEntityId[clone] = entity

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
		end
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
const function removeReflector(part: BasePart): ()
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
			if part:IsA("Part") then
                partPool.Return(part)
            else
                part:Destroy()
			end
		end
	end
end

--[=[
	Public: Adds a sign

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function addSign(part: Instance, rangeType: string?): ()
	if instanceToEntityId[part] then
		return
	end

	if not part:IsA("BasePart") then
        return
	end

	const entity: jecs.Entity<nil> = world:entity()

	world:set(entity, components.Sign, part)
	world:set(entity, components.SignInRange, (if rangeType ~= nil then rangeType else "near"):: types.RangeType)
	instanceToEntityId[part] = entity

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
const function removeSign(part: Instance): ()
	if instanceToEntityId[part] then
		const entity: jecs.Entity<nil>? = instanceToEntityId[part]
		if entity and world:contains(entity) then
			const signState: types.SignEntity? = world:get(entity, components.SignState)

			if signState then
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

	for entity: jecs.Entity<nil>, car:Instance in cachedQueries.SourceInstances do
		const DriveSeat: VehicleSeat? = car:FindFirstChildOfClass("VehicleSeat")

		if not DriveSeat then continue end

		const seatCF: CFrame = DriveSeat.CFrame
		const boxCF: CFrame = seatCF * signConfig.raycastBoxOffset

		if signConfig.isDebugBoxEnabled then
			local vehicleDebugBox: BasePart? = world:get(entity, components.SourceDebugBox)

			if not vehicleDebugBox then
				vehicleDebugBox = debugBoxTemplate:Clone()
				world:set(entity, components.SourceDebugBox, vehicleDebugBox)
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
			for _: number, part: BasePart in Folder:QueryDescendants("BasePart") do
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
		debugger.fatal("MassFatalInit","[REGISTER] 🔴 JECS (an Entity Component System) failed to load the world.")
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
		    const baseColor: vector = decalState.baseColor
			mainDecal.Color3 = Color3.new(baseColor.x, baseColor.y, baseColor.z)
		end
	end

	for entity: jecs.Entity<nil>, part: BasePart, state: types.ReflectorState in cachedQueries.Reflectors do
		const Color: Color3 = part.Color

		const newColor: vector = state.baseColor
		const newMaterial: Enum.Material = reflectorConfig.inactiveMaterial

		if state.lastMaterial ~= newMaterial then
			part.Material = newMaterial
			state.lastMaterial = newMaterial
		end

		if Color and not utils.areVectorsEqual(state.lastColor, newColor, 0.01) then
			part.Color = Color3.new(newColor.x, newColor.y, newColor.z)
			state.lastColor = newColor
		end

		if part:GetAttribute(reflectorConfig.hybridCloneAttributeName) then
			if part:IsA("Part") then
                partPool.Return(part)
            else
                part:Destroy()
			end
		end
	end

	if not config.SignConfig.debugBoxFolder and debugFolder then
		debugFolder:Destroy()
	else
		for entity: jecs.Entity<nil>, sourceDebugBox: BasePart in world:query(components.SourceDebugBox) do
			if sourceDebugBox then
				sourceDebugBox:Destroy()
			end
		end
	end

	grid.empty(reflectorGrid)
	grid.empty(signGrid)

	const toDelete: {jecs.Entity} = {}

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

	isSourceRegistered = isSourceRegistered,
	addSource = addSource,
	removeSource = removeSource,
	addReflector = addReflector,
	removeReflector = removeReflector,
	addSign = addSign,
	removeSign = removeSign,

	clearConnections = clearConnections,
	reset = reset,

	getPartsByRaycast = getPartsByRaycast,

})
