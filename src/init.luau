--!native
--!strict
-- USAGE: lightreflector.luau
-- Init module for Light Reflector. Handles boundaries and rendering, as well as vehicles.
-- Typing has been attempted but not complete

--[[
	Copyright (c) 2024-2026 Illinois_Roadbuff ("Rogue Jr") and Project Roadwork

	This Source Code Form is subject to the terms of the Mozilla Public
	License, v. 2.0. If a copy of the MPL was not distributed with this
	file, You can obtain one at https://mozilla.org/MPL/2.0/.

	VIEW README FILE FOR MORE INFORMATION LOCATED AT:
		LUAU: lightreflector/shared/readme.luau
		GIT: ./README.md

	GIT REPOSITORIES:
		Codeberg / Forgejo (main): https://codeberg.org/project-roadwork/light-reflector.git
		GitHub (Mirror): https://github.com/project-roadwork/light-reflector.git
]]

-- IMPORTANT: Services
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")  -- game.GetService(game, "ReplicatedStorage") is faster but breaks typing
local CollectionService: CollectionService = game:GetService("CollectionService")
local RunService: RunService = game:GetService("RunService")

-- IMPORTANT: Debugger and setup
local debugger = require("@self/shared/debugger")
local logs = require("@self/shared/logs")
local version = require("@self/shared/version")

debugger.set(`Light Reflector {version}`, logs.Ids::any, logs.URL)

-- IMPORTANT: RunContext Safety Net
debugger.assert(RunService:IsClient(), "RunContext", "Init module should be run from the client.")

-- IMPORTANT: Other Modules
local types = require("@self/shared/types")
local config = require("@self/shared/config")
local utils = require("@self/client/utils")
local dark = require("@self/client/dark")
local equations = require("@self/client/equations")
local sources = require("@self/client/sources")
local pool = require("@self/client/pool")

-- Variables
local registeredVehicles: types.VehicleMap = {}
local vehicleDebugBoxes: { [any]: BasePart } = {}
local currentDetectedParts: { [BasePart]: boolean } = {}

local surfaceGuisByPart: { [BasePart]: types.SurfaceGuiTemplate } = {}
local surfaceGuiStatesByPart: types.SurfaceGuiStates = {}
local reflectorsByPart = setmetatable({}, config.Constraints.KEYS)
local reflectorStatesByPart: types.ReflectorStates = setmetatable({}, config.Constraints.KEYS)
local cachedSignParts: { types.RangeType } = setmetatable({}, config.Constraints.KEYS)

local renderLoopThread: thread?, boundaryLoopThread: thread? = nil, nil
local isModuleStarting: boolean = false
local registeredReflectors: { [BasePart]: boolean } = {}
local overlapDetectionParams: OverlapParams = OverlapParams.new()
local detectedPartsThisFrame: { [BasePart]: boolean } = {}
local scriptConnections: { [RBXScriptConnection]: boolean } = {}

-- Debug Box Setup
local debugBoxTemplate:BasePart = Instance.new("Part") -- forced to do instance.new instead of nil or else the type solver is going into a panic attack
local debugFolder: Folder?

-- Pooler Safety Nets
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

	local surfaceGui:SurfaceGui = Instance.new("SurfaceGui")
	surfaceGui.Name = "SurfaceGui"
	surfaceGui.ZOffset = 3

	local imageLabel:ImageLabel = Instance.new("ImageLabel")
	imageLabel.Size = UDim2.fromScale(1,1)
	imageLabel.BackgroundTransparency = 1
	imageLabel.Parent = surfaceGui

	surfaceGui.Parent = surfaceGuiTemplate
	templateGui = surfaceGui
end

-- SurfaceGuiPool Setup
local SurfaceGuiPool = pool.new(templateGui,
	function(template: Instance): Instance
		local clone = template:Clone()

		return clone
	end,

	function(template: Instance)

	end, config.Constraints.SURFACE_GUI_MIN_POOL_SIZE, config.Constraints.SURFACE_GUI_MAX_POOL_SIZE) -- pool will warn ONCE if active parts exceed 350

