--!strict
--!native
-- USAGE: lightreflector/shared/types.luau
-- Types for Light Reflector.

export type LightSource = {
	Owner: Instance,
	getPosition: () -> Vector3,
	getDirection: () -> Vector3,
	isActive: () -> boolean | () -> number,
	Intensity: number,
}

export type SourceList = { LightSource }

export type RangeType = "near" | "far"

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

export type VehicleMap = {[Instance | Vehicle]: any}

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

export type ReflectorState = {
	currentIntensity: number,
	targetIntensity: number,

	baseColor: Color3,
	isActive: boolean?,
}

export type ReflectorStates = { [BasePart]: ReflectorState }

export type PavementMap = { [BasePart]: true }

export type PoolerType<T> = {
	Get: () -> T,
	Return: (T) -> (),
	Clear: () -> (),
}

return {}
