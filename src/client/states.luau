--!native
--!strict
-- USAGE: lightreflector/client/states.luau
-- State templates, creator, and pooler for Light Reflector

--[[

    SPDX-FileCopyrightText: 2025-2026 Illinois_Roadbuff (Rogue Jr) <illinois_roadbuff@proton.me>
    SPDX-FileCopyrightText: 2025-2026 Project Roadwork and Contributors

    SPDX-License-Identifier: MPL-2.0

  	 This Source Code Form is subject to the terms of the Mozilla Public
  	 License, v. 2.0. If a copy of the MPL was not distributed with this
 	 file, You can obtain one at https://mozilla.org/MPL/2.0/.

]]

--[[

	MOTIVATION OF POOLING TABLES:

		Each reflector has two tables, and each sign also has two tables. If
		there were 500 reflectors in the workspace (with Instance Streaming
		enabled) and 50 signs, there would be over 1100 tables in total.

		When the player is driving, reflectors and signs are going to stream
		out. The client is going to be creating tables and setting tables
		to `nil` every second, which may cause tremendeous GC pressure.

		Pooling tables may be a solution since it allows spare tables to be
		recycled; however, I am unsure of the overhead of pooling by itself.

		When viewing OSS projects, the only objects I see being "worth" of
		pooling are `thread`s and `Instance`s; howbeit, I have never seen
		tables being pooled before.

]]

-- IMPORTANT: Modules
const types = require("../shared/types")
const config: types.Configuration = require("../shared/config")
const utils: types.Utils = require("./utils")
const grid: types.GridModule = require("./grid")

-- IMPORTANT: Templates
const SIGN_STATE_TEMPLATE: types.SignEntity = {
	_inPool = false,
	CFrame = CFrame.new(0, 0, 0),
	Size = Vector3.new(0, 0, 0),
	partVeryReflective = false,
	baseIntensity = 1,
	doesSignMove = false,
	cellKey = {0, 0},
	partRenderMode = "SurfaceGui",
	surfaceGuiState = nil,
	decalState = nil,
	mainDecal = nil,
	neutralizedColor = Color3.new(1, 1, 1),
	colorAccum = vector.zero,
	intensityAccum = 0,
	lastFrame = 0
}

const DECAL_STATE_TEMPLATE: types.DecalState = {
	_inPool = false,
	currentBrightness = 0,
	targetBrightness = 0,
	baseColor = Color3.new(0, 0, 0),
	lastColor3 = Color3.new(0, 0, 0)
}

const SURFACE_GUI_STATE_TEMPLATE: types.SurfaceGuiState = {
	_inPool = false,
	gui = nil,
	currentTransparency = 1,
	currentBrightness = 0,
	currentLightInfluence = 1,
	isActive = true,
	isPendingRemoval = false,
	lastTransparency = 1,
	lastBrightness = 0,
	lastLightInfluence = 1,
	lastColor3 = Color3.new(0, 0, 0),

	targetTransparency = 1,
	targetBrightness = 0,
	targetLightInfluence = 1,
}

const REFLECTOR_STATE_TEMPLATE: types.ReflectorState = {
	_inPool = false,
	isActive = false,

	currentIntensity = 0,
	lastIntensity = 0.1,
	targetIntensity = 0,
	targetTransparency = 1,
	currentTransparency = 1,
	lastTransparency = 0,

	cellKey = {0, 0},

	baseColor = Color3.new(0, 0, 0),
	lastColor = Color3.new(0, 0, 0),
	origColor = Color3.new(0, 0, 0),
	lastMaterial = Enum.Material.SmoothPlastic,

	isWedge = false,
	isHybrid = false,
	CFrame = CFrame.new(0, 0, 0),
	baseIntensity = 1,

	hybridFadeRange = nil,

	hybridMinDistance = nil,

	hybridTransparencyMultiplier = 1,

	canHybridKeepColors = false,

	faceAttributeName = "",
	slopeNormalWorld = Vector3.new(0, 0, 0),
	faceNormalWorld = Vector3.new(0, 0, 0),

	doesReflectorMove = false,

	neutralizedColor = Color3.new(1, 1, 1),
	colorAccum = vector.zero,
	intensityAccum = 0,

	lastFrame = 0,
}

