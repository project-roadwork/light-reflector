--!strict
--!native
-- USAGE: lightreflector/shared/types.luau
-- Types for Light Reflector.

--[[

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at https://mozilla.org/MPL/2.0/.

]]

-- Modules
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
export type Pool = {
	Objects: {Object},
	ActiveObjects: {Object},
	HierarchicalPools: { [Object]: Pool },
	ObjectTemplate: Object,
	CreateObject: (Object) -> Object,
	ResetObject: (Object) -> (),
	MinSize: number, MaxSize: number,
	UsageMetrics: {ActiveCount: number, AvailableCount: number, PeakActive: number},
	Logger: any, Mutex: any,
	ObjectTaken: any, ObjectReturned: any,
	GetObject: (Pool) -> Object,
	ReturnObject: (Pool, Object) -> (boolean, string?),
	Prewarm: (Pool, number) -> (),
	CreateLog: (Pool, string, string) -> (),
}

-- Debugger Types
export type Debugger = typeof(debugger)
export type DebuggerLogs = typeof(require("../shared/logs"))

-- Configuration Types
export type Configuration = typeof(config)
export type BaseConfig = typeof(baseConfig)
export type Constraints = typeof(baseConfig.Constraints)
export type GeneralConfig = typeof(baseConfig.General)
export type ReflectorConfig = typeof(baseConfig.ReflectorConfig)
export type SignConfig = typeof(baseConfig.SignConfig)
export type ConfigKeys = typeof(baseConfig.Constraints.KEYS)
export type BASE_CONFIG = typeof(baseConfig)

-- Grid Types
export type GridModule = typeof(require("../client/grid"))

export type EntityId = number | vector | jecs.Entity
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
	Owner: Instance,
	getPosition: () -> Vector3,
	getDirection: () -> Vector3,
	isActive: () -> boolean | () -> number,
	getIntensity: (Instance) -> number,
}

export type SourceList = { LightSource }
export type IntensityData = {
	transparency: number,
	brightness: number,
	light: number,
}

export type SourcesModule = {
	Name: string,
	list: SourceList,

	create: (...any) -> LightSource,
	add: (...any) -> LightSource,
	register: (...any) -> LightSource,

	anyActive: (...any) -> boolean,
	getAllActive: (...any) -> {LightSource},
}

-- Utilities Types
export type Utils = {
	Name: string,

	deepMerge: (defaults: Dict, overrides: Dict, path: string?) -> (),
	trackAncestryRemoval: (instance: Instance, callback: (Instance) -> ()) -> RBXScriptConnection,
	configure: (userConfig: Dict) -> Configuration,

	getSpeedMPH: (DriveSeat: VehicleSeat) -> number,
	adaptiveWait: ((number?) -> number, minFPS: number, maxFPS: number, DriveSeat: VehicleSeat?) -> (number, number),
	adaptiveWaitWithSourcesOverride: ((number?) -> number, minFPS: number, maxFPS: number, DriveSeat: VehicleSeat?) -> (number, number),
	getFastestDriveSeat: (Vehicles: jecs.Cached_Query<Instance>) -> VehicleSeat?,

	fixPartOrientation: (part: BasePart, decal: Decal) -> (),
	normalizeBaseColor: (part: BasePart, isNormalizeEnabled: boolean) -> Color3,
	resetSurfaceGui: (SurfaceGuiPool: Pool, gui: SurfaceGuiTemplate) -> (),
	initPool: () -> Pool,

	pcallRetry: ((...any) -> (...any), maxRetries: number, ...any) -> (boolean, string?),
	areColorsEqual: (colorA: Color3, colorB: Color3, epsilon: number?) -> boolean,
	renderWait: (waitTime: number?) -> number,

	validFaces: { [string]: boolean },
}

-- Register Types
export type VehicleMap = {[Instance & Vehicle]: any}

