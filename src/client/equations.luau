--!native
--!strict
-- USAGE: lightreflector/client/equations.luau
-- Intensity equations for Light Reflector

-- Types Module
local types = require("../shared/types")

-- Configuration
local config = require("../shared/config")

-- Debugger
local debugger = require("../shared/debugger")

-- Variables
local rangeTypes: { [types.RangeType]: boolean } = { near = true, far = true }
local clamp = math.clamp

local function getNearbySources(signPos: Vector3, sources: types.SourceList, maxDistance: number)
	local nearby = {}
	for _, source in sources do
		if source.isActive() then
			local dist = (source.getPosition() - signPos).Magnitude
			if dist <= maxDistance then
				nearby[#nearby + 1] = source
			end
		end
	end
	return nearby
end

-- Public: Computes reflector intensity
local function computeReflectorIntensity(part: BasePart, sources:types.SourceList)

	--[[
		             __________________________________________________________
		Intensity = |  Σ  [ DotAlignment * DistanceFactor * WedgeFactor * ProximityFactor * LightIntensity ]
		             ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
		Clamped between 0 and 1

	]]

	debugger.assert(part:IsA("BasePart"), "InvalidInstance", "BasePart", part.ClassName)

	local intensity = 0

	for _, source in sources do
		if source.isActive()  then
			local pos = source.getPosition()
			local dir = source.getDirection()

			local toPart = (part.Position - pos).Unit
			local dot = clamp(dir:Dot(toPart), 0, 1)

			local dist = (part.Position - pos).Magnitude
			local distFactor = clamp(1 - (dist / config.ReflectorConfig.MaxDistance), 0, 1)

			local wedgeFactor = 1
			if config.ReflectorConfig.UseWedgeFacingDetection and part:IsA("WedgePart") then
				local slopeNormal = part.CFrame.LookVector
				local toLight = (pos - part.Position).Unit
				local wedgeDot = clamp(slopeNormal:Dot(toLight), 0, 1)
				wedgeFactor = clamp(
					(wedgeDot - config.ReflectorConfig.WedgeFacingDotThreshold) /
						(1 - config.ReflectorConfig.WedgeFacingDotThreshold),
					0, 1
				)
			end

			local proximityFactor = (dist < config.ReflectorConfig.MinDistance) and (dist / config.ReflectorConfig.MinDistance) or 1

			intensity += dot * distFactor * wedgeFactor * proximityFactor * (source.Intensity or 1)
		end
	end

	return clamp(intensity, 0, 1)
end

-- Public: Computes sign intensity
local function computeSignIntensity(part : Part, decal : Decal, rangeType: types.RangeType, sources: types.SourceList)

	--[[
			              			 ______________________________________________________________
		ImageTransparency =           min [ BaseTransparency * ProximityFactor * AngleContribution ]
			              			 ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾

			           			     ___________________________________________________________________________________________________
		SurfaceGuiBrightness =        Σ [ (1 + (1-DistanceFactor)*0.25 + AngleContribution*0.25)*ProximityFactor + (1-ProximityFactor) ]
			          			     ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾

		            			     __________________________________________________________________________________________
		SurfaceGuiLightInfluence =     min [ (DistanceFactor*0.5 + AngleContribution*0.5)*ProximityFactor + (1-ProximityFactor) ]
		              				 ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾

	]]

	debugger.assert(part:IsA("BasePart"), "InvalidInstance", "BasePart", part.ClassName)
	debugger.assert(rangeTypes[rangeType], "InvalidType", `either "far" or "near"`, rangeType)

	local parent: Instance = decal.Parent :: Instance
	debugger.assert(parent and parent:IsA("BasePart"), "InvalidInstance", "BasePart", parent.ClassName)
	local Parent: BasePart = parent :: BasePart -- forced to use casting due to custom debugger


	local FadeDistance = config.SignConfig.FadeDistance
	local MinFadeDistance = config.SignConfig.MinFadeDistance

	-- INFO OF VARIABLES:
	--   	Transparency affects the ImageLabel with the sign (SurfaceGui.ImageLabel)
	--   	Brightness affects SurfaceGui.Brightness
	--      Light affects SurfaceGui.LightInfluence

	local finalTransparency = 1
	local finalBrightness = 0
	local finalLight = 1

	local count = 0

	local enabledLights = {}

	local nearbySources = getNearbySources(Parent.Position, sources, config.SignConfig.FadeDistance + 500)
	if #nearbySources == 0 then
		return { transparency = 1, brightness = 0, light = 0 }
	end

	for _, light in nearbySources do
		if light.isActive() then
			enabledLights[#enabledLights + 1] = light
		end
	end
	local hasActiveLight =false

	for _, light in enabledLights do
		count += 1

		local seatPos = light.getPosition()
		local carLook = light.getDirection()

		local dist = (seatPos - Parent.Position).Magnitude

		local isReflective: boolean = (part:GetAttribute("VeryReflective") :: boolean?)
			or (part.Size.X > 2.5 or part.Size.Y > 2.5 or part.Size.Z > 2.5)


		local fadeRange = (rangeType == "near") and (isReflective and FadeDistance or FadeDistance / 2)
			or (isReflective and FadeDistance * 2 or FadeDistance) local distFade = clamp(dist / fadeRange, 0, 1)
		local distanceFactor = clamp(1 - (dist / fadeRange), 0, 1)

		local toDecal = ((Parent.Position - seatPos) * Vector3.new(1, 0, 1)).Unit

		local dot = clamp(carLook:Dot(toDecal), 0, 1)
		local angleFade = clamp(((1 - dot) ^ 2) * (distanceFactor * 2 + 0.7), 0, 1)
		local baseTransparency = (dot <= 0.1) and 1 or (distFade * 0.2 + angleFade * 0.8)
		local proximityFactor = (dist < MinFadeDistance) and (dist / MinFadeDistance) or 1

		local maxDot = math.cos(config.LightHalfAngle)
		local dotClamped = clamp((dot - maxDot) / (1 - maxDot), 0, 1)
		local angleContribution = 1 - dotClamped
		local distContribution = baseTransparency

		if dist < config.SignConfig.FadeDistance and dot > 0 then
			local weightedTransparency = baseTransparency * proximityFactor * angleContribution
			local weightedBrightness = (1 + (1 - distContribution) * 0.25 + angleContribution * 0.25) * proximityFactor + (1 - proximityFactor)
			local weightedLight = (distContribution * 0.5 + angleContribution * 0.5) * proximityFactor + (1 - proximityFactor)

			finalTransparency = math.min(finalTransparency, weightedTransparency)

			finalBrightness += weightedBrightness

			finalLight = math.min(finalLight, weightedLight)

			hasActiveLight = true
		end
	end
	if not hasActiveLight then
		finalTransparency = 1
		finalBrightness = 0
		finalLight = 1
	else
		finalTransparency = clamp(finalTransparency , 0, 1)
		finalBrightness   = clamp(finalBrightness , 0, 5)
		finalLight        = clamp(finalLight , 0, 1)
	end

	return {
		transparency = finalTransparency,
		brightness   = finalBrightness,
		light        = finalLight,
	}
end

return table.freeze({
	Name = "equations",
	computeSignIntensity = computeSignIntensity,
	computeReflectorIntensity = computeReflectorIntensity
})
