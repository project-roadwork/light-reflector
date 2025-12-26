--!strict
--!native
-- USAGE: lightreflector/shared/types.luau
-- Types for Light Reflector.

export type LightSource = {
	Owner: Instance,                          -- The vehicle or object emitting light
	getPosition: () -> Vector3,               -- Function returning the position of the light
	getDirection: () -> Vector3,              -- Function returning the forward direction of the light
	isActive: () -> boolean | () -> number,                  -- Function returning whether the light is currently active
	Intensity: number,                        -- Optional intensity multiplier
}

export type SourceList = { LightSource }     -- An array of LightSource

export type RangeType = "near" | "far"

-- Fade/Intensity result
export type IntensityData = {
	transparency: number,
	brightness: number,
	light: number,
}

export type Configuration = {
	MphScale: number,
	ReflectorConfig: {
		Enabled: boolean,
		PartName: string
	}
}

export type VehicleMap = {[Instance | Vehicle]: any} -- for getFastestDriveSeat

export type Utils = {
	deepMerge: (defaults: table, overrides: table) -> (),
	assignConfig: (userConfig: table?) -> Configuration,
	getSpeedMPH: (DriveSeat: VehicleSeat) -> number,
	adaptiveWait: (minFPS: number, maxFPS: number, DriveSeat: VehicleSeat?) -> number,
	getFastestDriveSeat: (Vehicles: VehicleMap) -> VehicleSeat?,
	isPavementReflector: (part: BasePart) -> boolean,
	fixPartOrientation: (part: BasePart, decal: Decal) -> (),
	normalizeBaseColor: (part: BasePart) -> ()
}

export type Dict = { [string | number]: any }


-- Configuration related to day/night cycles
export type DarkClockConfig = {
	DarkClockTimeStart: number,
	DarkClockTimeEnd: number,
}

-- Weather system dictionary
export type DarkWeathers = { [string]: boolean }

-- The main function returns a boolean
export type IsDarkEnvironmentFn = () -> boolean

-- Vehicle map
export type Vehicle = {
	DriveSeat: VehicleSeat,
	Body: Model
}


-- SurfaceGui tracking
export type SurfaceGuiState = {
	gui: SurfaceGui?,
	currentTransparency: number,
	currentBrightness: number,
	currentLight: number,
	targetTransparency: number,
	targetBrightness: number,
	targetLight: number,
}


export type SurfaceGuiStates = { [BasePart]: SurfaceGuiState }

-- Reflector state
export type ReflectorState = {
	currentIntensity: number,
	targetIntensity: number,

	baseColor: Color3,
	isActive: boolean?,
}

export type ReflectorStates = { [BasePart]: ReflectorState }

-- Pavement reflectors
export type PavementMap = { [BasePart]: true }



-- Dark weathers map
export type DarkWeathers = { [string]: boolean }



export type PoolerType<T> = {
	Get: () -> T,
	Return: (T) -> (),
	Clear: () -> (),
}


return {}