export type CachedQueries = {
	VehicleInstances: jecs.Cached_Query<Instance>,
	Signs: jecs.Cached_Query<Instance, RangeType>,
	Reflectors: jecs.Cached_Query<BasePart, ReflectorState>,
	SignStates: jecs.Cached_Query<SignEntity>,
	SignsPartsStates: jecs.Cached_Query<Instance, SignEntity>,
	ReflectorStates: jecs.Cached_Query<ReflectorState>,
	Vehicles: jecs.Cached_Query<Instance>,
}

export type Components = {
	VehicleInstance: jecs.Id<Instance>,
	VehicleDebugBox: jecs.Id<BasePart>,
	Reflector: jecs.Id<BasePart>,
	Sign: jecs.Id<Instance>,
	ReflectorState: jecs.Id<ReflectorState>,
	SignState: jecs.Id<SignEntity>,
	SignInRange: jecs.Id<RangeType>,
}

export type Register = {
	Name: string,

	getPartsByRaycast: () -> {[BasePart]: RangeType},

	start: () -> (),

	reflectorGrid: Grid,
	surfaceGuiPool: Pool,
	debugBoxTemplate: BasePart,

	getWorldUtils: () -> (jecs.World, Components, {[Instance]: jecs.Entity}, CachedQueries),

	scriptConnections: {[RBXScriptConnection]: boolean},

	registerVehicle: (car: Instance & Vehicle, isEnabled: (Instance) -> boolean, getIntensity: (Instance) -> number) -> (),
	unregisterVehicle: (car: Vehicle & Instance) -> (),
	registerReflector: (part: Instance) -> (),
	unregisterReflector: (part: BasePart) -> (),
	clearConnections: () -> (),
	reset: () -> (),
}

-- Equations Types
export type Equations = {
	Name: string,

	computeReflectorIntensity: (
		part: BasePart,
		state: ReflectorState,
		source: LightSource,
		MPH: number
	) -> (boolean | number, boolean | number),

	computeSignIntensity: (
		entity: SignEntity,
		part: BasePart,
		decal: Decal,
		rangeType: RangeType,
		activeSources: SourceList
	) -> {
		transparency: number,
		brightness: number,
		lightInfluence: number,
	}
}

-- Detector Types
export type Detect = {
	Name: string,
	currentDetectedParts: {[BasePart]: boolean},
	activeReflectorEntities: {[jecs.Entity]: boolean },
	start: () -> (),
	reset: () -> (),
	safeCancelThread: () -> (boolean, string?),
	getDetectedParts: () -> { [Instance]: boolean },
}

-- Renderer Types
export type Render = {
	Name: string,
	start: () -> (),
	reset: () -> (),
	safeCancelThread: () -> (boolean, string?),
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
}

export type DecalState = {
	baseColor: Color3,
	currentBrightness: number,
	targetBrightness: number,
}

export type SurfaceGuiTemplate = SurfaceGui & {
	ImageLabel: ImageLabel
}

export type SurfaceGuiStates = { [BasePart]: SurfaceGuiState }

export type DecalStates = { [BasePart]: DecalState }

export type ReflectorState = {
	currentIntensity: number,
	targetIntensity: number,
	lastIntensity: number,

	baseColor: Color3,
	isActive: boolean?,

	lastMaterial: Enum.Material,
	lastColor: Color3,

	isHybrid: boolean?,
	targetTransparency: number,
	currentTransparency: number,
	lastTransparency: number,

	doesReflectorMove: boolean,
	cellKey: { [number]: number },
	CFrame: CFrame,
	isWedge: boolean,
	faceAttributeName: string?,
	slopeNormalWorld: Vector3?,
	faceNormalWorld: Vector3?,
}


export type SignEntity = {
	partRenderMode: "SurfaceGui" | "Decal",
	surfaceGuiState: SurfaceGuiState?,
	decalState: DecalState?,
	mainDecal: Decal?,
	part: BasePart?,
	doesSignMove:boolean,
	CFrame: CFrame,
	Size: Vector3,
	partVeryReflective: boolean?,
}

export type LightReflector = {
	start: () -> (),
	cleanup: () -> (),
	config: Configuration,
	register: Register,
	utils: Utils,
}

-- Return
return {}
