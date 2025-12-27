--!native
--!strict
-- USAGE: lightreflector.luau
-- Init module for Light Reflector. Handles boundaries and rendering, as well as vehicles.

--[[
	Copyright (c) 2024-2026 Project Roadwork and Contributors

	Licensed under the Apache License, Version 2.0 (the "License");
	you may not use this file except in compliance with the License.
	You may obtain a copy of the License at

 	   http://www.apache.org/licenses/LICENSE-2.0

	Unless required by applicable law or agreed to in writing, software
	distributed under the License is distributed on an "AS IS" BASIS,
	WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied.
	See the License for the specific language governing permissions and
	limitations under the License.

	VIEW README FILE FOR MORE INFORMATION LOCATED AT:
		LUAU: lightreflector/shared/readme.luau
		GIT: ./README.md

	GIT REPOSITORIES:
		Codeberg / Forgejo (main): https://codeberg.org/project-roadwork/light-reflector.git
		GitHub (Mirror): https://github.com/project-roadwork/light-reflector.git
]]

-- IMPORTANT: Services
local Lighting: Lighting = game:GetService("Lighting") -- game.GetService(game, "Lighting") is faster but breaks typing
local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local CollectionService: CollectionService = game:GetService("CollectionService")
local RunService: RunService = game:GetService("RunService")

-- IMPORTANT: Debugger and setup
local debugger = require("@self/shared/debugger")
local logs = require("@self/shared/logs")
local ver = require("@self/shared/ver")

debugger.set(`Light Reflector {ver}`, logs.Ids::any, logs.URL)

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
local Vehicles: types.VehicleMap = {}
local currentParts: { [BasePart]: true } = {}

local SurfaceGuisInBox = {}
local SurfaceGuiStates: types.SurfaceGuiStates = {}
local ReflectorsisInBox = setmetatable({}, config.Keys)
local ReflectorStates: types.ReflectorStates = setmetatable({}, config.Keys)
local CachedParts: { types.RangeType } = setmetatable({}, config.Keys)

local RenderThread: any, BoundaryThread: any = nil, nil
local Starting: boolean = false
local PavementReflectors = {}
local overlapParams: OverlapParams = OverlapParams.new()

-- Debug Box Setup
local debugBox = Instance.new("Part") -- forced to do instance.new instead of nil or else the type solver is going into a panic attack

if config.SignConfig.DebugBoundary then
	local DebugFolder = config.SignConfig.DebugBoxFolder
		or Instance.new("Folder")

	DebugFolder.Parent = workspace

	debugBox.Anchored = true
	debugBox.CanCollide = false
	debugBox.CastShadow = false
	debugBox.Transparency = config.SignConfig.DebugBoxTransparency
	debugBox.Color = config.SignConfig.DebugBoxColor
	debugBox.Material = config.SignConfig.DebugBoxMaterial
	debugBox.Name = config.SignConfig.DebugBoxName
	debugBox.Size = config.SignConfig.BoxSizeNear
	debugBox.Parent = DebugFolder
end

-- Pooler Safety Nets
local SurfaceGuiTemplate = ReplicatedStorage:FindFirstChild("ReflectorTemplate")

if not SurfaceGuiTemplate then
	debugger.warn("InitWarning","SurfaceGui template does not exist! Using safety net and creating SurfaceGui template...")
	SurfaceGuiTemplate = Instance.new("Folder")
	SurfaceGuiTemplate.Name = "ReflectorTemplate"
	SurfaceGuiTemplate.Parent = ReplicatedStorage
end

local TemplateGui = SurfaceGuiTemplate:FindFirstChildOfClass("SurfaceGui")
if not TemplateGui then
	debugger.warn("InitWarning","SurfaceGui does not exist in the template! Using safety net and creating SurfaceGui...")

	local SurfaceGui = Instance.new("SurfaceGui")
	SurfaceGui.Name = "SurfaceGui"
	SurfaceGui.ZOffset = 3

	local ImageLabel = Instance.new("ImageLabel")
	ImageLabel.Size = UDim2.fromScale(1,1)
	ImageLabel.BackgroundTransparency = 1
	ImageLabel.Parent = SurfaceGui

	SurfaceGui.Parent = SurfaceGuiTemplate
	TemplateGui = SurfaceGui
