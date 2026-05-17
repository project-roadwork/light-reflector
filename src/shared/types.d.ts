// USAGE: lightreflector/shared/types.luau
// Types for Light Reflector.

/*
    SPDX-FileCopyrightText: 2025-2026 Illinois_Roadbuff (Rogue Jr) <illinois_roadbuff@proton.me>
	SPDX-FileCopyrightText: 2025-2026 Project Roadwork and Contributors

	SPDX-License-Identifier: MPL-2.0

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at https://mozilla.org/MPL/2.0/.

*/

// Jecs Types
export type JecsModule = typeof import("./jecs");

// Pool Types
export type PoolModule = any;
export type Object = Instance;

export type Pool<T> = {
  Objects: T[];
  ActiveObjects: T[];
  HierarchicalPools: { [key: string]: Pool<T> };

  ObjectTemplate: T;
  CreateObject: (obj: T) => T;
  ResetObject: (obj: T) => void;

  MinSize: number;
  MaxSize: number;

  UsageMetrics: {
    ActiveCount: number;
    AvailableCount: number;
    PeakActive: number;
  };
  Logger: any;
  Mutex: any;

  ObjectTaken: any;
  ObjectReturned: any;

  GetObject: (pool: Pool<T>) => T | undefined;
  ReturnObject: (pool: Pool<T>, obj: T) => [boolean, string?];

  Prewarm: (pool: Pool<T>, count: number) => void;
  CreateLog: (pool: Pool<T>, a: string, b: string) => void;
};

// Debugger Types
export type Debugger = any;
export type DebuggerLogs = any;

// Configuration Types
export type Configuration = any;
export type BaseConfig = any;
export type Constraints = any;
export type GeneralConfig = any;
export type ReflectorConfig = any;
export type SignConfig = any;
export type ConfigKeys = any;
export type BASE_CONFIG = any;

// Grid Types
export type GridModule = any;

export type EntityId = any;
type Key = string | number;

export type Grid = {
  CellSize: number;

  Position: { [key: string]: Vector3 };
  Part?: { [key: string]: BasePart };

  CellCoords: { [key: string]: Vector2 };
  Cells: { [x: number]: { [z: number]: Key[] } };
  Coarse: { [x: number]: { [z: number]: { x: number; z: number } } };

  CellIndex: { [key: string]: { x: number; z: number; i: number } };
  Dirty: { [key: string]: boolean };

  CellCache: { [x: number]: Key[] | undefined };
  EntityMap: { [key: string]: EntityId };

  _ReconciledThisQuery: { [key: string]: boolean };
  _QueryLock: boolean;

  _scratchParts: BasePart[];
  _scratchIds: EntityId[];
};

// Sources Types
export type LightSource = {
  Owner: BasePart;
  Model?: Model;
  getPosition: () => Vector3;
  getDirection: () => Vector3;
  isActive: (part: BasePart) => boolean;
  getIntensity: (part: BasePart) => number;
  getColor: (part: BasePart) => vector;
};

export type SourceList = LightSource[];

export type IntensityData = {
  transparency: number;
  brightness: number;
  light: number;
};

export type SourcesModule = {
  readonly name: string;
  readonly list: SourceList;

  readonly create: (...args: any[]) => LightSource;
  readonly add: (...args: any[]) => LightSource;
  readonly register: (...args: any[]) => LightSource;

  readonly anyActive: (...args: any[]) => boolean;
  readonly getAllActive: (...args: any[]) => LightSource[];
};

// Utilities Types
export type Utils = {
  readonly name: string;

  readonly trackAncestryRemoval: (
    instance: Instance,
    callback: (i: Instance) => void,
  ) => RBXScriptConnection;

  readonly getSpeedMPH: (source: BasePart) => number;
  readonly adaptiveWait: (
    fn: (n?: number) => number,
    minFPS: number,
    maxFPS: number,
    source?: BasePart,
  ) => [number, number];
  readonly adaptiveWaitWithSourcesOverride: (
    fn: (n?: number) => number,
    minFPS: number,
    maxFPS: number,
    source?: BasePart,
  ) => [number, number];
  readonly getFastestSource: (sources: any) => BasePart | undefined;

  readonly fixPartOrientation: (part: BasePart, decal: Decal) => void;
  readonly normalizeBaseColor: (
    part: BasePart,
    isNormalizeEnabled: boolean,
  ) => Color3;
  readonly resetSurfaceGui: (
    pool: Pool<SurfaceGuiTemplate>,
    gui: SurfaceGuiTemplate,
  ) => void;
  readonly initSurfaceGuiPool: () => Pool<SurfaceGuiTemplate>;
  readonly initPartPool: () => Pool<Part>;

  readonly pcallRetry: (
    fn: (...args: any[]) => any,
    maxRetries: number,
    ...args: any[]
  ) => [boolean, string?];
  readonly areColorsEqual: (a: Color3, b: Color3, epsilon?: number) => boolean;
  readonly areVectorsEqual: (a: vector, b: vector, epsilon?: number) => boolean;
  readonly copyPartProps: (part: Part, clone: Part) => void;
  readonly areColorsEqualRaw: (
    aR: number,
    aG: number,
    aB: number,
    bR: number,
    bG: number,
    bB: number,
    epsilon?: number,
  ) => boolean;
  readonly renderWait: (waitTime?: number) => number;

  readonly spawnDebugField: (
    origin: Vector3,
    forward: Vector3,
    maxDot: number,
    radius: number,
    count: number,
    debugFolder: Instance,
  ) => void;

  readonly validFaces: { [key: string]: boolean };
};

