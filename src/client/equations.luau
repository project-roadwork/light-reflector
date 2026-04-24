--!native
--!strict
-- USAGE: lightreflector/client/equations.luau
-- Intensity equations for Light Reflector

--[[
    SPDX-FileCopyrightText: 2025-2026 Illinois_Roadbuff <illinois_roadbuff@proton.me>
    SPDX-FileCopyrightText: 2025-2026 Project Roadwork and Contributors

    SPDX-License-Identifier: MPL-2.0

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at https://mozilla.org/MPL/2.0/.

]]

-- IMPORTANT: Modules
const types = require("../shared/types")
const debugger: types.Debugger = require("../shared/debugger")
const utils: types.Utils = require("./utils")
const grid: types.GridModule = require("./grid")

-- Variables
const rangeTypes: { [types.RangeType]: boolean } = { near = true, far = true }
const clamp: (number, number, number) -> number = math.clamp
const raycast: (WorldRoot, Vector3, Vector3, RaycastParams) -> RaycastResult? = workspace.Raycast

const rayParams: RaycastParams = RaycastParams.new()
rayParams.FilterType = Enum.RaycastFilterType.Exclude
rayParams.IgnoreWater = true

const SAMPLE_POINTS: {Vector3} = {}

--[=[
	Private: Computes the occlusion of a part via Raycast
	@private

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function _computeOcclusion(part: BasePart, CFrame: CFrame, Size: Vector3, lightPos: Vector3, samplePoints: {Vector3}, rayParams: RaycastParams, config:types.BASE_CONFIG): number
	const total: number = #samplePoints
	local hit: number = 0

	for _: number, offset: Vector3 in samplePoints do
		const worldPoint: Vector3 = CFrame:PointToWorldSpace(offset * Size)

		const dir: Vector3 = worldPoint - lightPos
		const result: RaycastResult? = raycast(workspace, lightPos, dir, rayParams)
		const instance: Instance? = result and result.Instance or nil
		const excludeTransparent: boolean = config.General.occlusionRaycastExcludeTransparent

		if instance and instance ~= part then
			if excludeTransparent then
				if instance.IsA(instance, "BasePart") and instance.Transparency ~= 1 then
					const transmittance: number = instance.Transparency ^ 2.5
					-- ^ light doesn't work like fractioning, so use an exponent instead of 1 - transparency
					hit += (1 - transmittance)
				end
			else
				hit += 1
			end
		end

		if excludeTransparent == false then
			if hit == total then
				return 0
			end

			if hit == 0 then
				return 1
			end -- Micro optimization
		end
	end

	return math.sqrt(1 - (hit / total))
end

--[=[
	Public: Computes reflector intensity

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function computeReflectorIntensity(part: BasePart, state, source: types.LightSource, MPH: number, config: types.BASE_CONFIG): (number, number)

	--[[
		             __________________________________________________________
		Intensity = |  Σ  [ DotAlignment * DistanceFactor * WedgeFactor * ProximityFactor * LightIntensity ]
		             ‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾‾
		Clamped between 0 and 1

	]]

	--	debugger.assert(part:IsA("BasePart"), "InvalidInstance", "BasePart", part.ClassName)

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

	const maxDot: number =  math.cos(config.General.lightHalfAngle)

	if state.isHybrid then
		--maxDot =  math.cos(config.General.lightHalfAngle)
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

	const coneFactor: number = if config.ReflectorConfig.useMaxDOT then
		(clamp((dot - maxDot) / (1 - maxDot), 0, 1)) ^ .42
		else 1

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
			return -1, -1
		end

		const facedot: number = math.max(0, state.faceNormalWorld:Dot(-toPart)) -- clamping seems to bug

		--	part:SetAttribute("DOT", facedot) -- Kept as reference for debugging

		if facedot <= config.ReflectorConfig.hybridFacingDotThreshold then -- Usually near 0
			--continue
			return -1, -1
		end
	end

	const proximityFactor = (dist < config.ReflectorConfig.minDistance) and (dist / config.ReflectorConfig.minDistance) or 1

	intensity += (dot * (coneFactor)) * distFactor * wedgeFactor * proximityFactor * (lightIntensity or 1)

	if state.isHybrid then
		if canHybridKeepColors == false then intensity = .5 end

		const distFade: number = clamp(dist / hybridFadeRange, 0, 1)

		if distFade <= 0 then
			return -1, -1
		end

		const distanceFactor: number = clamp(1 - (dist / hybridFadeRange), 0, 1)

		const angleFade: number = math.sqrt(1 - dot)
		const baseTransparency: number = (dot <= 0.1) and 1 or
			(distFade * 0.2 + angleFade * 0.8)

		const proximityFactor: number = (dist < hybridMinDistance) and (dist /  hybridMinDistance) or 1

		const dotClamped: number = clamp((dot - maxDot) / (1 - maxDot), 0, 1)
		const angleContribution: number = 1 - dotClamped
		const distContribution: number = baseTransparency

		local weightedTransparency: number = (baseTransparency * proximityFactor * angleContribution)

		weightedTransparency += (1 - weightedTransparency) * distFade

		finalTransparency = math.min(finalTransparency, weightedTransparency)
	end

	if config.ReflectorConfig.useRaycastForObstacles then
		intensity *= _computeOcclusion(part, state.CFrame, part.Size, seatPos, SAMPLE_POINTS, rayParams, config)
	end

	return clamp(intensity * baseIntensity, 0, 1), if intensity > 0 then clamp(finalTransparency*hybridTransparencyMultiplier, 0.5, 1) else 1
end

--[=[
	Public: Computes sign intensity

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function computeSignIntensity(part : BasePart, state: types.SignEntity,  source: types.LightSource, decal: Decal, rangeType: types.RangeType, config: types.BASE_CONFIG)

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

	const FadeDistance:number = config.SignConfig.maxFadeDistance
	const MinFadeDistance:number = config.SignConfig.minFadeDistance

	const partCFrame:CFrame = state.CFrame
	const partPosition:Vector3 = partCFrame.Position
	const partSize:Vector3 = state.Size -- probably offers a bit of optimization?

	-- INFO OF VARIABLES:
	--   	Transparency affects the ImageLabel with the sign (SurfaceGui.ImageLabel.ImageTransparency)
	--   	Brightness affects SurfaceGui.Brightness
	--      LightInfluence affects SurfaceGui.LightInfluence

	local transparency:number = 1
	local brightness:number = 0
	local lightInfluence:number = 1

	const partVeryReflective:boolean? = state.partVeryReflective

	local hasActiveLight: boolean = false
	const maxDot: number = math.cos(config.General.lightHalfAngle)

	const seatPos: Vector3 = source.getPosition()
	const carLook: Vector3 = source.getDirection()
	local intensity: number = source.getIntensity(source.Owner) or 1

	const dist: number = (seatPos - partPosition).Magnitude

	const isReflective: boolean = (partVeryReflective)
		or (partSize.X > 2.5 or partSize.Y > 2.5 or partSize.Z > 2.5)

	const fadeRange: number = (rangeType == "near") and (isReflective and FadeDistance or FadeDistance / 2)
		or (isReflective and FadeDistance * 2 or FadeDistance)

	const distFade: number = clamp(dist / fadeRange, 0, 1)

	const distanceFactor : number= clamp(1 - (dist / fadeRange), 0, 1)

	const toDecal: Vector3 = (partPosition - seatPos).Unit

	const dot: number = clamp(carLook:Dot(toDecal), 0, 1)
	const angleFade: number = clamp(math.sqrt(1 - dot) ^ 1.25, 0, 1)
	local baseTransparency: number = (dot <= 0.1) and 1 or (distFade * 0.3 + angleFade * 0.7)

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
		return {
			transparency = -1,
			brightness = -0,
			lightInfluence =-1,
		}
	end

	if dist < config.SignConfig.maxFadeDistance and dot > 0 then
		if config.SignConfig.useRaycastForObstacles then
			const configCustomExclude: {Instance} = config.General.occlusionRaycastExclude :: {Instance}

			if #configCustomExclude > 0 then
				rayParams.FilterDescendantsInstances = {source.Owner, table.unpack(configCustomExclude)}
			else
				rayParams.FilterDescendantsInstances = {source.Owner}
			end

			intensity *= _computeOcclusion(part, state.CFrame, state.Size, seatPos, SAMPLE_POINTS, rayParams, config)
		end

		transparency = (baseTransparency * proximityFactor * angleContribution) / intensity
		brightness = ((1 + (1 - distContribution) * 0.25 + angleContribution * 0.25) * proximityFactor + (1 - proximityFactor))  * intensity
		lightInfluence = ((distContribution * 0.5 + angleContribution * 0.5) * proximityFactor + (1 - proximityFactor)) / intensity

		hasActiveLight = true
	end

	if config.SignConfig.isDebugConeAngleEnabled then
		task.defer(utils.spawnDebugField, seatPos, carLook, maxDot,
			60,
			50,
			config.SignConfig.debugBoxFolder or workspace
		)

		task.defer(utils.spawnDebugField, seatPos, carLook, maxDot,
			120,
			100,
			config.SignConfig.debugBoxFolder or workspace
		)
	end

	return {
		transparency = transparency,
		brightness = brightness,
		lightInfluence = lightInfluence,
		hasActiveLight = hasActiveLight
	}
end

--[=[
	Public: Builds sample points to be used for raycasting

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function buildSamplePoints(quality: number)
	for x: number = 0, quality do
		for y: number = 0, quality do
			table.insert(SAMPLE_POINTS,
				Vector3.new(
					(x / quality) - 0.5,
					(y / quality) - 0.5,
					0
				)
			)
		end
	end
end

-- Return public variables and API
return table.freeze({
	name = "equations",
	computeSignIntensity = computeSignIntensity,
	computeReflectorIntensity = computeReflectorIntensity,
	buildSamplePoints = buildSamplePoints
}) :: types.Equations
