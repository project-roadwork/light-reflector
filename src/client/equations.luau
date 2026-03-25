--!native
--!strict
-- USAGE: lightreflector/client/equations.luau
-- Intensity equations for Light Reflector

--[[

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at https://mozilla.org/MPL/2.0/.

]]

-- Types Module
local types = require("../shared/types")

-- Configuration
local config = require("../shared/config")

-- Debugger
local debugger = require("../shared/debugger")

-- Utilities
local utils = require("./utils")

-- Grid
local grid = require("./grid")

-- Variables
local rangeTypes: { [types.RangeType]: boolean } = { near = true, far = true }
local clamp = math.clamp

-- Public: Get nearby light sources
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
local function computeReflectorIntensity(part: BasePart, state, source, MPH: number): (boolean | number, boolean | number, number)

	--[[
		             __________________________________________________________
		Intensity = |  Σ  [ DotAlignment * DistanceFactor * WedgeFactor * ProximityFactor * LightIntensity ]
		             ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
		Clamped between 0 and 1

	]]

	--	debugger.assert(part:IsA("BasePart"), "InvalidInstance", "BasePart", part.ClassName)

	local baseIntensity:number = state.baseIntensity

	local intensity:number = 0
	local finalTransparency:number = 1

	local hybridTransparencyMultiplier:number = 1

	local partCFrame:CFrame = state.CFrame
	local partPosition:Vector3 = partCFrame.Position

	local face:string? = state.faceAttributeName

	local hybridFadeRange:number = 0
	local hybridMinDistance:number = 0
	local hybridCanKeepColorsAttribute:boolean? = nil
	local hybridTransparencyAttribute:number? = nil

	local canHybridKeepColors: boolean = false

	local maxDot = 0

	if state.isHybrid then
		maxDot =  math.cos(config.General.lightHalfAngle)
		hybridFadeRange = state.hybridFadeRange
		hybridMinDistance = state.hybridMinDistance
		hybridTransparencyMultiplier = state.hybridTransparencyMultiplier

		canHybridKeepColors = state.canHybridKeepColors
	end -- Added isHybrid if-block since :GetAttribute() calls may be expensive?

	local seatPos: Vector3 = source.getPosition()
	local dir:Vector3 = source.getDirection()

	local predictionFactor = 0.5

	local offset = MPH * predictionFactor

	local pos = seatPos + dir * offset

	local lightIntensity = source.getIntensity(source.Owner)  or 1

	local change = partPosition - pos

	local toPart = change.Unit
	local dot =  clamp(dir:Dot(toPart), 0, 1)

	local dist = change.Magnitude
	local distFactor = clamp(1 - (dist / config.ReflectorConfig.maxDistance), 0, 1)

	local wedgeFactor = 1

	if state.isWedge then
		local toLight = -toPart
		local rawDot = state.slopeNormalWorld:Dot(toLight)

		--	part:SetAttribute("RawDOT", rawDot) -- Kept as reference for debugging

		if rawDot <= 0 then
			wedgeFactor = 0
		else
			local dotClamped = clamp(rawDot, 0, 1)
			wedgeFactor = clamp(
				(dotClamped - config.ReflectorConfig.wedgeFacingDotThreshold) /
					(1 - config.ReflectorConfig.wedgeFacingDotThreshold), -- Usually near 0
				0, 1
			)
		end
	end

	if face then
		if not utils.validFaces[face] then
			debugger.warn("Warning", `Invalid Enum.NormalID face; got {face}.`)
			--	continue
			return false, false
		end

		local facedot = math.max(0, state.faceNormalWorld:Dot(-toPart)) -- clamping seems to bug

		--	part:SetAttribute("DOT", facedot) -- Kept as reference for debugging

		if facedot <= config.ReflectorConfig.hybridFacingDotThreshold then -- Usually near 0
			--continue
			return false, false
		end
	end

	local proximityFactor = (dist < config.ReflectorConfig.minDistance) and (dist / config.ReflectorConfig.minDistance) or 1

	intensity += dot * distFactor * wedgeFactor * proximityFactor * (lightIntensity or 1)

	if state.isHybrid then
		if canHybridKeepColors == false then intensity = .5 end

		local distFade = clamp(dist / hybridFadeRange, 0, 1)

		if distFade <= 0 then
			return false, false
		end

		local distanceFactor = clamp(1 - (dist / hybridFadeRange), 0, 1)

		local angleFade = math.sqrt(1 - dot) -- different equation since it's a smaller part
		local baseTransparency = (dot <= 0.1) and 1 or
			(distFade * 0.3 + angleFade * 0.7)

		local proximityFactor = (dist < hybridMinDistance) and (dist /  hybridMinDistance) or 1

		local dotClamped = clamp((dot - maxDot) / (1 - maxDot), 0, 1)
		local angleContribution = 1 - dotClamped
		local distContribution = baseTransparency

		local weightedTransparency = (baseTransparency * proximityFactor * angleContribution)

		weightedTransparency += (1 - weightedTransparency) * distFade

		finalTransparency = math.min(finalTransparency, weightedTransparency)
	end

	return clamp(intensity * baseIntensity, 0, 1), if intensity > 0 then clamp(finalTransparency*hybridTransparencyMultiplier, 0.5, 1) else 1
