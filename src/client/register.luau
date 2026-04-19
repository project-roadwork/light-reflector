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
const types: {} = require("../shared/types")
const config: types.Configuration = require("../shared/config")
const utils: types.Utils = require("../client/utils")
const sources: types.SourcesModule = require("../client/sources")
const grid: types.GridModule = require("../client/grid")

-- Reflector Grid
const reflectorGrid: types.Grid = grid.newGrid(1900)

-- SurfaceGui Object Pool
const surfaceGuiPool: types.Pool = utils.initPool()

-- Tables
const vehicleDebugBoxes: { [any]: BasePart } = {}
const registeredVehicles: types.VehicleMap = {}
const registeredReflectors: { [BasePart]: boolean } = {}
const signEntitiesByPart: types.SignEntitiesByPart = {}

const baseConfig = config.getConfig()
const constraints = baseConfig.Constraints
const signConfig = baseConfig.SignConfig

const reflectorStatesByPart: setmetatable<{ [BasePart]: types.ReflectorState }, typeof(constraints.KEYS)>
	= setmetatable({}, constraints.KEYS)

const registeredSigns: setmetatable<{ [BasePart]: types.RangeType }, typeof(constraints.KEYS)>
	= setmetatable({}, constraints.KEYS)

const scriptConnections: { [RBXScriptConnection]: boolean } = {}
const trackedAnsestryInstances: { [Instance]: boolean } = {}

-- Debug Box Setup
const debugBoxTemplate:BasePart = Instance.new("Part") -- forced to do instance.new instead of nil or else the type solver is going into a panic attack
local debugFolder: Folder?

-- Miscellaneous
const abs: (number) -> number = math.abs


-- Raycast Setup
const overlapDetectionParams: OverlapParams = OverlapParams.new()

overlapDetectionParams.FilterType = Enum.RaycastFilterType.Include
overlapDetectionParams.FilterDescendantsInstances = signConfig.signsFolders :: any

