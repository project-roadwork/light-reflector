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
const types = require("../shared/types")

-- Configuration
const config: types.Configuration = require("../shared/config")

-- Debugger
const debugger: types.Debugger = require("../shared/debugger")

-- Utilities
const utils: types.Utils = require("./utils")

-- Grid
const grid: types.GridModule = require("./grid")

-- Variables
const rangeTypes: { [types.RangeType]: boolean } = { near = true, far = true }
const clamp: (number, number, number) -> number = math.clamp

-- Functions
--[=[
	Public: Get nearby light sources

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function _getNearbySources(signPos: Vector3, sources: types.SourceList, maxDistance: number): { types.LightSource }
	const nearby: { types.LightSource } = {}
	for _, source in sources do
		if source.isActive() then
			const dist = (source.getPosition() - signPos).Magnitude
			if dist <= maxDistance then
				nearby[#nearby + 1] = source
			end
		end
	end
	return nearby
end

--[=[
	Public: Computes reflector intensity

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function computeReflectorIntensity(part: BasePart, state, source: types.LightSource, MPH: number): (boolean | number, boolean | number)

	--[[
		             __________________________________________________________
		Intensity = |  Σ  [ DotAlignment * DistanceFactor * WedgeFactor * ProximityFactor * LightIntensity ]
		             ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
		Clamped between 0 and 1

	]]

	--	debugger.assert(part:IsA("BasePart"), "InvalidInstance", "BasePart", part.ClassName)

	const config = config.getConfig()

	const baseIntensity:number = state.baseIntensity

	local intensity:number = 0
	local finalTransparency:number = 1

	local hybridTransparencyMultiplier:number = 1

	const partCFrame:CFrame = state.CFrame
	const partPosition:Vector3 = partCFrame.Position

	const face:string? = state.faceAttributeName

	local hybridFadeRange:number = 0
	local hybridMinDistance:number = 0
	local hybridCanKeepColorsAttribute:boolean? = nil
	local hybridTransparencyAttribute:number? = nil

	local canHybridKeepColors: boolean = false

	local maxDot: number = 0

	if state.isHybrid then
		maxDot =  math.cos(config.General.lightHalfAngle)
		hybridFadeRange = state.hybridFadeRange
		hybridMinDistance = state.hybridMinDistance
		hybridTransparencyMultiplier = state.hybridTransparencyMultiplier

		canHybridKeepColors = state.canHybridKeepColors
	end -- Added isHybrid if-block since :GetAttribute() calls may be expensive?

	const seatPos: Vector3 = source.getPosition()
	const dir:Vector3 = source.getDirection()

	const predictionFactor: number = 0.5

	const offset: number = MPH * predictionFactor

	const pos: Vector3 = seatPos + dir * offset

	const lightIntensity: number = source.getIntensity(source.Owner)  or 1

	const change: Vector3 = partPosition - pos

	const toPart: Vector3 = change.Unit
	const dot: number =  clamp(dir:Dot(toPart), 0, 1)

	const dist: number = change.Magnitude
	const distFactor: number = clamp(1 - (dist / config.ReflectorConfig.maxDistance), 0, 1)

	local wedgeFactor: number = 1

	if state.isWedge then
		const toLight: Vector3 = -toPart
		const rawDot: number = state.slopeNormalWorld:Dot(toLight)

		--	part:SetAttribute("RawDOT", rawDot) -- Kept as reference for debugging

		if rawDot <= 0 then
			wedgeFactor = 0
		else
			const dotClamped: number = clamp(rawDot, 0, 1)
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

		const facedot: number = math.max(0, state.faceNormalWorld:Dot(-toPart)) -- clamping seems to bug

		--	part:SetAttribute("DOT", facedot) -- Kept as reference for debugging

		if facedot <= config.ReflectorConfig.hybridFacingDotThreshold then -- Usually near 0
			--continue
			return false, false
		end
	end

	const proximityFactor = (dist < config.ReflectorConfig.minDistance) and (dist / config.ReflectorConfig.minDistance) or 1

	intensity += dot * distFactor * wedgeFactor * proximityFactor * (lightIntensity or 1)

	if state.isHybrid then
		if canHybridKeepColors == false then intensity = .5 end

		const distFade: number = clamp(dist / hybridFadeRange, 0, 1)

		if distFade <= 0 then
			return false, false
		end

		const distanceFactor: number = clamp(1 - (dist / hybridFadeRange), 0, 1)

		const angleFade: number = math.sqrt(1 - dot) -- different equation since it's a smaller part
		const baseTransparency: number = (dot <= 0.1) and 1 or
			(distFade * 0.3 + angleFade * 0.7)

		const proximityFactor: number = (dist < hybridMinDistance) and (dist /  hybridMinDistance) or 1

		const dotClamped: number = clamp((dot - maxDot) / (1 - maxDot), 0, 1)
		const angleContribution: number = 1 - dotClamped
		const distContribution: number = baseTransparency

		local weightedTransparency: number = (baseTransparency * proximityFactor * angleContribution)

		weightedTransparency += (1 - weightedTransparency) * distFade

		finalTransparency = math.min(finalTransparency, weightedTransparency)
	end

	return clamp(intensity * baseIntensity, 0, 1), if intensity > 0 then clamp(finalTransparency*hybridTransparencyMultiplier, 0.5, 1) else 1
end

--[=[
	Public: Computes sign intensity

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function computeSignIntensity(entity: types.SignEntity, part : BasePart, decal : Decal, rangeType: types.RangeType, activeSources: types.SourceList)

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

	const config = config.getConfig()

	--debugger.assert(part:IsA("BasePart"), "InvalidInstance", "BasePart", part.ClassName) Removed since :IsA() calls are expensive
	debugger.assert(rangeTypes[rangeType], "InvalidType", `either "far" or "near"`, rangeType)

	const baseIntensity:number = part:GetAttribute(config.Constraints.BASE_INTENSITY_ATTRIBUTE) or 1

	const FadeDistance:number = config.SignConfig.maxFadeDistance
	const MinFadeDistance:number = config.SignConfig.minFadeDistance

	const partCFrame:CFrame = entity.CFrame
	const partPosition:Vector3 = partCFrame.Position
	const partSize:Vector3 = entity.Size -- probably offers a bit of optimization?

	-- INFO OF VARIABLES:
	--   	Transparency affects the ImageLabel with the sign (SurfaceGui.ImageLabel)
	--   	Brightness affects SurfaceGui.Brightness
	--      Light affects SurfaceGui.LightInfluence

	local finalTransparency:number = 1
	local finalBrightness:number = 0
	local finalLightInfluence:number = 1

	const partVeryReflective:boolean? = entity.partVeryReflective

	local count:number = 0

	const nearbySources: { types.LightSource } = _getNearbySources(partPosition, activeSources, config.SignConfig.maxFadeDistance + 500)
	if #nearbySources == 0 then
		return { transparency = 1, brightness = 0, lightInfluence = 0 }
	end

	local hasActiveLight: boolean = false
	const maxDot: number = math.cos(config.General.lightHalfAngle)

	for _: number, light: types.LightSource in nearbySources do
		count += 1

		const seatPos: Vector3 = light.getPosition()
		const carLook: Vector3 = light.getDirection()
		const intensity: number = light.getIntensity(light.Owner) or 1

		const dist: number = (seatPos - partPosition).Magnitude

		const isReflective: boolean = (partVeryReflective)
			or (partSize.X > 2.5 or partSize.Y > 2.5 or partSize.Z > 2.5)


		const fadeRange: number = (rangeType == "near") and (isReflective and FadeDistance or FadeDistance / 2)
			or (isReflective and FadeDistance * 2 or FadeDistance)

		const distFade: number = clamp(dist / fadeRange, 0, 1)

		const distanceFactor : number= clamp(1 - (dist / fadeRange), 0, 1)

		const toDecal: Vector3 = (partPosition - seatPos).Unit

		const dot: number = clamp(carLook:Dot(toDecal), 0, 1)
		const angleFade: number = clamp(((1 - dot) ^ 2.5) * (distanceFactor * 2 + 0.7), 0, 1)
		const baseTransparency: number = (dot <= 0.1) and 1 or (distFade * 0.2 + angleFade * 0.8)
		const proximityFactor: number = (dist < MinFadeDistance) and (dist / MinFadeDistance) or 1

		const dotClamped: number = clamp((dot - maxDot) / (1 - maxDot), 0, 1)
		const angleContribution: number = 1 - dotClamped
		const distContribution: number = baseTransparency

		const faceNormalconst: Vector3 = Vector3.FromNormalId(decal.Face)
		const faceNormalWorld: Vector3 = partCFrame:VectorToWorldSpace(faceNormalconst)

		const toLight: Vector3 = (seatPos - partPosition).Unit
		const facedot: number = clamp(faceNormalWorld:Dot(toLight), 0, 1)

		--	part:SetAttribute("DOT", facedot) -- Kept as reference for debugging

		if facedot <= config.SignConfig.decalFacingDotThreshold then -- Usually near 0
			continue
		end

		if dist < config.SignConfig.maxFadeDistance and dot > 0 then
			const weightedTransparency = (baseTransparency * proximityFactor * angleContribution) / intensity
			const weightedBrightness = ((1 + (1 - distContribution) * 0.25 + angleContribution * 0.25) * proximityFactor + (1 - proximityFactor))  * intensity
			const weightedLightInfluence = ((distContribution * 0.5 + angleContribution * 0.5) * proximityFactor + (1 - proximityFactor)) / intensity

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

-- Return public variables and API
return table.freeze({
	Name = "equations",
	computeSignIntensity = computeSignIntensity,
	computeReflectorIntensity = computeReflectorIntensity
}) :: types.Equations