end

-- Public: Computes sign intensity
local function computeSignIntensity(state, part : BasePart, decal : Decal, rangeType: types.RangeType, activeSources: types.SourceList)

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

	--debugger.assert(part:IsA("BasePart"), "InvalidInstance", "BasePart", part.ClassName) Removed since :IsA() calls are expensive
	debugger.assert(rangeTypes[rangeType], "InvalidType", `either "far" or "near"`, rangeType)

	local baseIntensity:number = part:GetAttribute(config.Constraints.BASE_INTENSITY_ATTRIBUTE) or 1

	local FadeDistance:number = config.SignConfig.maxFadeDistance
	local MinFadeDistance:number = config.SignConfig.minFadeDistance

	local partCFrame:CFrame = state.CFrame
	local partPosition:Vector3 = partCFrame.Position
	local partSize:Vector3 = state.Size -- probably offers a bit of optimization?

	-- INFO OF VARIABLES:
	--   	Transparency affects the ImageLabel with the sign (SurfaceGui.ImageLabel)
	--   	Brightness affects SurfaceGui.Brightness
	--      Light affects SurfaceGui.LightInfluence

	local finalTransparency:number = 1
	local finalBrightness:number = 0
	local finalLightInfluence:number = 1

	local partVeryReflective:boolean? = state.partVeryReflective

	local count:number = 0

	local nearbySources = getNearbySources(partPosition, activeSources, config.SignConfig.maxFadeDistance + 500)
	if #nearbySources == 0 then
		return { transparency = 1, brightness = 0, lightInfluence = 0 }
	end

	local hasActiveLight =false
	local maxDot = math.cos(config.General.lightHalfAngle)

	for _, light in nearbySources do
		count += 1

		local seatPos = light.getPosition()
		local carLook = light.getDirection()
		local intensity = light.getIntensity(light.Owner) or 1

		local dist = (seatPos - partPosition).Magnitude

		local isReflective: boolean = (partVeryReflective)
			or (partSize.X > 2.5 or partSize.Y > 2.5 or partSize.Z > 2.5)


		local fadeRange = (rangeType == "near") and (isReflective and FadeDistance or FadeDistance / 2)
			or (isReflective and FadeDistance * 2 or FadeDistance)

		local distFade = clamp(dist / fadeRange, 0, 1)

		local distanceFactor = clamp(1 - (dist / fadeRange), 0, 1)

		local toDecal = (partPosition - seatPos).Unit

		local dot = clamp(carLook:Dot(toDecal), 0, 1)
		local angleFade = clamp(((1 - dot) ^ 2.5) * (distanceFactor * 2 + 0.7), 0, 1)
		local baseTransparency = (dot <= 0.1) and 1 or (distFade * 0.2 + angleFade * 0.8)
		local proximityFactor = (dist < MinFadeDistance) and (dist / MinFadeDistance) or 1

		local dotClamped = clamp((dot - maxDot) / (1 - maxDot), 0, 1)
		local angleContribution = 1 - dotClamped
		local distContribution = baseTransparency

		local faceNormalLocal = Vector3.FromNormalId(decal.Face)
		local faceNormalWorld = partCFrame:VectorToWorldSpace(faceNormalLocal)

		local toLight = (seatPos - partPosition).Unit
		local facedot = clamp(faceNormalWorld:Dot(toLight), 0, 1)

		--	part:SetAttribute("DOT", facedot) -- Kept as reference for debugging

		if facedot <= config.SignConfig.decalFacingDotThreshold then -- Usually near 0
			continue
		end

		if dist < config.SignConfig.maxFadeDistance and dot > 0 then
			local weightedTransparency = (baseTransparency * proximityFactor * angleContribution) / intensity
			local weightedBrightness = ((1 + (1 - distContribution) * 0.25 + angleContribution * 0.25) * proximityFactor + (1 - proximityFactor))  * intensity
			local weightedLightInfluence = ((distContribution * 0.5 + angleContribution * 0.5) * proximityFactor + (1 - proximityFactor)) / intensity

			finalTransparency = math.min(finalTransparency, weightedTransparency)
			finalBrightness += weightedBrightness
			finalLightInfluence = math.min(finalLightInfluence, weightedLightInfluence)

			hasActiveLight = true
		end
	end

	if not hasActiveLight then
		finalTransparency = 1
		finalBrightness = 0
		finalLightInfluence = 1
	else
		finalTransparency = clamp(finalTransparency  , 0, 1)
		finalBrightness   = clamp(finalBrightness * baseIntensity  , 0, 5)
		finalLightInfluence        = clamp(finalLightInfluence   , 0, 1)
	end

	return {
		transparency = finalTransparency,
		brightness   = finalBrightness,
		lightInfluence        = finalLightInfluence,
	}
end

return table.freeze({
	Name = "equations",
	computeSignIntensity = computeSignIntensity,
	computeReflectorIntensity = computeReflectorIntensity
})
