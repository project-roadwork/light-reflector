--!strict
--!native
local ReplicatedStorage = game:GetService("ReplicatedStorage")
-- USAGE: lightreflector/shared/types.luau
-- Types for Light Reflector.

--[[
    SPDX-FileCopyrightText: 2025-2026 Illinois_Roadbuff (Rogue Jr) <illinois_roadbuff@proton.me>
	SPDX-FileCopyrightText: 2025-2026 Project Roadwork and Contributors

	SPDX-License-Identifier: MPL-2.0

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at https://mozilla.org/MPL/2.0/.

]]

-- Modules
local grid = require(ReplicatedStorage.Packages.lightreflector.client.grid)
const config = require("../shared/config")
const baseConfig = config.getConfig()
const debugger = require("../shared/debugger")
const jecs = require("../shared/jecs")
const pool = require("../client/pool")

-- Jecs Types
export type JecsModule = typeof(jecs)

-- Pool Types
export type PoolModule = typeof(pool)
export type Object = Instance


export type Pool<T> = {
	Objects: {T},
	ActiveObjects: {[T]: boolean},
	HierarchicalPools: { [T]: Pool<T> },

	ObjectTemplate: T,
	CreateObject: (T) -> T,
	ResetObject: (T) -> (),

	MinSize: number,
	MaxSize: number,

	UsageMetrics: {ActiveCount: number, AvailableCount: number, PeakActive: number},
	Logger: any,
	Mutex: any,

	ObjectTaken: any,
	ObjectReturned: any,

	GetObject: (Pool<T>) -> T?,
	ReturnObject: (Pool<T>, T) -> (boolean, string?),

	Prewarm: (Pool<T>, number) -> (),
	CreateLog: (Pool<T>, string, string) -> (),
}

-- Debugger Types
export type Debugger = typeof(debugger)
export type DebuggerLogs = typeof(require("../shared/logs"))

-- Configuration Types
export type Configuration = typeof(config)
export type BaseConfig = typeof(baseConfig) -- kind of lazy but adding types for each configuration value is a lot of work
export type Constraints = typeof(baseConfig.Constraints)
export type GeneralConfig = typeof(baseConfig.General)
export type ReflectorConfig = typeof(baseConfig.ReflectorConfig)
export type SignConfig = typeof(baseConfig.SignConfig)
export type ConfigKeys = typeof(baseConfig.Constraints.KEYS)
export type BASE_CONFIG = typeof(baseConfig)

-- Grid Types
export type GridModule = typeof(grid)

export type EntityId = jecs.Entity<nil>
type Key = string | number

export type Grid = {
	CellSize: number,

	Position: {[Key]: Vector3},
	Part: {[Key]: BasePart}?,

	CellCoords: {[Key]: Vector2},
	Cells: {[number]: {[number]: {Key}}},
	Coarse: {[number]: {[number]: {x: number, z: number}}},

	CellIndex: {[Key]: {x: number, z: number, i: number}},
	Dirty: {[Key]: boolean},

	CellCache: {[number]: {Key}?},
	EntityMap: {[Key]: EntityId},

	_ReconciledThisQuery: {[Key]: boolean},
	_QueryLock: boolean,

	_scratchParts: {BasePart},
	_scratchIds: {EntityId},
}

-- Sources Types
export type LightSource = {
	Owner: BasePart,
	Model: Model?,
	getPosition: () -> Vector3,
	getDirection: () -> Vector3,
	isActive: (BasePart) -> boolean,
	getIntensity: (BasePart) -> number,
	getColor: (BasePart) -> vector
}

export type SourceList = { LightSource }
export type IntensityData = {
	transparency: number,
	brightness: number,
	light: number,
}

export type SourcesModule = {
	read name: string,
	read list: SourceList,

	read create: (...any) -> LightSource,
	read add: (...any) -> LightSource,
	read register: (...any) -> LightSource,

	read anyActive: (...any) -> boolean,
	read getAllActive: (...any) -> {LightSource},
}

