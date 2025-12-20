--!native

-- apologies for the large header and changelog, it would be moved to a seperate README & LICENSE ile soon

local ProjectRoadworkHeader = [[--[LIGHT-REFLECTOR]-------------------------------------
  FILE:             Light-Reflector.luau
  DESCRIPTION:      A light reflector that reflects decals for now at long distances.
  functionality. 
  USAGE:            A-Chassis Tune/Plugins/Light-Reflector.luau
  DEPENDENCIES:     POOLERPLUS
  LANGUAGE:         Luau
  
  GROUP:            Project Roadwork
  VERSION:          0.1.5-alpha
  CREATED:          2025-10-26 2:03 PM CDT  
  LAST UPDATED:     2025-12-19 9:27 PM CST   
  LICENSE:          Apache-2.0

  CODEBERG REPO:    https://codeberg.org/project-roadwork/light-reflector (MAIN)
  GITHUB REPO:      https://github.com/project-roadwork/light-reflector (BACKUP)
  
  NOTES: Use the accompanying repository links for documentation, help, or
  to propose a suggestion or comment. The NOTICE file can be found in the respository
  links.
  
  LICENSE HEADER:
	Copyright 2025 Illinois_Roadbuff (Rogue Jr) and the Project Roadwork Contributors

	Licensed under the Apache License, Version 2.0 (the "License");
 	 http://www.apache.org/licenses/LICENSE-2.0
  
  AUTHORS:
   Illinois_Roadbuff (2653606809) - October 26th, 2025 - Created the file
-----------------------------------------------------------------------------------]]

--[[
-- Changelog [MM/DD/YYYY]
-- This will be moved to a seperate script soon

[12/19/2025 : Light-Reflector, Version 0.1.5-alpha]
	Author: Illinois_Roadbuff "Rogue Jr"
	
	[Fixes]
		- now works without a weather system	
	
	[Features]
		- add option to disable raycasting or not
		- another way to process signs via :GetDescendants() albeit it may lag when used frequently
		- add streaming variable

[10/29/2025 : Light-Reflector, Version 0.1.4-alpha]
	Author: Illinois_Roadbuff "Rogue Jr"
	
	[Fixes]
		- move overlap params outside the loop
		- fix surfacegui safety net
		- adjust cleanup function although it does not work atm
		- adjust box radius and offset to be shorter (reflectivity is not that long on normal low beams)

	Raycast still lags badly on high part areas DESPITE overlap params
	
[10/27/2025 : Light-Reflector, Version 0.1.3-alpha]
	Author: Illinois_Roadbuff "Rogue Jr"
	
	[Fixes]
		- remove car from include overlap param

	[Features]
		- add cleanup functionality
		- make sure that surfacegui pool is reused
		- automatically clean up when headlights are not enabled or when it is not night

[10/27/2025 : Light-Reflector, Version 0.1.2-alpha]
	Author: Illinois_Roadbuff "Rogue Jr"
	WIP

[10/27/2025 : Light-Reflector, Version 0.1.1-alpha]
	Author: Illinois_Roadbuff "Rogue Jr"
	WIP
	
[10/27/2025 : Light-Reflector, Version 0.1.0-alpha]
	Author: Illinois_Roadbuff "Rogue Jr"
	WIP
]]
task.wait(1)

local version = "0.1.5"

-- CONFIG --

local car = script.Parent.Car.Value -- do not change unless you do not use an A-Chassis like system
local DriveSeat: VehicleSeat = car.DriveSeat
local LightValues = car.Body.Headlight.on -- set this to whatever value shows the headlights (MUST BE A BOOLEAN)
local Lighting = game:GetService("Lighting") -- Do not change

local FadeDistance = 2500 -- max fade distane of signs in studs
local MinFadeDistance = 60 -- studs
local MphScale = 2.23694 * 0.28 -- (stud/sec) → mph
local SignsFolders = { workspace.Signs, workspace.Other } -- SET THIS TO YOUR OWN SIGNS FOLDERS SEPERATED BY A COMMA

local STREAMING = true -- Set this to true if you have a custom streaming system or have instance streaming enabled.

-- RAYCAST CONFIG --

local UseRaycast = false -- only set this to true if you actually need raycasting which is unneccesary (lots of lag). 
-- Otherwise, leaving this as false processes all of the signs

local DebugBoundary = false -- Shows the debug box
local BoxOffset = CFrame.new(0, 3, -625) -- offset to car
local BoxSizeNear = Vector3.new(250, 150, 1250) -- smaller box close to headlights
local BoxSizeFar = Vector3.new(500, 150, 1250) -- larger box far from headlights
local BoxOffsetNear = BoxOffset
local BoxOffsetFar = BoxOffset * CFrame.new(0, 0, -BoxSizeNear.Z / 2)

local OverlapParams = OverlapParams.new()
OverlapParams.FilterType = Enum.RaycastFilterType.Include