-- IMPORTANT: Pools
const pools: types.StatePools = {
	SignState = {},
	DecalState = {},
	SurfaceGuiState = {},
	ReflectorState = {},
}

-- Miscellaneous
type AnyTable = {[string]: any}

--[=[
	Private: Reset a state to a template
	@private

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function _resetToTemplate<T>(state: T, template: T): ()
	for k: string, v: any in (template :: AnyTable) do
		if k == "cellKey" then
			(state :: AnyTable)[k] = {0, 0} -- new table
		else
			(state :: AnyTable)[k] = v
		end
	end
end

--[=[
	Public: Acquires sign state

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function acquireSignState(part: BasePart, baseConfig: types.BASE_CONFIG): types.SignEntity
	const attributes: {[string]: any} = part:GetAttributes()

	const constraints: types.Constraints = baseConfig.Constraints
	const generalConfig: types.GeneralConfig = baseConfig.General
	const signConfig: types.SignConfig = baseConfig.SignConfig

	local partRenderMode: "Decal" | "SurfaceGui" = attributes[signConfig.partRenderModeAttributeName]
	partRenderMode = partRenderMode or constraints.SIGNS_PRIMARY_RENDER_MODE :: "Decal" | "SurfaceGui"

	const baseIntensity:number = attributes[constraints.BASE_INTENSITY_ATTRIBUTE] or 1

	const state: types.SignEntity = table.remove(pools.SignState) or table.clone(SIGN_STATE_TEMPLATE)

	state.CFrame = part.CFrame
	state.Size = part.Size
	state.partVeryReflective = attributes["VeryReflective"] or false
	state.baseIntensity = baseIntensity
	state.doesSignMove = attributes[generalConfig.movingPartAttribute] or false
	state.partRenderMode = partRenderMode

	state._inPool = false

	return state
end

--[=[
	Public: Acquires Decal state

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function acquireDecalState(): types.DecalState
	const state: types.DecalState = table.remove(pools.DecalState) or table.clone(DECAL_STATE_TEMPLATE)
	state._inPool = false

	return state
end

--[=[
	Public: Acquires SurfaceGui state

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function acquireSurfaceGuiState(): types.SurfaceGuiState
	const state: types.SurfaceGuiState = table.remove(pools.SurfaceGuiState) or table.clone(SURFACE_GUI_STATE_TEMPLATE)
	state._inPool = false

	return state
end

--[=[
	Public: Acquires reflector state

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function acquireReflectorState(part: BasePart, baseConfig: types.BASE_CONFIG, reflectorGrid: types.Grid): types.ReflectorState
	const attributes: {[string]: any} = part:GetAttributes() -- maybe this is faster than multiple :GetAttribute calls?

	const constraints: types.Constraints = baseConfig.Constraints
	const generalConfig: types.GeneralConfig = baseConfig.General
	const reflectorConfig: types.ReflectorConfig = baseConfig.ReflectorConfig

	const partCFrame: CFrame = part.CFrame

	const cellX: number?, cellZ: number? = grid.getCellKey(reflectorGrid, partCFrame.Position)

	const isHybrid: boolean = if reflectorConfig.isHybridEnabled then attributes[reflectorConfig.hybridAttributeName] else false
	const hybridTransparencyAttribute: number? = if isHybrid then attributes[reflectorConfig.hybridTransparencyAttribute] else nil
	const hybridCanKeepColorsAttribute: boolean? = if isHybrid then attributes[reflectorConfig.hybridKeepColorsAttribute] else nil

	const useWedge: boolean = reflectorConfig.useWedgeFacingDetection
	const isWedge: boolean = if useWedge then (part:IsA("WedgePart") or (part:IsA("Part") and part.Shape == Enum.PartType.Wedge)) else false

	const slopeNormalWorld: Vector3? = if isWedge then partCFrame:VectorToWorldSpace(Vector3.new(0,1,-1).Unit) else nil

	const faceAttributeName: string = attributes[reflectorConfig.faceAttributeName]

	local faceNormalWorld: Vector3?
	if faceAttributeName and utils.validFaces[faceAttributeName] then
		faceNormalWorld = partCFrame:VectorToWorldSpace(Vector3.FromNormalId(Enum.NormalId[faceAttributeName]))
	end

	const state: types.ReflectorState = table.remove(pools.ReflectorState) or table.clone(REFLECTOR_STATE_TEMPLATE)

	state._inPool = false

	state.cellKey = {cellX or 0, cellZ or 0}
	state.baseColor = attributes["BaseColor"] or state.baseColor
	state.origColor = attributes["OrigColor"] or state.origColor
	state.isWedge = isWedge
	state.isHybrid = isHybrid
	state.CFrame = partCFrame
	state.baseIntensity = attributes[constraints.BASE_INTENSITY_ATTRIBUTE] or 1

	state.hybridFadeRange = if isHybrid then
		(attributes[reflectorConfig.hybridMaxDistanceAttribute] or reflectorConfig.defaultHybridMaxDistance) else nil

	state.hybridMinDistance = if isHybrid then
		(attributes[reflectorConfig.hybridMinDistanceAttribute] or reflectorConfig.defaultHybridMinDistance) else nil

	state.hybridTransparencyMultiplier = if typeof(hybridTransparencyAttribute) == "number" then hybridTransparencyAttribute else
		reflectorConfig.defaultHybridTransparencyMultiplier

	state.canHybridKeepColors = if typeof(hybridCanKeepColorsAttribute) == "boolean" then hybridCanKeepColorsAttribute
		else reflectorConfig.defaultCanHybridKeepColors

	state.faceAttributeName = faceAttributeName
	state.slopeNormalWorld = slopeNormalWorld or state.slopeNormalWorld
	state.faceNormalWorld = faceNormalWorld or state.faceNormalWorld
	state.doesReflectorMove = attributes[generalConfig.movingPartAttribute]

	return state
end

--[=[
	Public: Returns Decal state

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function _returnDecalState(state: types.DecalState): ()
	if state._inPool then
		return
	end

	_resetToTemplate(state, DECAL_STATE_TEMPLATE)

	state._inPool = true
	table.insert(pools.DecalState, state)
end

--[=[
	Public: Returns SurfaceGui state

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function _returnSurfaceGuiState(state: types.SurfaceGuiState, surfaceGuiPool: types.Pool<types.SurfaceGuiTemplate>): ()
	if state._inPool then
		return
	end

	if state.gui then
		utils.resetSurfaceGui(surfaceGuiPool, state.gui)
		state.gui = nil
	end

	_resetToTemplate(state, SURFACE_GUI_STATE_TEMPLATE)

	state._inPool = true
	table.insert(pools.SurfaceGuiState, state)
end

--[=[
	Public: Returns sign state

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function returnSignState(state: types.SignEntity, surfaceGuiPool: types.Pool<types.SurfaceGuiTemplate>): ()
	if config.FLAGS.NO_STATE_POOLING then
		return
	end

	if state._inPool then
		return
	end

	if state.surfaceGuiState then
		_returnSurfaceGuiState(state.surfaceGuiState, surfaceGuiPool)
		state.surfaceGuiState = nil
	end

	if state.decalState then
		_returnDecalState(state.decalState)
		state.decalState = nil
	end

	state.mainDecal = nil

	_resetToTemplate(state, SIGN_STATE_TEMPLATE)

	state._inPool = true
	table.insert(pools.SignState, state)
end

--[=[
	Public: Returns reflector state

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function returnReflectorState(state: types.ReflectorState): ()
	if config.FLAGS.NO_STATE_POOLING then
		return
	end

	if state._inPool then
		return
	end

	_resetToTemplate(state, REFLECTOR_STATE_TEMPLATE)

	state._inPool = true
	table.insert(pools.ReflectorState, state)
end

-- Return public API
return table.freeze({
	name = "states",
	acquireDecalState = acquireDecalState,
	acquireSignState = acquireSignState,
	acquireReflectorState = acquireReflectorState,
	acquireSurfaceGuiState = acquireSurfaceGuiState,
	returnSignState = returnSignState,
	returnReflectorState = returnReflectorState,
})