-- Utilities Types
export type Utils = {
	read name: string,

	read trackAncestryRemoval: (instance: Instance, callback: (Instance) -> ()) -> RBXScriptConnection,

	read getSpeedMPH: (source: BasePart) -> number,
	read adaptiveWait: ((number?) -> number, minFPS: number, maxFPS: number, source: BasePart?) -> (number, number),
	read adaptiveWaitWithSourcesOverride: ((number?) -> number, minFPS: number, maxFPS: number, source: BasePart?) -> (number, number),
	read getFastestSource: (sources: jecs.Cached_Query<BasePart>) -> BasePart?,

	read fixPartOrientation: (part: BasePart, decal: Decal) -> (),
	read normalizeBaseColor: (part: BasePart, isNormalizeEnabled: boolean) -> Color3,
	read resetSurfaceGui: (SurfaceGuiPool: Pool<SurfaceGuiTemplate>, gui: SurfaceGuiTemplate) -> (),
	read initSurfaceGuiPool: () -> Pool<SurfaceGuiTemplate>,
	read initPartPool: () -> Pool<Part>,

	read pcallRetry: ((...any) -> (...any), maxRetries: number, ...any) -> (boolean, string?),
	read areColorsEqual: (colorA: Color3, colorB: Color3, epsilon: number?) -> boolean,
	read areVectorsEqual: (vectorA: vector, vectorB: vector, epsilon: number?) -> boolean,
	read areColorsEqualRaw: (aR: number, aG: number, aB: number, bR: number, bG: number, bB: number, epsilon: number?) -> boolean,
	read renderWait: (waitTime: number?) -> number,

	read spawnDebugField: (origin: Vector3, forward: Vector3, maxDot: number, radius: number, count: number, debugFolder: Instance) -> (),

	read validFaces: { [string]: boolean },

	read copyPartProps: (part: Part, clone: Part) -> (),
}


-- Register Types
export type VehicleMap = {[Instance & Vehicle]: any}

export type CachedQueries = {
	SourceInstances: jecs.Cached_Query<BasePart>,
	Signs: jecs.Cached_Query<BasePart, RangeType>,
	Reflectors: jecs.Cached_Query<BasePart, ReflectorState>,
	SignStates: jecs.Cached_Query<SignEntity>,
	SignsPartsStates: jecs.Cached_Query<BasePart, SignEntity>,
	ReflectorStates: jecs.Cached_Query<ReflectorState>,
}

export type Components = {
	SourceInstance: jecs.Id<BasePart>,
	SourceDebugBox: jecs.Id<BasePart>,
	Reflector: jecs.Id<BasePart>,
	Sign: jecs.Id<BasePart>,
	ReflectorState: jecs.Id<ReflectorState>,
	SignState: jecs.Id<SignEntity>,
	SignInRange: jecs.Id<RangeType>,
}

export type Register = {
	read name: string,

	read getPartsByRaycast: () -> {[BasePart]: RangeType},


	read init: () -> (),
	read start: () -> (),

	read reflectorGrid: Grid,
	read signGrid: Grid,
	read surfaceGuiPool: Pool<SurfaceGuiTemplate>,
	read debugBoxTemplate: BasePart,

	read getWorldUtils: () -> (jecs.World, Components, {[Instance]: jecs.Entity}, CachedQueries),

	read isSourceRegistered: (source: BasePart) -> (boolean, jecs.Entity<nil>?),
	read addSource: (source: BasePart, model: Model?, isEnabled: (BasePart) -> boolean, getIntensity: (BasePart) -> number, getColor: (BasePart) -> vector, trackAncestry: boolean?) -> (),
	read removeSource: (source: BasePart) -> (),
	read addReflector: (part: Instance) -> (),
	read removeReflector: (part: BasePart) -> (),
	read addSign: (part: Instance, rangeType: RangeType?) -> (),
	read removeSign: (part: Instance) -> (),

	read clearConnections: () -> (),
	read reset: () -> (),
}

-- Equations Types
export type Equations = {
	read name: string,

	read computeReflectorIntensity: (
		part: BasePart,
		state: ReflectorState,
		lightSource: LightSource,
		MPH: number,
		config: BASE_CONFIG
	) -> (number, number),

	read computeSignIntensity: (

		part: BasePart,
		state: SignEntity,
		lightSource: LightSource,
		decal: Decal,
		rangeType: RangeType,
		config: BASE_CONFIG
	) -> {
		transparency: number,
		brightness: number,
		lightInfluence: number,
		hasActiveLight: boolean
	},

	read buildSamplePoints: (quality: number) -> (),
}