--[=[
	Public: Removes a vehicle
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function unregisterVehicle(car: types.Vehicle & Instance): ()
	if not registeredVehicles[car] then
		debugger.warn("Warning", "Cannot find vehicle in vehicle map.")
		return
	end

	const sourcesList: types.SourceList = sources.list
	registeredVehicles[car] = nil

	for i = #sourcesList, 1, -1 do
		if sourcesList[i].Owner == car then
			debugger.print("Info", "Found car")
			table.remove(sourcesList, i)
			break
		end
	end

	const box: BasePart = vehicleDebugBoxes[car]
	if box then
		box:Destroy()
		vehicleDebugBoxes[car] = nil
	end


end

--[=[
	Public: Adds a vehicle
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function registerVehicle(car: Instance & types.Vehicle, isEnabled: (Instance) -> boolean, getIntensity: (Instance) -> number): ()
	const config = config.getConfig()
	-- could have asserted but would flood the output with errors

	if car == nil then
		debugger.warn("Warning", "Vehicle (1st argument) CANNOT be nil.")
		return
	end

	if registeredVehicles[car] then
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

	registeredVehicles[car] = true

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
		const connection: RBXScriptConnection = utils.trackAnsestryRemoval(car, function()
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
	const config = config.getConfig()
	const reflectorConfig: typeof(config.ReflectorConfig) = config.ReflectorConfig

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
			registeredReflectors[clone] = true
			utils.normalizeBaseColor(clone, false) -- setting the second argument to false just sets the baseColor attribute

			if not trackedAnsestryInstances[clone] then
				const connection: RBXScriptConnection = utils.trackAnsestryRemoval(clone, function()
					--grid.remove(part, lastPosition)
					trackedAnsestryInstances[clone] = nil
					registeredReflectors[clone] = nil
					const state: types.ReflectorState = reflectorStatesByPart[part]
					if state then
						grid.remove(reflectorGrid, part, state.CFrame.Position)
						reflectorStatesByPart[part] = nil
					else
						grid.remove(reflectorGrid, part, part.Position)
					end
				end)

				scriptConnections[connection] = true
				trackedAnsestryInstances[clone] = true
			end

			grid.spawn(reflectorGrid, clone, clone.Position)
		else
			registeredReflectors[part] = true
			utils.normalizeBaseColor(part, true)

			if not trackedAnsestryInstances[part] then
				const connection = utils.trackAnsestryRemoval(part, function()

					trackedAnsestryInstances[part] = nil
					registeredReflectors[part] = nil
					const state: types.ReflectorState = reflectorStatesByPart[part]

					if state then
						grid.remove(reflectorGrid,part, state.CFrame.Position)
						reflectorStatesByPart[part] = nil
					else
						grid.remove(reflectorGrid,part, part.Position)
					end

				end)

				scriptConnections[connection] = true
				trackedAnsestryInstances[part] = true
			end

			grid.spawn(reflectorGrid, part, part.Position)
		end
	end
end


--[=[
	Public: Removes reflectors from the reflector rable
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function unregisterReflector(part:BasePart): ()
	const config = config.getConfig()
	const reflectorConfig: typeof(config.ReflectorConfig) = config.ReflectorConfig

	if reflectorConfig.isReflector(part) or part:HasTag(reflectorConfig.tagName) then
		registeredReflectors[part] = nil

		if part:GetAttribute(reflectorConfig.hybridCloneAttributeName) then
			part:Destroy()
		end
	end
end

const function registerSign(part:Instance, rangeType: string?): ()
	registeredSigns[part::any] = if rangeType ~= nil then rangeType else "near" -- near and far range types does not really make a difference

	if part:IsA("BasePart") then

		if not trackedAnsestryInstances[part] then
			const connection: RBXScriptConnection = utils.trackAnsestryRemoval(part, function()
				trackedAnsestryInstances[part] = nil

				const entity: types.SignEntity = signEntitiesByPart[part]

				if entity then
					signEntitiesByPart[part] = nil
				end

				registeredSigns[part] = nil
			end)

			scriptConnections[connection] = true
			trackedAnsestryInstances[part] = true
		end
	end

end

const function unregisterSign(part:BasePart): ()
	if registeredSigns[part::any] then
		registeredSigns[part::any] = nil
	end
end

--[=[
	Private: Builds Part Cache

	@private
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function _cacheSigns():  ()
	const config = config.getConfig()

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
		for _, folder in config.SignConfig.signsFolders do
			for _, part:BasePart in folder:GetDescendants() do
				registerSign(part)
			end

			if config.Constraints.IS_STREAMING_ENABLED then
				const descendantAddedSignal:RBXScriptConnection = folder.DescendantAdded:Connect(function(part)
					registerSign(part) -- cannot do :Connect(registerSign) or else it would cause type issues
				end)

				const descendantRemovingSignal:RBXScriptConnection = folder.DescendantRemoving:Connect(function(part)
					registerSign(part)
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
	const config = config.getConfig()
	const partsDictionary: {[BasePart]: types.RangeType} = {}

	for car: Instance, _: boolean in registeredVehicles do
		const DriveSeat: VehicleSeat? = car:FindFirstChildOfClass("VehicleSeat")

		if not DriveSeat then continue end

		const seatCF: CFrame = DriveSeat.CFrame
		const boxCF: CFrame = seatCF * config.SignConfig.raycastBoxOffset

		if config.SignConfig.isDebugBoxEnabled then
			local vehicleDebugBox: BasePart = vehicleDebugBoxes[car]

			if not vehicleDebugBox then
				vehicleDebugBox = debugBoxTemplate:Clone()
				vehicleDebugBoxes[car] = vehicleDebugBox
			end

			vehicleDebugBox.CFrame = boxCF
			vehicleDebugBox.Transparency = config.SignConfig.debugBoxTransparency
			vehicleDebugBox.Parent = debugFolder
		end

		for _, part in config.General.GetPartsInBox(workspace, seatCF * config.SignConfig.raycastBoxOffsetNear, config.SignConfig.raycastBoxSizeNear, overlapDetectionParams) do
			partsDictionary[part] = "near"

			if not trackedAnsestryInstances[part] then

				const connection: RBXScriptConnection = utils.trackAnsestryRemoval(part, function()
					trackedAnsestryInstances[part] = nil
					const entity: types.SignEntity = signEntitiesByPart[part]

					if entity then
						signEntitiesByPart[part] = nil
					end
				end)

				scriptConnections[connection] = true
				trackedAnsestryInstances[part] = true
			end


		end
		for _, part in config.General.GetPartsInBox(workspace, seatCF * config.SignConfig.raycastBoxOffsetFar, config.SignConfig.raycastBoxSizeFar, overlapDetectionParams) do
			--if not partsDictionary[part] then partsDictionary[part] = "far" end

			partsDictionary[part] = "far"

			if not trackedAnsestryInstances[part] then

				const connection: RBXScriptConnection = utils.trackAnsestryRemoval(part, function()
					trackedAnsestryInstances[part] = nil
					const entity: types.SignEntity = signEntitiesByPart[part]

					if entity then
						signEntitiesByPart[part] = nil
					end
				end)

				scriptConnections[connection] = true
				trackedAnsestryInstances[part] = true
			end
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
	const config = config.getConfig()
	const reflectorConfig: typeof(config.ReflectorConfig) = config.ReflectorConfig

	if reflectorConfig.isTagsEnabled then
		for _, part:Instance in CollectionService:GetTagged(reflectorConfig.tagName) do
			registerReflector(part)
		end

		const instanceAddedSignal:RBXScriptConnection = CollectionService:GetInstanceAddedSignal(reflectorConfig.tagName):Connect(registerReflector)
		const instanceRemovedSignal:RBXScriptConnection = CollectionService:GetInstanceRemovedSignal(reflectorConfig.tagName):Connect(unregisterReflector)

		scriptConnections[instanceAddedSignal] = true
		scriptConnections[instanceRemovedSignal] = true
	else
		for _, Folder in reflectorConfig.reflectorsFolder do
			for _, part:Instance in Folder:GetDescendants() do
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
	const config = config.getConfig()

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
	Public: Disconnects the connections in the table 'scriptConnections'
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function clearConnections()
	for scriptSignal:RBXScriptSignal, boolean:boolean in scriptConnections do
		if not scriptSignal then
			continue
		end

		scriptSignal:Disconnect()
		scriptConnections[scriptSignal] = nil
	end

	table.clear(scriptConnections)
end

const function start()
	const config = config.getConfig()

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
const function reset()
	const config = config.getConfig()
	const reflectorConfig: typeof(config.ReflectorConfig) = config.ReflectorConfig

	for part:BasePart, entity: types.SignEntity in signEntitiesByPart do
		const surfaceGuiState: types.SurfaceGuiState? = entity.surfaceGuiState
		const decalState: types.DecalState? = entity.decalState
		const mainDecal: Decal? = entity.mainDecal

		if surfaceGuiState and surfaceGuiState.gui then
			utils.resetSurfaceGui(surfaceGuiPool, surfaceGuiState.gui)
		end

		if decalState and mainDecal then
			mainDecal.Color3 = decalState.baseColor
		end
	end

	for part:BasePart, state: types.ReflectorState in reflectorStatesByPart do
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

		registeredReflectors[part] = nil
		reflectorStatesByPart[part] = nil
	end

	if not config.SignConfig.debugBoxFolder and debugFolder then
		debugFolder:Destroy()
	else
		for vehicle, boolean in registeredVehicles do
			const vehicleDebugBox = vehicleDebugBoxes[vehicle]

			if vehicleDebugBox then
				vehicleDebugBox:Destroy()
			end

			vehicleDebugBoxes[vehicle] = nil
		end
	end

	grid.empty(reflectorGrid)

	table.clear(registeredVehicles)
	table.clear(registeredReflectors)
	table.clear(reflectorStatesByPart)
	table.clear(vehicleDebugBoxes)
	table.clear(signEntitiesByPart)
	table.clear(trackedAnsestryInstances)
end

-- Return API and variables
return table.freeze({
	Name = "register",

	start = start,

	reflectorGrid = reflectorGrid,
	registeredVehicles = registeredVehicles,
	registeredReflectors = registeredReflectors,
	registeredSigns = registeredSigns,
	signEntitiesByPart = signEntitiesByPart,
	reflectorStatesByPart = reflectorStatesByPart,
	debugBoxTemplate = debugBoxTemplate,
	surfaceGuiPool = surfaceGuiPool,

	registerVehicle = registerVehicle,
	unregisterVehicle = unregisterVehicle,
	registerReflector = registerReflector,
	unregisterReflector = unregisterReflector,

	clearConnections = clearConnections,
	reset = reset,

	scriptConnections = scriptConnections,
	getPartsByRaycast = getPartsByRaycast,

}) :: types.Register