OverlapParams.FilterDescendantsInstances = SignsFolders

-- DEBUGGER --

local print, warn = print, warn -- change if you have your own debugger

local function dprint(m)
	print(`:: Light-Reflector {version} :: {m}`)
end

local function dwarn(m)
	warn(`:: Light-Reflector {version} :: {m}`)
end


local index, PoolerPlus = game:GetService("ReplicatedStorage"):FindFirstChild("PoolerPlus"), nil
if index then
	PoolerPlus = require(index)
else
	dwarn("Dependency PoolerPlus does not exist! This script strictly needs this dependency! Halting execution...")
	return
end


local ReplicatedStorage = game:GetService("ReplicatedStorage")
local SurfaceGuiTemplate = ReplicatedStorage:FindFirstChild("ReflectorTemplate")

if not SurfaceGuiTemplate then
	dwarn("SurfaceGui template does not exist! Using safety net and creating SurfaceGui template...")
	SurfaceGuiTemplate = Instance.new("Folder")
	SurfaceGuiTemplate.Name = "ReflectorTemplate"
	SurfaceGuiTemplate.Parent = ReplicatedStorage
end

local TemplateGui = SurfaceGuiTemplate:FindFirstChildOfClass("SurfaceGui")
if not TemplateGui then
	dwarn("SurfaceGui does not exist in the template! Using safety net and creating SurfaceGui...")

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


local SurfaceGuiPool = PoolerPlus:GetPool("SurfaceGuis")

if not SurfaceGuiPool then
	SurfaceGuiPool= PoolerPlus:CreatePool("SurfaceGuis", function()
		return SurfaceGuiTemplate.SurfaceGui:Clone()
	end, nil, nil, {
		preloadCount = 10,
		enableAnalytics = false,
		instanceConfig = { template = SurfaceGuiTemplate.SurfaceGui:Clone() },
	})
end
	
local SurfaceGuisInBox = {}
local SurfaceGuiStates = {}
local currentParts = {}

local debugBox
if DebugBoundary then
	debugBox = Instance.new("Part")
	debugBox.Anchored = true
	debugBox.CanCollide = false
	debugBox.CastShadow = false
	debugBox.Transparency = 0.8
	debugBox.Color = Color3.fromRGB(0, 255, 0)
	debugBox.Material = Enum.Material.Plastic
	debugBox.Name = "SensorDebugBox"
	debugBox.Size = BoxSizeNear
	debugBox.Parent = car.Body
end


local function getSpeedMph()
	return DriveSeat.AssemblyLinearVelocity.Magnitude * MphScale
end

local function AdaptiveWait(minFPS, maxFPS)
	local speedMph = getSpeedMph()
	local targetFPS = math.clamp((speedMph / 80) * maxFPS, minFPS, maxFPS)
	return 1 / targetFPS
end

local function isNight()
	local clockTime = Lighting.ClockTime
	local Weather = game.ReplicatedStorage:WaitForChild("WeatherResources", 5)
	local cancount = false
	
	if Weather then -- TTP or Redon Tech weather compatibility
		local WeatherFolder = Weather.Weather
		local Current = WeatherFolder.Current

		-- will be moved to table soon { [weather] == true } 
		if Current.Weather.Value == "Drizzle" then

		elseif Current.Weather.Value == "Showers" then

		elseif Current.Weather.Value == "Rain" then

		elseif Current.Weather.Value == "Heavy Rain" or Current.Weather.Value == "Thunderstorms" then
			cancount = true
		elseif Current.Weather.Value == "Strong Thunderstorms" then
			cancount = true
		elseif Current.Weather.Value == "Flurries" then


		elseif Current.Weather.Value == "Snow Showers" then


		elseif Current.Weather.Value == "Snow" then


		elseif Current.Weather.Value == "Heavy Snow" then


		elseif Current.Weather.Value == "Freezing Drizzle" then


		elseif Current.Weather.Value == "Rain / Snow Showers" then

		elseif Current.Weather.Value == "Rain / Snow" then

		elseif Current.Weather.Value == "Heavy Rain / Snow" then
			cancount = true
		elseif Current.Weather.Value == "Cloudy" then


		elseif Current.Weather.Value == "Partly Cloudy" then

		elseif Current.Weather.Value == "Mostly Cloudy" then


		else

		end
	else
		dwarn("Unable to find Weather System.")
	end
	

	return (clockTime >= 17.2 or clockTime < 6.3) or cancount
end