// Register Types
export type VehicleMap = { [key: string]: any };

export type CachedQueries = {
  SourceInstances: any;
  Signs: any;
  Reflectors: any;
  SignStates: any;
  SignsPartsStates: any;
  ReflectorStates: any;
};

export type Components = {
  SourceInstance: any;
  SourceDebugBox: any;
  Reflector: any;
  Sign: any;
  ReflectorState: any;
  SignState: any;
  SignInRange: any;
};

export type Register = {
  readonly name: string;

  readonly getPartsByRaycast: () => { [part: string]: RangeType };

  readonly init: () => void;
  readonly start: () => void;

  readonly reflectorGrid: Grid;
  readonly signGrid: Grid;
  readonly surfaceGuiPool: Pool<SurfaceGuiTemplate>;
  readonly debugBoxTemplate: BasePart;

  readonly getWorldUtils: () => [
    any,
    Components,
    { [key: string]: any },
    CachedQueries,
  ];

  readonly addSource: (...args: any[]) => void;
  readonly removeSource: (source: BasePart) => void;
  readonly addReflector: (part: Instance) => void;
  readonly removeReflector: (part: BasePart) => void;
  readonly addSign: (part: Instance, rangeType?: RangeType) => void;
  readonly removeSign: (part: Instance) => void;

  readonly clearConnections: () => void;
  readonly reset: () => void;
};

// Equations Types
export type Equations = {
  readonly name: string;

  readonly computeReflectorIntensity: (
    part: BasePart,
    state: ReflectorState,
    lightSource: LightSource,
    MPH: number,
    config: BASE_CONFIG,
  ) => [number, number];

  readonly computeSignIntensity: (
    part: BasePart,
    state: SignEntity,
    lightSource: LightSource,
    decal: Decal,
    rangeType: RangeType,
    config: BASE_CONFIG,
  ) => {
    transparency: number;
    brightness: number;
    lightInfluence: number;
    hasActiveLight: boolean;
  };

  readonly buildSamplePoints: (quality: number) => void;
};

// Detector Types
export type Detect = {
  readonly name: string;
  readonly currentDetectedEntities: { [key: string]: boolean };
  readonly activeReflectorEntities: { [key: string]: boolean };
  readonly init: () => void;
  readonly start: () => void;
  readonly reset: () => void;
  readonly safeCancelThread: () => [boolean, string?];
  readonly getDetectedEntities: () => { [key: string]: boolean };
};

// Renderer Types
export type Render = {
  readonly name: string;
  readonly init: () => void;
  readonly start: () => void;
  readonly reset: () => void;
  readonly safeCancelThread: () => [boolean, string?];
};

// Misc Types
export type Dict = { [key: string]: any };
export type RangeType = "near" | "far";

// Dark Types
export type DarkClockConfig = {
  DarkClockTimeStart: number;
  DarkClockTimeEnd: number;
};

export type DarkWeathers = { [key: string]: boolean };

export type IsDarkEnvironmentFn = () => boolean;

export type Vehicle = {
  DriveSeat: VehicleSeat;
  Body: Model;
};

// States
export type SurfaceGuiState = {
  _inPool: boolean;
  gui?: SurfaceGuiTemplate;
  currentTransparency: number;
  currentBrightness: number;
  currentLightInfluence: number;
  targetTransparency: number;
  targetBrightness: number;
  targetLightInfluence: number;
  isPendingRemoval: boolean;
  isActive: boolean;
  lastTransparency: number;
  lastBrightness: number;
  lastLightInfluence: number;
  lastColor: vector;
};

export type DecalState = {
  _inPool: boolean;
  baseColor: vector;
  currentBrightness: number;
  targetBrightness: number;
  lastColor: vector;
};

export type SurfaceGuiTemplate = SurfaceGui & {
  ImageLabel: ImageLabel;
};

export type SurfaceGuiStates = { [key: string]: SurfaceGuiState };

export type DecalStates = { [key: string]: DecalState };

export type ReflectorState = any;
export type SignEntity = any;

// Init module
export type LightReflector = {
  readonly init: () => void;
  readonly start: () => void;
  readonly reset: () => void;
  readonly config: Configuration;
  readonly register: Register;
};

// States module types
export type StatesModule = {
  readonly name: string;

  readonly acquireDecalState: () => DecalState;
  readonly acquireSignState: (
    part: BasePart,
    baseConfig: BASE_CONFIG,
    signGrid: any,
  ) => SignEntity;
  readonly acquireReflectorState: (
    part: BasePart,
    baseConfig: BASE_CONFIG,
    reflectorGrid: Grid,
  ) => ReflectorState;
  readonly acquireSurfaceGuiState: () => SurfaceGuiState;

  readonly returnSignState: (
    state: SignEntity,
    pool: Pool<SurfaceGuiTemplate>,
  ) => void;
  readonly returnReflectorState: (state: ReflectorState) => void;
};

export type StatePools = {
  SignState: SignEntity[];
  DecalState: DecalState[];
  SurfaceGuiState: SurfaceGuiState[];
  ReflectorState: ReflectorState[];
};
