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
]]

-- IMPORTANT: Services
local Lighting: Lighting = game:GetService("Lighting")
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

-- Variables
local Vehicles: types.VehicleMap = {}
local SurfaceGuisInBox = {}
local SurfaceGuiStates: types.SurfaceGuiStates = {}
local ReflectorsisInBox = {}
local ReflectorStates: types.ReflectorStates = {}
local currentParts: { [BasePart]: true } = {}
local CachedParts: { types.RangeType } = {}

local RenderThread: any, BoundaryThread: any = nil, nil
local Starting: boolean = false
local PavementReflectors = {}
local overlapParams: OverlapParams = OverlapParams.new()

-- Debug Box Setup
local debugBox= Instance.new("Part") -- forced to do instance.new instead of nil or else the type solver is going into a panic attack
if config.SignConfig.DebugBoundary then

	debugBox.Anchored = true
	debugBox.CanCollide = false
	debugBox.CastShadow = false
	debugBox.Transparency = 0.8
	debugBox.Color = Color3.fromRGB(0, 255, 0)
	debugBox.Material = Enum.Material.Plastic
	debugBox.Name = "SensorDebugBox"
	debugBox.Size = config.SignConfig.BoxSizeNear
	debugBox.Parent = workspace
end

-- Pooler Safety Nets

-- TODO
-- Make custom pooler module so there would be no needed dependency
local index, PoolerPlus = ReplicatedStorage:FindFirstChild("PoolerPlus"), nil
if index then
	PoolerPlus = require(index)
else
	debugger.fatal("FatalInit","Dependency PoolerPlus does not exist! This script strictly needs this dependency! Halting execution...")
end

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
local SurfaceGuiPool: any = PoolerPlus:GetPool("SurfaceGuis") :: any? -- literally cannot type this even with types.ObjectPool<SurfaceGui>? sorry

if not SurfaceGuiPool then
	SurfaceGuiPool= PoolerPlus:CreatePool("SurfaceGuis", function()
		return SurfaceGuiTemplate.SurfaceGui:Clone()
	end, nil, nil, {
		preloadCount = 10,
		enableAnalytics = false,
		instanceConfig = { template = SurfaceGuiTemplate.SurfaceGui:Clone() },
	}) :: any
end

-- Public: Adds a vehicle
local function AddVehicle(car: types.Vehicle, enabled: boolean | number): ()

	Vehicles[car] = true
	local seat = car.DriveSeat

	sources.register(
		car,
		function() return seat.Position + Vector3.new(0,2,0) end,
		function() return seat.CFrame.LookVector end,
		function()
			if typeof(enabled) == "Instance" and enabled:IsA("ValueBase") then
				local v = enabled.Value
				return (typeof(v) == "boolean" and v) or (typeof(v) == "number" and v > 0)
			else
				return (typeof(enabled) == "boolean" and enabled) or (typeof(enabled) == "number" and enabled > 0)
			end
		end,

		1
	)
end

-- Public: Removes a vehicle
local function RemoveVehicle(car: types.Vehicle): ()
	local sourcesList = sources.list
	Vehicles[car] = nil

	for i = #sourcesList, 1, -1 do
		if sourcesList[i].Owner == car then
			debugger.print("found car!")
			table.remove(sourcesList, i)
			break
		end
	end

end

-- Public: Processes reflectors and normalizes base color
local function ProcessReflector(p)
	if config.ReflectorConfig.Condition(p) or p:HasTag("Reflector") then
		PavementReflectors[p] = true
		utils.normalizeBaseColor(p)
	end
end

-- Public: Removes reflectors from the reflector rable
local function RemoveReflector(p): ()
	if config.ReflectorConfig.Condition(p) or p:HasTag("Reflector") then
		PavementReflectors[p] = nil
	end
end

-- Private: Builds Part Cache
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

-- Private: Inserts parts into a table via raycast
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
			debugBox.Transparency = 0.7
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

-- Private: Starts reflector indexing and processing
local function _startReflectorIndexing(): ()
	if config.ReflectorConfig.UseTags then
		for i,p in CollectionService:GetTagged("Reflector") do
				ProcessReflector(p::any)
		end

		CollectionService:GetInstanceAddedSignal("Reflector"):Connect(ProcessReflector)
		CollectionService:GetInstanceRemovedSignal("Reflector"):Connect(RemoveReflector)
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