local function computeFadeData(part, decal, rangeType)
	local seatPos = DriveSeat.Position
	local dist = (seatPos - decal.Parent.Position).Magnitude

	local isReflective = part:GetAttribute("VeryReflective")
		or (part.Size.X > 2.5 or part.Size.Y > 2.5 or part.Size.Z > 2.5)

	local fadeRange = (rangeType == "near")
		and (isReflective and FadeDistance or FadeDistance / 2)
		or (isReflective and FadeDistance * 2 or FadeDistance)

	local distFade = math.clamp(dist / fadeRange, 0, 1)
	local toDecal = ((decal.Parent.Position - seatPos) * Vector3.new(1, 0, 1)).Unit
	local carLook = DriveSeat.CFrame.LookVector * Vector3.new(1, 0, 1)
	local dot = math.clamp(carLook:Dot(toDecal), 0, 1)

	local distanceFactor = math.clamp(1 - (dist / fadeRange), 0, 1)
	local angleFade = math.clamp(((1 - dot) ^ 2) * (distanceFactor * 2 + 0.7), 0, 1)
	local baseTransparency = (dot <= 0.1) and 1 or (distFade * 0.2 + angleFade * 0.8)

	local proximityFactor = (dist < MinFadeDistance) and (dist / MinFadeDistance) or 1
	local fadeOutFactor = 3

	local HeadlightHalfAngle = math.rad(10)
	local maxDot = math.cos(HeadlightHalfAngle)
	local dotClamped = math.clamp((dot - maxDot) / (1 - maxDot), 0, 1)

	local angleContribution = 1 - dotClamped
	local distContribution = baseTransparency

	return {
		transparency = baseTransparency + (1 - proximityFactor) * fadeOutFactor * (1 - baseTransparency),
		brightness = (1 + (1 - distContribution) * 0.25 + angleContribution * 0.25)
			* proximityFactor + (1 - proximityFactor),
		light = (distContribution * 0.5 + angleContribution * 0.5)
			* proximityFactor + (1 - proximityFactor),
	}
end

local function FixPartOrientation(part: BasePart, decal)
	if part:GetAttribute("IsFixed") == true then return end
	if decal.Face == Enum.NormalId.Top then


		part.CFrame *= CFrame.Angles(0, math.rad(-90), math.rad(-90))

		local size = part.Size
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

local function InsertParts()
	local partsDict = {}
	
	local seatCF = DriveSeat.CFrame
	local boxCF = seatCF * BoxOffset

	if DebugBoundary then
		debugBox.CFrame = boxCF
		debugBox.Transparency = 0.7
	end
	
	if UseRaycast then
		for _, p in workspace:GetPartBoundsInBox(seatCF * BoxOffsetNear, BoxSizeNear, OverlapParams) do
			partsDict[p] = "near"
		end
		for _, p in workspace:GetPartBoundsInBox(seatCF * BoxOffsetFar, BoxSizeFar, OverlapParams) do
			if not partsDict[p] then partsDict[p] = "far" end
		end
	else
		for _, v in SignsFolders do
			for _, p in v:GetDescendants() do
				partsDict[p] = "near"
			end
		end
	end
	
	return partsDict
end


local function DetectBoundaries(Frequency)
	local s,r = pcall(function()
		local partsDict = if STREAMING then nil else InsertParts()
		while true do
			task.wait(AdaptiveWait(1,3))
			local activeParts = {}

		
			if not (LightValues.Value) or not isNight() then
				if debugBox then debugBox.Transparency = 0.95 end
				--dprint("Cleaning up!")
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
				continue
			end

			if STREAMING then partsDict = InsertParts() end

			for part, rangeType in partsDict do
				local mainDecal = nil
				for _, decal in part:GetChildren() do
					if decal:IsA("Decal") then
						local name = decal.Name
						local isExcludedBottom = (name == "Decal" and decal.Face == Enum.NormalId.Bottom)
						if name == "F" or (name ~= "Back" and name ~= "B" and name ~= "Images/Metal Lined" and not isExcludedBottom) then
							mainDecal = decal
							break
						end
					end


				end

				if not mainDecal then continue end

				if part:GetAttribute("IsFixed") ~= true then
					FixPartOrientation(part, mainDecal)
				end

			--	activeParts[part] = true


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

				local fadeData = computeFadeData(part, mainDecal, rangeType)

				local state = SurfaceGuiStates[part]
				if not state then
					state = {
						gui = gui,
						currentTransparency = gui.ImageLabel.ImageTransparency,
						currentBrightness = gui.Brightness,
						currentLight = gui.LightInfluence,
					}
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
		dwarn(r)
	end

end

local function Render(Frequency)
	local s,r = pcall(function()
		while true do
			local dt = AdaptiveWait(45, 55)
			task.wait(dt)
		
			local LerpSpeed = 5

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
		dwarn(r)
	end
end

local function Start() -- for future use
	local a=task.defer(DetectBoundaries)
	local b=task.defer(Render)

	dprint("Successfully loaded!")

	car.Destroying:Once(function()
		dprint("Car is being destroyed; cleaning up!")
		task.cancel(a)
		task.cancel(b)
		--SurfaceGuiPool:Clear()

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
	end)
end



Start()