end

-- SurfaceGuiPool Setup
local SurfaceGuiPool = pool.new(SurfaceGuiTemplate.SurfaceGui,
	function(a0: Instance): Instance
		--	print(a0:GetFullName())
		local clone = a0:Clone()
		return clone
	end,

	function(a0: Instance)
		--	print("reset!")
		a0.Parent = nil
	end, config.SurfaceGuiMinPoolSize, config.SurfaceGuiMaxPoolSize) -- pool will warn ONCE if active parts exceed 350

--[=[
	Public: Adds a vehicle
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
local function AddVehicle(car: types.Vehicle, enabled: boolean | number): ()

	-- could have asserted but would flood the output with errors

	if car == nil then
		debugger.warn("Warning", "Vehicle (1st argument) CANNOT be nil.")
		return
	end

	if Vehicles[car] then
		debugger.warn("Warning", "Vehicle already indexed in vehicle map.")
		return
	end

	local seat = car:FindFirstChildOfClass("VehicleSeat")

	if not seat then
		debugger.warn("Warning", "Failed to find VehicleSeat in vehicle (1st argument). Did you ensure that the VehicleSeat instance exists before calling AddVehicle?")
		return
	end

	if enabled == nil then
		debugger.warn("Warning", "Enabled (2nd argument) CANNOT be nil.")
		return
	end

	if type(enabled) ~= "boolean"
		and type(enabled) ~= "number"
		and not (typeof(enabled) == "Instance" and enabled:IsA("ValueBase")) then

		debugger.warn("Warning", "Enabled (2nd argument) MUST be a boolean, number, or a ValueBase like IntValue, etc.")
		return
	end

	Vehicles[car] = true

	sources.register(
		car,
		function() return seat.Position + config.VehicleSeatOffset end,
		function() return seat.CFrame.LookVector end,
		function()
			if typeof(enabled) == "Instance" and enabled:IsA("ValueBase") then
				local v = enabled.Value
				return (type(v) == "boolean" and v) or (type(v) == "number" and v > 0)
			else
				return (type(enabled) == "boolean" and enabled) or (type(enabled) == "number" and enabled > 0)
			end
		end,

		1
	)
end

--[=[
	Public: Removes a vehicle
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
local function RemoveVehicle(car: types.Vehicle): ()
	if not Vehicles[car] then
		debugger.warn("Warning", "Cannot find vehicle in vehicle map.")
		return
	end

	local sourcesList = sources.list
	Vehicles[car] = nil

	for i = #sourcesList, 1, -1 do
		if sourcesList[i].Owner == car then
			debugger.print("Info", "Found car")
			table.remove(sourcesList, i)
			break
		end
	end

end

--[=[
	Public: Processes reflectors and normalizes base color
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
local function ProcessReflector(p)
	if config.ReflectorConfig.Condition(p) or p:HasTag(config.ReflectorConfig.TagName) then
		PavementReflectors[p] = true
		utils.normalizeBaseColor(p)
	end
end

--[=[
	Public: Removes reflectors from the reflector rable
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
local function RemoveReflector(p): ()
	if config.ReflectorConfig.Condition(p) or p:HasTag(config.ReflectorConfig.TagName) then
		PavementReflectors[p] = nil
	end
end


--[=[
	Private: Builds Part Cache

	@private
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
local function _buildPartsCache()
	for _, folder in config.SignConfig.SignsFolders do
		for _, p in folder:GetDescendants() do
			CachedParts[p] = "near"
		end

		if config.STREAMING then
			folder.DescendantAdded:Connect(function(p:Instance)
				CachedParts[p::any] = "near"
			end)

			folder.DescendantRemoving:Connect(function(p:Instance)
				CachedParts[p::any] = nil
			end)
		end
	end
end

--[=[
	Private: Resets and returns SurfaceGui with pool check

	@private
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
local function _resetSurfaceGui(gui: SurfaceGui)
	if not gui then return end

	if gui.Parent == nil and gui.Enabled == false then
		return
	end

	--if gui:GetAttribute("InPool") == true then return end
	gui.Enabled = false
	gui.Adornee = nil
	gui.Parent = nil
	--gui:SetAttribute("InPool", true)

--[[	for part, state in SurfaceGuiStates do
		if state.gui == gui then
			SurfaceGuiStates[part] = nil
		end
	end
	for part, trackedGui in SurfaceGuisInBox do
		if trackedGui == gui then
			SurfaceGuisInBox[part] = nil
		end
	end]] -- Rmoved to prevent return duplication. This inactive code block is kept here for reference.

	--SurfaceGuiPool:ReturnObject(gui)
	local success:boolean, response:string? = pcall(SurfaceGuiPool.ReturnObject, SurfaceGuiPool, gui)
	-- Pooler may warn that an object was returned to a pool that is not in the active list,
	-- 	thus, a pcall is needed for this case to prevent the function from halting

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
local function _insertPartsRaycast()
	local SignsConfig = config.SignConfig
	local BoxOffset = SignsConfig.BoxOffset
	local DebugBoundary = SignsConfig.DebugBoundary
	local BoxOffsetNear = SignsConfig.BoxOffsetNear
	local BoxOffsetFar = SignsConfig.BoxOffsetFar
	local BoxSizeNear = SignsConfig.BoxSizeNear
	local BoxSizeFar = SignsConfig.BoxSizeFar

	local partsDict = {}

	for i,car in Vehicles do
		local DriveSeat = car.DriveSeat

		local seatCF = DriveSeat.CFrame
		local boxCF = seatCF * BoxOffset

		if DebugBoundary then
			local debugBoxClone = debugBox:Clone()
			debugBox.CFrame = boxCF
			debugBox.Transparency = config.SignConfig.DebugBoxTransparency
			debugBox.Parent = car.Body
		end

		for _, p in workspace:GetPartBoundsInBox(seatCF * BoxOffsetNear, BoxSizeNear, overlapParams) do
			partsDict[p] = "near"
		end
		for _, p in workspace:GetPartBoundsInBox(seatCF * BoxOffsetFar, BoxSizeFar, overlapParams) do
			if not partsDict[p] then partsDict[p] = "far" end
		end
	end

	return partsDict
end

--[=[
	Private: Starts reflector indexing and processing

	@private
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
local function _startReflectorIndexing(): ()
	if config.ReflectorConfig.UseTags then
		for i,p in CollectionService:GetTagged(config.ReflectorConfig.TagName) do
			ProcessReflector(p::any)
		end

		CollectionService:GetInstanceAddedSignal(config.ReflectorConfig.TagName):Connect(ProcessReflector)
		CollectionService:GetInstanceRemovedSignal(config.ReflectorConfig.TagName):Connect(RemoveReflector)
	else
		for i,Folder in config.ReflectorConfig.ReflectorsFolder do
			for i,p in Folder:GetDescendants() do
				ProcessReflector(p)
			end

			Folder.DescendantAdded:Connect(ProcessReflector::any)
			Folder.DescendantRemoving:Connect(RemoveReflector::any)
		end
	end
end

--[=[
	Private: Boundary / zone detection loop

	@private
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
local function _detectBoundaries(Frequency: number): ()
	-- pcall replaced with pcallRetry used in the Start function
	local partsDict
	if config.UseRaycast then
		partsDict = _insertPartsRaycast()
	else

		partsDict = {}

		-- partsDict = CachedParts

		-- cacheparts is a weak table, so probably better to clone everything to create an interm strong ref?
	end

	while true do
		task.wait(utils.adaptiveWait(config.BoundaryMinFPS,
			config.BoundaryMaxFPS,
			utils.getFastestDriveSeat(Vehicles)))

		local activeParts = {}

		table.clear(ReflectorsisInBox)
		table.clear(partsDict)

		for part, range in CachedParts do
			partsDict[part] = range
		end


		if not sources.anyActive() or not dark() then
			if debugBox then debugBox.Transparency = 0.95 end
			for part, state in SurfaceGuiStates do
				if state.gui then
					state.gui.Enabled = false
					state.gui.Adornee = nil
					state.gui.Parent = nil
					_resetSurfaceGui(state.gui)
				end
				SurfaceGuiStates[part] = nil
				--	SurfaceGuisInBox[part] = nil -- Removed to prevent return duplication
			end

			for part, state in ReflectorStates do
				ReflectorStates[part] = nil
				ReflectorsisInBox[part] = nil

				if state.baseColor then
					part.Color = state.baseColor
					part.Material = config.ReflectorConfig.InactiveMaterial
				end
			end
			continue
		end

		for part in PavementReflectors do
			if not part then continue end

			ReflectorsisInBox[part] = true

			local state = ReflectorStates[part]
			if not state then
				state = {
					currentIntensity = 0,
					targetIntensity = 0,
					baseColor = part:GetAttribute("BaseColor"),
					isActive = false,
				}:: types.ReflectorState
				ReflectorStates[part] = state
			end

			state.targetIntensity = equations.computeReflectorIntensity(part, sources.list)
		end

		for part, rangeType in partsDict do

			if not sources.anyActive() or not dark() then
				continue
			end

			local mainDecal = part:FindFirstChild(config.SignConfig.MainDecalName)

			if not mainDecal then
				for _, decal in part:GetChildren() do
					if decal:IsA("Decal") then
						local name = decal.Name

						if config.SignConfig.MainDecalConditions(decal) then
							mainDecal = decal
							decal.Name = config.SignConfig.MainDecalName
							break
						end
					end
				end
			end

			if not mainDecal then continue end

			if part:GetAttribute("IsFixed") ~= true then
				utils.fixPartOrientation(part, mainDecal)
			end

			local gui = SurfaceGuisInBox[part]
			if not gui  then
				gui = SurfaceGuiPool:GetObject() :: SurfaceGui

				if gui == nil then debugger.warn("Warning", "Pool contains nil instances.") continue end

			--	gui:SetAttribute("InPool", false)
				gui.Face = mainDecal.Face
				gui.Adornee = part
				gui.Parent = part
				gui.Enabled = true
				gui.ImageLabel.Image = mainDecal.Texture
				gui.ImageLabel.ImageTransparency = mainDecal.Transparency
				SurfaceGuisInBox[part] = gui
			end

			if gui.Parent == nil then
			--	gui:SetAttribute("InPool", false)
				gui.Face = mainDecal.Face
				gui.Parent = part
				gui.Adornee = part
				gui.Enabled = true
				gui.ImageLabel.Image = mainDecal.Texture
				gui.ImageLabel.ImageTransparency = mainDecal.Transparency
			end

			local fadeData = equations.computeSignIntensity(part, mainDecal, "near", sources.list)

			local state = SurfaceGuiStates[part]
			if not state then
				state = {
					gui = gui,
					currentTransparency = gui.ImageLabel.ImageTransparency,
					currentBrightness = gui.Brightness,
					currentLight = gui.LightInfluence,
					isActive = true
				}:: types.SurfaceGuiState -- forced to do this
				SurfaceGuiStates[part] = state
			end

			state.targetTransparency = fadeData.transparency
			state.targetBrightness = fadeData.brightness
			state.targetLight = fadeData.light

			activeParts[part] = true
		end

		local previousParts = currentParts or {}

		for part in previousParts do
			if not activeParts[part] then
				local gui = SurfaceGuisInBox[part]
				if gui then
					_resetSurfaceGui(gui)
				end
			end
		end
		currentParts = activeParts
	end
end

--[=[
	Private: Rendering loop

	@private
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
local function _render(Frequency: number): ()
	-- pcall replaced with pcallRetry used in the Start function
	while true do
		local dt = utils.adaptiveWait(config.RenderMinFPS, config.RenderMaxFPS,
			utils.getFastestDriveSeat(Vehicles))

		task.wait(dt) -- dt = deltaTime

		local LerpSpeed = config.ReflectorConfig.LerpSpeed
		for part, state in ReflectorStates do
			if not ReflectorsisInBox[part] then
				if state.baseColor then
					part.Color = state.baseColor
					part.Material = Enum.Material.Plastic
				end
				ReflectorStates[part] = nil
				continue
			end

			state.currentIntensity +=
				(state.targetIntensity - state.currentIntensity)
				* math.clamp(LerpSpeed * dt, 0, 1)

			if state.isActive == nil then
				state.isActive = false
			end

			if state.isActive then
				if state.currentIntensity <= config.ReflectorConfig.DeactivateThreshold then
					state.isActive = false
				end
			else
				if state.currentIntensity >= config.ReflectorConfig.ActivateThreshold then
					state.isActive = true
				end
			end

			local intensity = state.currentIntensity

			if intensity >= config.ReflectorConfig.NeonMinIntensity then
				part.Material = config.ReflectorConfig.ActiveMaterial

				local baseColor: Color3 = state.baseColor
				local minScale = config.ReflectorConfig.DarkBrightness / 255
				local maxScale = config.ReflectorConfig.LightBrightness / 255

				local scale = minScale + (maxScale - minScale) * intensity

				local r = math.clamp(baseColor.R * scale, 0, 1)
				local g = math.clamp(baseColor.G * scale, 0, 1)
				local b = math.clamp(baseColor.B * scale, 0, 1)

				part.Color = Color3.new(r, g, b)

			elseif intensity > 0 then
				part.Material = Enum.Material.Plastic

				part.Color = state.baseColor:Lerp(
					config.ReflectorConfig.PartialDimmingBaseColor,
					intensity * 0.5
				)
			else
				part.Material = config.ReflectorConfig.InactiveMaterial
				part.Color = state.baseColor
			end
		end

		for part, state in SurfaceGuiStates do
			if not currentParts[part] then
				if state.gui then
					state.gui.Enabled = false
					state.gui.Adornee = nil
					state.gui.Parent = nil
					_resetSurfaceGui(state.gui)
				end
				SurfaceGuiStates[part] = nil
				SurfaceGuisInBox[part] = nil
				continue
			end

			local gui = state.gui
			if gui and gui.Parent then
				local LerpSpeed = config.SignConfig.LerpSpeed
				state.currentTransparency += (state.targetTransparency - state.currentTransparency) * math.clamp(LerpSpeed * dt, 0, 1)
				state.currentBrightness += (state.targetBrightness - state.currentBrightness) * math.clamp(LerpSpeed * dt, 0, 1)
				state.currentLight += (state.targetLight - state.currentLight) * math.clamp(LerpSpeed * dt, 0, 1)

				gui.ImageLabel.ImageTransparency = state.currentTransparency
				gui.Brightness = state.currentBrightness
				gui.LightInfluence = state.currentLight

				local num = config.SignConfig.InactiveTransparency

				if state.targetTransparency >= num and state.currentTransparency >= num then
					gui.Enabled = false
					gui.Adornee = nil
					gui.Parent = nil
					_resetSurfaceGui(gui)
					SurfaceGuiStates[part] = nil
					SurfaceGuisInBox[part] = nil
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
	debugger.assert(not Starting, "AlreadyStarting")

	Starting = true

	if not config.UseRaycast then _buildPartsCache() end

	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = config.SignConfig.SignsFolders :: any

	_startReflectorIndexing()

	BoundaryThread = task.defer(utils.pcallRetry, _detectBoundaries, config.MaxPcallRetries)
	RenderThread = task.defer(utils.pcallRetry, _render, config.MaxPcallRetries)

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
	debugger.assert(Starting, "Warning", "Cleanup called before Start().")

	debugger.print("Info","Cleaning up!")
	task.cancel(BoundaryThread :: any)
	task.cancel(RenderThread :: any)
	--=SurfaceGuiPool:Clear()

	for part, state in SurfaceGuiStates do
		local gui = state.gui
		if gui then
			gui.Enabled = false
			gui.Adornee = nil
			gui.Parent = nil
			_resetSurfaceGui(gui)
		end
	end

	for part, gui in SurfaceGuisInBox do
		if gui and gui.Parent then
			gui.Enabled = false
			gui.Adornee = nil
			gui.Parent = nil
			_resetSurfaceGui(gui)
		end
	end

	table.clear(SurfaceGuiStates)
	table.clear(currentParts)
	table.clear(SurfaceGuisInBox)
end

-- Return Public Variables and API
return table.freeze({
	Start = Start,
	AddVehicle = AddVehicle,
	RemoveVehicle = RemoveVehicle,
	Cleanup = Cleanup,
	AssignConfig = utils.assignConfig,
	ProcessReflector = ProcessReflector,
	RemoveReflector = RemoveReflector,
	SurfaceGuiStates = SurfaceGuiStates,
	ReflectorStates = ReflectorStates
})