-- Private: Boundary / zone detection loop
local function _detectBoundaries(Frequency: number): ()
	local s:boolean, r:string? = pcall(function() -- pcall type bug, cannot fix on my end!
		local partsDict
		if config.UseRaycast then
			partsDict = _insertPartsRaycast()
		else
			partsDict = CachedParts
		end

		while true do
			task.wait(utils.adaptiveWait(1,3, utils.getFastestDriveSeat(Vehicles)))
			local activeParts = {}

			table.clear(ReflectorsisInBox)
			if not sources.anyActive() or not dark() then
				if debugBox then debugBox.Transparency = 0.95 end
				for part, state in SurfaceGuiStates do
					if state.gui then
						state.gui.Enabled = false
						state.gui.Adornee = nil
						state.gui.Parent = nil
						SurfaceGuiPool:Return(state.gui)
					end
					SurfaceGuiStates[part] = nil
					SurfaceGuisInBox[part] = nil

				end

				for part, state in ReflectorStates do
					ReflectorStates[part] = nil
					ReflectorsisInBox[part] = nil

					if state.baseColor then
						part.Color = state.baseColor
						part.Material = Enum.Material.Plastic
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
				local mainDecal = part:FindFirstChild("ACTUALMainDecal123")

				if not mainDecal then
					for _, decal in part:GetChildren() do
						if decal:IsA("Decal") then
							local name = decal.Name
							local isExcludedBottom = (name == "Decal" and decal.Face == Enum.NormalId.Bottom)
							if name == "F" or (name ~= "Back" and name ~= "B" and name ~= "Images/Metal Lined" and not isExcludedBottom) then
								mainDecal = decal
								decal.Name = "ACTUALMainDecal123"
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
				if not gui then
					gui = SurfaceGuiPool:Get()
					gui.Face = mainDecal.Face
					gui.Adornee = part
					gui.Parent = part
					gui.Enabled = true
					gui.ImageLabel.Image = mainDecal.Texture
					gui.ImageLabel.ImageTransparency = mainDecal.Transparency
					SurfaceGuisInBox[part] = gui
				end

				local fadeData = equations.computeSignIntensity(part, mainDecal, "near", sources.list)


				local state = SurfaceGuiStates[part]
				if not state then
					state = {
						gui = gui,
						currentTransparency = gui.ImageLabel.ImageTransparency,
						currentBrightness = gui.Brightness,
						currentLight = gui.LightInfluence,
					}:: types.SurfaceGuiState -- forced to do this
					SurfaceGuiStates[part] = state

				end

				state.targetTransparency = fadeData.transparency
				state.targetBrightness = fadeData.brightness
				state.targetLight = fadeData.light

				activeParts[part] = true
			end
			currentParts = activeParts
		end
	end)
	if not s then
		debugger.warn("Warning",r)
	end

end

-- Private: Rendering loop
local function _render(Frequency: number): ()
	local s,r = pcall(function()
		while true do
			local dt = utils.adaptiveWait(45, 55, utils.getFastestDriveSeat(Vehicles))
			task.wait(dt)

			local LerpSpeed = 10
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
					part.Material = Enum.Material.Neon


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
						Color3.fromRGB(120, 120, 120),
						intensity * 0.5
					)
				else
					part.Material = Enum.Material.Plastic
					part.Color = state.baseColor
				end
			end


			for part, state in SurfaceGuiStates do
				if not currentParts[part] then
					if state.gui then
						state.gui.Enabled = false
						state.gui.Adornee = nil
						state.gui.Parent = nil
						SurfaceGuiPool:Return(state.gui)
					end
					SurfaceGuiStates[part] = nil
					SurfaceGuisInBox[part] = nil
					continue
				end

				local gui = state.gui
				if gui and gui.Parent then

					local LerpSpeed = 5

					state.currentTransparency += (state.targetTransparency - state.currentTransparency) * math.clamp(LerpSpeed * dt, 0, 1)
					state.currentBrightness += (state.targetBrightness - state.currentBrightness) * math.clamp(LerpSpeed * dt, 0, 1)
					state.currentLight += (state.targetLight - state.currentLight) * math.clamp(LerpSpeed * dt, 0, 1)

					gui.ImageLabel.ImageTransparency = state.currentTransparency
					gui.Brightness = state.currentBrightness
					gui.LightInfluence = state.currentLight
				end
			end

		end
	end)
	if not s then
		debugger.warn("Warning",r)
	end
end

-- Public: Starts the module
local function Start() : ()
	debugger.assert(not Starting, "AlreadyStarting")

	Starting = true

	if not config.UseRaycast then _buildPartsCache() end

	overlapParams.FilterType = Enum.RaycastFilterType.Include
	overlapParams.FilterDescendantsInstances = config.SignConfig.SignsFolders :: any

	_startReflectorIndexing()

	BoundaryThread= task.defer(_detectBoundaries)
	RenderThread= task.defer(_render)

	debugger.print("Info","Successfully loaded!")
end

-- Public: Cleans up the module
local function Cleanup(): ()
	debugger.print("Info","Cleaning up!")
	task.cancel(BoundaryThread :: any)
	task.cancel(RenderThread :: any)
	SurfaceGuiPool:Clear()

	for part, state in SurfaceGuiStates do
		local gui = state.gui
		if gui then
			gui.Enabled = false
			gui.Adornee = nil
			gui.Parent = nil
			SurfaceGuiPool:Return(gui)
		end
	end

	for part, gui in SurfaceGuisInBox do
		if gui and gui.Parent then
			gui.Enabled = false
			gui.Adornee = nil
			gui.Parent = nil
			SurfaceGuiPool:Return(gui)
		end
	end

	table.clear(SurfaceGuiStates)
	table.clear(currentParts)
	table.clear(SurfaceGuisInBox)
end

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