-- Detector Types
export type Detect = {
	read name: string,
	read currentDetectedEntities: {[jecs.Entity]: boolean},
	read activeReflectorEntities: {[jecs.Entity]: boolean },
	read init: () -> (),
	read start: () -> (),
	read reset: () -> (),
	read safeCancelThread: () -> (boolean, string?),
	read getDetectedEntities: () -> { [jecs.Entity]: boolean },
}

-- Renderer Types
export type Render = {
	read name: string,
	read init: () -> (),
	read start: () -> (),
	read reset: () -> (),
	read safeCancelThread: () -> (boolean, string?),
}

-- Misc Types
export type Dict = { [string | number]: any }
export type RangeType = "near" | "far"

-- Dark Types
export type DarkClockConfig = {
	DarkClockTimeStart: number,
	DarkClockTimeEnd: number,
}

export type DarkWeathers = { [string]: boolean }

export type IsDarkEnvironmentFn = () -> boolean

export type Vehicle = {
	DriveSeat: VehicleSeat,
	Body: Model
}

-- States
export type SurfaceGuiState = {
	_inPool: boolean,
	gui: SurfaceGuiTemplate?,
	currentTransparency: number,
	currentBrightness: number,
	currentLightInfluence: number,
	targetTransparency: number,
	targetBrightness: number,
	targetLightInfluence: number,
	isPendingRemoval: boolean,
	isActive: boolean,
	lastTransparency: number,
	lastBrightness: number,
	lastLightInfluence: number,
	lastColor: vector
}

export type DecalState = {
	_inPool: boolean,
	baseColor: vector,
	currentBrightness: number,
	targetBrightness: number,
	lastColor: vector
}

export type SurfaceGuiTemplate = SurfaceGui & {
	ImageLabel: ImageLabel
}

export type SurfaceGuiStates = { [BasePart]: SurfaceGuiState }

export type DecalStates = { [BasePart]: DecalState }

export type ReflectorState = {
	_inPool: boolean,
	currentIntensity: number,
	targetIntensity: number,
	lastIntensity: number,
	baseIntensity: number,

	baseColor: vector,
	origColor: vector,
	isActive: boolean?,
	lastIsActive: boolean?,

	lastMaterial: Enum.Material,
	lastColor: vector,

	isHybrid: boolean?,
	isMarking: boolean?,
	hybridFadeRange: number?,
	hybridMinDistance: number?,
	hybridTransparencyMultiplier: number,
	canHybridKeepColors: boolean,
	targetTransparency: number,
	lastTargetIntensity: number,
	currentTransparency: number,
	lastTransparency: number,

	doesReflectorMove: boolean,
	cellKey: vector,
	CFrame: CFrame,
	isWedge: boolean,
	faceAttributeName: string?,
	slopeNormalWorld: Vector3?,
	faceNormalWorld: Vector3?,

	neutralizedColor: vector,
	colorAccum: vector,
	intensityAccum: number,

	lastFrame: number,
}

export type SignEntity = {
	_inPool: boolean,
	CFrame: CFrame,
	Size: Vector3,
	partVeryReflective: boolean?,
	baseIntensity: number,
	doesSignMove: boolean,
	partRenderMode: "SurfaceGui" | "Decal",
	surfaceGuiState: SurfaceGuiState?,
	decalState: DecalState?,
	mainDecal: Decal?,
	cellKey: vector,

	neutralizedColor: vector,
	colorAccum: vector,
	intensityAccum: number,

	lastFrame: number,
}

-- Init module
export type LightReflector = {
	read init: () -> (),
	read start: () -> (),
	read reset: () -> (),
	read config: Configuration,
	read register: Register,
}

-- States module types
export type StatesModule = {
	read name: string,

	read acquireDecalState: () -> DecalState,
	read acquireSignState: (part: BasePart, baseConfig: BASE_CONFIG, signGrid: Grid) -> SignEntity,
	read acquireReflectorState: (part: BasePart, baseConfig: BASE_CONFIG, reflectorGrid: Grid) -> ReflectorState,
	read acquireSurfaceGuiState: () -> SurfaceGuiState,

	read returnSignState: (state: SignEntity, surfaceGuiPool: Pool<SurfaceGuiTemplate>) -> (),
	read returnReflectorState: (state: ReflectorState) -> (),
}

export type StatePools = {
	SignState: {SignEntity},
	DecalState: {DecalState},
	SurfaceGuiState: {SurfaceGuiState},
	ReflectorState: {ReflectorState},
}

-- Return
return {}