-- Functions
--[=[
	Public: Adds a vehicle
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
local function RegisterVehicle(car: Instance, isEnabled: boolean | number): ()
	-- could have asserted but would flood the output with errors

	if car == nil then
		debugger.warn("Warning", "Vehicle (1st argument) CANNOT be nil.")
		return
	end

	if registeredVehicles[car] then
		debugger.warn("Warning", "Vehicle already indexed in vehicle map.")
		return
	end

	local seat = car:FindFirstChildOfClass("VehicleSeat")

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
				local v = isEnabled.Value
				return (type(v) == "boolean" and v) or (type(v) == "number" and v > 0)
			else
				return (type(isEnabled) == "boolean" and isEnabled) or (type(isEnabled) == "number" and isEnabled > 0)
			end
		end, 1
	)
end

--[=[
	Public: Removes a vehicle
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
local function UnregisterVehicle(car: types.Vehicle): ()
	if not registeredVehicles[car] then
		debugger.warn("Warning", "Cannot find vehicle in vehicle map.")
		return
	end

	local sourcesList = sources.list
	registeredVehicles[car] = nil

	for i = #sourcesList, 1, -1 do
		if sourcesList[i].Owner == car then
			debugger.print("Info", "Found car")
			table.remove(sourcesList, i)
			break
		end
	end

	local box = vehicleDebugBoxes[car]
	if box then
		box:Destroy()
		vehicleDebugBoxes[car] = nil
	end
end

--[=[
	Public: Processes reflectors and normalizes base color
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
local function RegisterReflector(part:BasePart): ()
	if config.ReflectorConfig.isReflector(part) or part:HasTag(config.ReflectorConfig.tagName) then
		registeredReflectors[part] = true
		utils.normalizeBaseColor(part)
	end
end

--[=[
	Public: Removes reflectors from the reflector rable
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
local function UnregisterReflector(part:BasePart): ()
	if config.ReflectorConfig.isReflector(part) or part:HasTag(config.ReflectorConfig.tagName) then
		registeredReflectors[part] = nil
	end
end

--[=[
	Private: Builds Part Cache

	@private
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
local function _cacheSignParts():  ()
	local isTagsEnabled = config.SignConfig.isTagsEnabled
	local tagName = config.SignConfig.tagName

	if isTagsEnabled then
		for _, part in CollectionService:GetTagged(tagName) do
			cachedSignParts[part::any] = "near" -- near and far range types does not really make a difference
		end

		if config.Constraints.IS_STREAMING_ENABLED then
			local instanceAddedSignal = CollectionService:GetInstanceAddedSignal(tagName):Connect(function(part:Instance)
				cachedSignParts[part::any] = "near"
			end)

			local instanceRemovedSignal = CollectionService:GetInstanceRemovedSignal(tagName):Connect(function(part:Instance)
				cachedSignParts[part::any] = nil
			end)

			scriptConnections[instanceAddedSignal] = true
			scriptConnections[instanceRemovedSignal] = true
		end

	else
		for _, folder in config.SignConfig.signsFolders do
			for _, part in folder:GetDescendants() do
				cachedSignParts[part] = "near"
			end

			if config.Constraints.IS_STREAMING_ENABLED then
				local descendantAddedSignal = folder.DescendantAdded:Connect(function(part:Instance)
					cachedSignParts[part::any] = "near"
				end)

				local descendantRemovingSignal = folder.DescendantRemoving:Connect(function(part:Instance)
					cachedSignParts[part::any] = nil
				end)

				scriptConnections[descendantAddedSignal] = true
				scriptConnections[descendantRemovingSignal] = true
			end
		end
	end
end

--[=[
	Private: Resets and returns SurfaceGui with pool check

	@private
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
local function _resetSurfaceGui(gui: types.SurfaceGuiTemplate)
	if not gui then return end

	if gui.Parent == nil and gui.Enabled == false then
		return
	end

	--if gui:GetAttribute("InPool") == true then return end

	gui.Enabled = false
	gui.Adornee = nil
	gui.Parent = nil

	gui.Brightness = 0
	gui.LightInfluence = 1
	gui.ImageLabel.ImageTransparency = 1
	-- ^ reset the template so that signs do not flicker once indexed

	--gui:SetAttribute("InPool", true) -- InPool attribute is unreliable

--[[	for part, state in surfaceGuiStatesByPart do
		if state.gui == gui then
			surfaceGuiStatesByPart[part] = nil
		end
	end
	for part, trackedGui in surfaceGuisByPart do
		if trackedGui == gui then
			surfaceGuisByPart[part] = nil
		end
	end]] -- Rmoved to prevent return duplication. This inactive code block is kept here for reference.

	local success:boolean, response:string? = SurfaceGuiPool:ReturnObject(gui)
	-- in the pool module, I made it so that :ReturnObject has similar returns as a pcall

	if not success then
		gui:Destroy() -- destroy the gui instead
		debugger.warn("Warning", response)
	end
end

--[=[
	Private: Inserts parts into a table via raycast

	@private
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
local function _collectPartsByRaycast(): {[BasePart]: types.RangeType}
	local partsDictionary: {[BasePart]: types.RangeType} = {}

	for car: Instance, boolean in registeredVehicles do
		local DriveSeat = car:FindFirstChildOfClass("VehicleSeat")

		if not DriveSeat then continue end

		local seatCF = DriveSeat.CFrame
		local boxCF = seatCF * config.SignConfig.raycastBoxOffset

		if config.SignConfig.isDebugBoxEnabled then
			local vehicleDebugBox = vehicleDebugBoxes[car]

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
		end
		for _, part in config.General.GetPartsInBox(workspace, seatCF * config.SignConfig.raycastBoxOffsetFar, config.SignConfig.raycastBoxSizeFar, overlapDetectionParams) do
			if not partsDictionary[part] then partsDictionary[part] = "far" end
		end
	end

	return partsDictionary
end

--[=[
	Private: Starts reflector indexing and processing

	@private
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
local function _cacheReflectors(): ()
	if config.ReflectorConfig.isTagsEnabled then
		for i,part in CollectionService:GetTagged(config.ReflectorConfig.tagName) do
			RegisterReflector(part::any)
		end

		local instanceAddedSignal = CollectionService:GetInstanceAddedSignal(config.ReflectorConfig.tagName):Connect(RegisterReflector)
		local instanceRemovedSignal = CollectionService:GetInstanceRemovedSignal(config.ReflectorConfig.tagName):Connect(UnregisterReflector)

		scriptConnections[instanceAddedSignal] = true
		scriptConnections[instanceRemovedSignal] = true
	else
		for i,Folder in config.ReflectorConfig.reflectorsFolder do
			for i,part in Folder:GetDescendants() do
				RegisterReflector(part)
			end

			local descendantAddedSignal = Folder.DescendantAdded:Connect(RegisterReflector::any)
			local DescendantRemovingSignal = Folder.DescendantRemoving:Connect(UnregisterReflector::any)

			scriptConnections[descendantAddedSignal] = true
			scriptConnections[DescendantRemovingSignal] = true
		end
	end
end

--[=[
	Private: Boundary / zone detection loop

	@private
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
local function _runBoundaryDetectionLoop(): ()
	-- pcall replaced with pcallRetry used in the Start function
	local partsDictionary: {[BasePart]: types.RangeType}
	if not config.Constraints.IS_RAYCAST_ENABLED then
		partsDictionary = {}
		-- OLD REFERENCE: partsDictionary = cachedSignParts
		-- ^ Cacheparts is a weak table, so probably better to clone everything to create an interm (temp) strong ref?
	end

	while true do
		task.wait(utils.adaptiveWait(config.Constraints.BOUNDARY_MIN_FPS,
			config.Constraints.BOUNDARY_MAX_FPS,
			utils.getFastestDriveSeat(registeredVehicles)))
		-- ^ adaptive waiting based on vehicle speed. This only indexes parts in the area rather than renders,
		--    so the FPS numbers should be low


		table.clear(detectedPartsThisFrame)
		table.clear(reflectorsByPart)

		if config.Constraints.IS_RAYCAST_ENABLED == false then
			table.clear(partsDictionary)
			for part, range in cachedSignParts do
				partsDictionary[part] = range
			end
		else
			partsDictionary = _collectPartsByRaycast()
		end

		if not sources.anyActive() or not dark() then
			if debugBoxTemplate then debugBoxTemplate.Transparency = 0.95 end
			for part, state in surfaceGuiStatesByPart do
				state.targetTransparency = 1
				state.targetBrightness = 0
				state.targetLight = 1
			end

			for part, state in reflectorStatesByPart do
				state.currentIntensity = 0
				state.targetIntensity = 0
				state.isActive = false

				if state.baseColor then
					part.Color = state.baseColor
					part.Material = config.ReflectorConfig.inactiveMaterial
				end
			end
			continue
		end

		for part in registeredReflectors do
			if config.ReflectorConfig.isEnabled == false then break end
			if not part then continue end

			reflectorsByPart[part] = true

			local state = reflectorStatesByPart[part]
			if not state then
				state = {
					currentIntensity = 0,
					targetIntensity = 0,
					baseColor = part:GetAttribute("BaseColor"),
					isActive = false,
					lastMaterial = Enum.Material.Rock,
					lastColor = Color3.fromRGB(1,2,3),

				}:: types.ReflectorState
				reflectorStatesByPart[part] = state
			end

			state.targetIntensity = equations.computeReflectorIntensity(part, sources.list)
		end

		for part, rangeType in partsDictionary do
			if config.SignConfig.isEnabled == false then break end
			if not sources.anyActive() or not dark() then
				continue
			end

			local mainDecal = part:FindFirstChild(config.SignConfig.mainDecalName)
			-- ^ unfortunately one cannot set instances as attributes
			if not mainDecal then
				for _, decal in part:GetChildren() do
					if decal:IsA("Decal") then
						local name = decal.Name

						if config.SignConfig.isMainDecal(decal) then
							mainDecal = decal
							decal.Name = config.SignConfig.mainDecalName
							break
						end
					end
				end
			end

			if not mainDecal then continue end

			if part:GetAttribute("IsFixed") ~= true then
				utils.fixPartOrientation(part, mainDecal)
			end
			local fadeData = equations.computeSignIntensity(part, mainDecal, "near", sources.list)

			if fadeData.transparency >= config.SignConfig.inactiveTransparencyThreshold  then
				continue
			end

			local gui: types.SurfaceGuiTemplate = surfaceGuisByPart[part]

			if not gui then
				gui = SurfaceGuiPool:GetObject() :: types.SurfaceGuiTemplate

				if gui == nil then debugger.warn("Warning", "Pool contains nil instances.") continue end

				gui.Face = mainDecal.Face
				gui.Adornee = part
				gui.Parent = part
				gui.Enabled = true
				gui.ImageLabel.Image = mainDecal.Texture
				gui.ImageLabel.ImageTransparency = mainDecal.Transparency
				surfaceGuisByPart[part] = gui
			end

			if gui.Parent == nil then
				gui.Face = mainDecal.Face
				gui.Parent = part
				gui.Adornee = part
				gui.Enabled = true
				gui.ImageLabel.Image = mainDecal.Texture
				gui.ImageLabel.ImageTransparency = mainDecal.Transparency
			end

			local state = surfaceGuiStatesByPart[part]
			if not state then
				state = {
					gui = gui,
					currentTransparency = 1,
					currentBrightness = 0,
					currentLight = 1,
					isActive = true,
					isPendingRemoval = false,
				}:: types.SurfaceGuiState -- forced to do this or else type errors
				surfaceGuiStatesByPart[part] = state
			end

			state.targetTransparency = fadeData.transparency
			state.targetBrightness = fadeData.brightness
			state.targetLight = fadeData.light

			detectedPartsThisFrame[part] = true
		end

		for part, state in surfaceGuiStatesByPart do
			if state and state.isPendingRemoval and state.gui then
				_resetSurfaceGui(state.gui)
				surfaceGuiStatesByPart[part] = nil
				surfaceGuisByPart[part] = nil
			end
		end

		for part, gui in surfaceGuisByPart do
			if not part:IsDescendantOf(workspace) then
				_resetSurfaceGui(gui)
				surfaceGuisByPart[part] = nil
				surfaceGuiStatesByPart[part] = nil
			end
		end

		currentDetectedParts = detectedPartsThisFrame
	end
end

--[=[
	Private: Rendering loop

	@private
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
local function _runRenderLoop(): ()
	-- pcall replaced with pcallRetry used in the Start function
	while true do
		local deltaTime = utils.adaptiveWait(config.Constraints.RENDER_MIN_FPS, config.Constraints.RENDER_MAX_FPS,
			utils.getFastestDriveSeat(registeredVehicles)) -- adaptive waiting based on fastest vehicle speed

		-- this should be in a higher FPS since it renders the animations

		task.wait(deltaTime)

		local lerpSpeed:number = config.ReflectorConfig.lerpSpeed

		for part, state in reflectorStatesByPart do
			local Material = part.Material
			local Color = part.Color

			if config.ReflectorConfig.isEnabled == false then break end

			if not reflectorsByPart[part] then
				local BaseMaterial = config.ReflectorConfig.inactiveMaterial

				if state.baseColor then
					if state.lastMaterial ~= BaseMaterial then
						part.Material = BaseMaterial
						state.lastMaterial = BaseMaterial
					end

					if not utils.areColorsEqual(state.lastColor, state.baseColor, 0.01) then
						part.Color = state.baseColor
						state.lastColor = state.baseColor
					end
				end
				reflectorStatesByPart[part] = nil
				continue
			end

			state.currentIntensity +=
				(state.targetIntensity - state.currentIntensity)
				* math.clamp(lerpSpeed * deltaTime, 0, 1)

			if state.isActive == nil then
				state.isActive = false
			end

			if state.isActive then
				if state.currentIntensity <= config.ReflectorConfig.inactivateIntensityThreshold then
					state.isActive = false
				end
			else
				if state.currentIntensity >= config.ReflectorConfig.activateIntensityThreshold then
					state.isActive = true
				end
			end

			local intensity = state.currentIntensity

			local newColor
			local newMaterial
			-- ^ variables to reduce .Material and .Color calls
			--   Will only be changed if the material/color is not the same as the current one

			if intensity >= config.ReflectorConfig.neonActivationIntensity then
				newMaterial = config.ReflectorConfig.activeMaterial

				local baseColor: Color3 = state.baseColor
				local minScale = config.ReflectorConfig.minBrightness / 255
				local maxScale = config.ReflectorConfig.maxBrightness / 255

				local scale = minScale + (maxScale - minScale) * intensity

				local r = math.clamp(baseColor.R * scale, 0, 1)
				local g = math.clamp(baseColor.G * scale, 0, 1)
				local b = math.clamp(baseColor.B * scale, 0, 1)

				newColor = Color3.new(r, g, b)

			elseif intensity > 0 then
				newMaterial = Enum.Material.Plastic

				newColor = state.baseColor:Lerp(
					config.ReflectorConfig.partialDimmingBaseColor,
					intensity * 0.5
				)
			else
				newMaterial = config.ReflectorConfig.inactiveMaterial
				newColor = state.baseColor
			end

			if state.lastMaterial ~= newMaterial then
				part.Material = newMaterial
				state.lastMaterial = newMaterial
			end

			if not utils.areColorsEqual(state.lastColor, newColor, 0.01) then
				part.Color = newColor
				state.lastColor = newColor
			end
		end

		lerpSpeed = config.SignConfig.lerpSpeed

		for part, state in surfaceGuiStatesByPart do
			if config.SignConfig.isEnabled == false then break end

			local gui = state.gui
			if gui and gui.Parent then


				local inPart = currentDetectedParts[part] ~= nil
				if inPart then
					state.currentTransparency += (state.targetTransparency - state.currentTransparency) * math.clamp(lerpSpeed * deltaTime, 0, 1)
					state.currentBrightness += (state.targetBrightness - state.currentBrightness) * math.clamp(lerpSpeed * deltaTime, 0, 1)
					state.currentLight += (state.targetLight - state.currentLight) * math.clamp(lerpSpeed * deltaTime, 0, 1)
				else
					state.currentTransparency += (1 - state.currentTransparency) * math.clamp(lerpSpeed * deltaTime, 0, 1)
					state.currentBrightness += (0 - state.currentBrightness) * math.clamp(lerpSpeed * deltaTime, 0, 1)
					state.currentLight += (1 - state.currentLight) * math.clamp(lerpSpeed * deltaTime, 0, 1)

					if state.currentTransparency >= config.SignConfig.inactiveTransparencyThreshold then
						state.isPendingRemoval = true
					end
				end

				gui.ImageLabel.ImageTransparency = state.currentTransparency
				gui.Brightness = state.currentBrightness
				gui.LightInfluence = state.currentLight

				local num = config.SignConfig.inactiveTransparencyThreshold

				if state.currentTransparency >= num then
					state.isActive = false
					state.isPendingRemoval = true
				end
			end
		end
	end
end

--[=[
	Public: Starts the module

	```lua
	LightReflector.Start()
	```

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
local function Start() : ()
	debugger.assert(not isModuleStarting, "AlreadyStarting")

	isModuleStarting = true

	table.freeze(config.Constraints)

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

	if not config.Constraints.IS_RAYCAST_ENABLED then _cacheSignParts() end

	overlapDetectionParams.FilterType = Enum.RaycastFilterType.Include
	overlapDetectionParams.FilterDescendantsInstances = config.SignConfig.signsFolders :: any

	_cacheReflectors()

	boundaryLoopThread = task.defer(utils.pcallRetry, _runBoundaryDetectionLoop, config.Constraints.MAX_PCALL_RETRIES)
	renderLoopThread = task.defer(utils.pcallRetry, _runRenderLoop, config.Constraints.MAX_PCALL_RETRIES)
	-- ^ two separate loops since both are in different frequencies

	debugger.print("Info","Successfully loaded!")
end

--[=[
	Public: Cleans up the module

	```lua
	LightReflector.Cleanup()
	```

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
local function Cleanup(): ()
	debugger.assert(isModuleStarting, "Warning", "Cleanup called before Start().")

	debugger.print("Info","Cleaning up!")

	for scriptSignal:RBXScriptSignal, boolean:boolean in scriptConnections do
		scriptSignal:Disconnect()
		scriptConnections[scriptSignal] = nil
	end

	task.cancel(boundaryLoopThread :: any)
	task.cancel(renderLoopThread :: any)

	for part:BasePart, state in surfaceGuiStatesByPart do
		local gui = state.gui
		if gui then
			_resetSurfaceGui(gui)
		end
	end

	for part:BasePart, gui in surfaceGuisByPart do
		if gui and gui.Parent then
			_resetSurfaceGui(gui)
		end
	end

	for part:BasePart, state in reflectorStatesByPart do
		local Material = part.Material
		local Color = part.Color

		local newColor = state.baseColor
		local newMaterial = config.ReflectorConfig.inactiveMaterial

		if state.lastMaterial ~= newMaterial then
			part.Material = newMaterial
			state.lastMaterial = newMaterial
		end

		if Color and not utils.areColorsEqual(state.lastColor, newColor, 0.01) then
			part.Color = newColor
			state.lastColor = newColor
		end
	end

	if not config.SignConfig.debugBoxFolder and debugFolder then
		debugFolder:Destroy()
	else
		for vehicle, boolean in registeredVehicles do
			local vehicleDebugBox = vehicleDebugBoxes[vehicle]

			if vehicleDebugBox then
				vehicleDebugBox:Destroy()
			end

			vehicleDebugBoxes[vehicle] = nil
		end
	end

	table.clear(surfaceGuiStatesByPart)
	table.clear(currentDetectedParts)
	table.clear(surfaceGuisByPart)
end

-- Return public variables and API
return table.freeze({
	Start = Start,
	RegisterVehicle = RegisterVehicle,
	UnregisterVehicle = UnregisterVehicle,
	Cleanup = Cleanup,
	AssignConfiguration = utils.assignConfiguration,
	RegisterReflector = RegisterReflector,
	UnregisterReflector = UnregisterReflector,
	surfaceGuiStatesByPart = surfaceGuiStatesByPart,
	reflectorStatesByPart = reflectorStatesByPart
})
