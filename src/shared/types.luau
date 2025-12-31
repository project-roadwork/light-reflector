--!strict
--!native
-- USAGE: lightreflector/shared/types.luau
-- Types for Light Reflector.

--[[

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at https://mozilla.org/MPL/2.0/.

]]

export type LightSource = {
	Owner: Instance,
	getPosition: () -> Vector3,
	getDirection: () -> Vector3,
	isActive: () -> boolean | () -> number,
	getIntensity: () -> number,
}

export type SourceList = { LightSource }

export type RangeType = "near" | "far"

export type IntensityData = {
	transparency: number,
	brightness: number,
	light: number,
}

export type Configuration = {
	[string]: any,

	SignConfig: { [string]: any },
	ReflectorConfig: { [string]: any },
}

export type VehicleMap = {[Instance & Vehicle]: any}

export type Utils = {
	deepMerge: (defaults: {}, overrides: {}) -> (),
	assignConfig: (userConfig: {}?) -> Configuration,
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

export type SurfaceGuiTemplate = SurfaceGui & {
	ImageLabel: ImageLabel
}

export type SurfaceGuiStates = { [BasePart]: SurfaceGuiState }

export type ReflectorState = {
	currentIntensity: number,
	targetIntensity: number,

	baseColor: Color3,
	isActive: boolean?,

	lastMaterial: Enum.Material,
	lastColor: Color3,

	isHybrid: boolean?,
	targetTransparency: number,
	currentTransparency: number,
	lastTransparency: number,
}

export type ReflectorStates = { [BasePart]: ReflectorState }

export type PavementMap = { [BasePart]: true }

return {}
