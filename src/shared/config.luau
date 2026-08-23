--!native
--!strict
-- USAGE: lightreflector/shared/config.luau
-- Configuration file for Light Reflector

--[[
    SPDX-FileCopyrightText: 2025-2026 Illinois_Roadbuff (Rogue Jr) <illinois_roadbuff@proton.me>
    SPDX-FileCopyrightText: 2025-2026 Project Roadwork and Contributors

    SPDX-License-Identifier: MPL-2.0 AND MIT

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at https://mozilla.org/MPL/2.0/.

   Includes some config components from Chrono 2.0.x (https://github.com/Parihsz/Chrono)

    SPDX-FileCopyrightText: 2025 Parihsz

]]

-- Variables
const WAITING_ON_CHANGE: {[number]: (any)} = {}
const WAITING_ON_LOCK: {[number]: (any)} = {}
const placeholderPart: BasePart = Instance.new("Part")
local LOCKED: boolean = false

-- Flags
const FLAGS = {
	["PCALL"] = false, -- Enable protected calls or not. Useful for debugging.
	["TRACK_ANCESTRY_CONNECTIONS"] = false, -- Enable to track ancestry connections
	["NO_STATE_POOLING"] = false, -- Disables pooling/recycling of states (tables)
}

-- Base Config
const BASE_CONFIG = {

	--[[

		SYSTEMS:
			I. Sign / Gantry System (Input: Decal & BasePart adornee)

				-> Manipulates real life light reflection on highway/road signs
				  DESPITE native light rendering limitations by utilizting a SurfaceGui or a decal by itself to imitate brightness

				RENDER MODES:
				  1. SurfaceGui - Utilizes a SurfaceGui with an image label to reflect by using `.Brightness`, `.LightInfluence`, and `.ImageTransparency` properties
				  	Benefits:
				  		1.  Prevents the sign from appearing extremely bright
				  		2.  Can be applied to every material
				  	Cons:
				  		1.  Appears slightly unrealistic when viewed at an angle
				  		2.  Orientation may be distorted or incorrect on meshes or unions

				  2. Decal - Utilizes a decal by itself to reflect by increasing the decal's base Color3 above (255, 255, 255)
				  	Benefits:
				  		1.  Appears more realistic when viewed at an angle
				  		2.  Orientation is preserved on meshes or unions
				  		3.  Probably more light-weight as no SurfaceGuis need to be created
				  	Cons:
				  		1.  Sign may appear overwhelmingly bright when faced uprfront
				  		2.  Materials such as `Metal` will make the decal appear distorted

			II. Reflector System (Input: BasePart)

				-> Manipulates real life light reflection on road reflectors such as pavement reflectors WITHOUT
				  having to use unreliable tricks such as the `ForceField` by utilizing the `Neon` material

				A. Hybrid Subsystem (Input: BasePart)

				   -> Hybrid subsystem that works alongside the Reflector System by utilizing the
				     Sign/Gantry System's transparency logic to provide a BasePart layer with the
				     `Neon` material method and dynamic fading WITHOUT impacting visuals of the main part

				      1. Can be useful for non-decal sign parts and reflective traffic light shields

		CONFIGURATION INSTRUCTIONS:
			- To change a value, simply change the value of the property.
			- Values not marked by *(recommended)* can be easily changed uner your discretion or choice.

		Learn more:
			https://codeberg.org/project-roadwork/light-reflector.git

		It is recommended that one does NOT change any UPPER_SNAKE_CASE (or all capital) constraints during runtime.
			-> one cannot change values in frozen tables anyway ;)

	]]

	Constraints = { -- This table will be frozen once the module starts
		LOCKED = false, -- (recommended -> false) DO NOT CHANGE

		-- [PROFILING]
		PROFILING = true, -- Whether you want to profile this library via the Microprofiler

		-- [VERSION]
		VERSION = require("./version")._VERSION,

		-- [REPOSITORIES]
		CODEBERG = "https://codeberg.org/project-roadwork/light-reflector.git",
		GITHUB = "https://github.com/project-roadwork/light-reflector.git",
		-- ^ Codeberg and GitHub repositories for Light Reflector

		-- [GENERAL]
		IS_STREAMING_ENABLED = true,
		-- ^ Set this to true if you have a custom streaming system or have instance streaming enabled.

		MPH_SCALE = 2.23694 * 0.28, -- (recommended -> 2.23694 * 0.28 -> 0.28 meters = 1 stud)
		-- ^ (stud/sec) → mph (CHANGE THIS IF YOU HAVE A DIFFERENT SCALE)

		KEYS = { __mode = "k" }, -- (recommended -> { __mode = "k" } )
		-- ^ Keys to use on weak tables. (This may no longer be used in 2.1.0)

		MAX_PCALL_RETRIES = 5,  -- (recommended -> 5)
		-- ^ Amount of times to retry a pcall

		SPAWN = task.defer, -- (recommended -> a defer function) - THIS MUST NOT YIELD
		-- ^ Function to spawn or resume threads/coroutines.
		--   this is provided in case you would want to switch to a custom function or task.spawn/coroutine.wrap

		SIGNS_PRIMARY_RENDER_MODE = "SurfaceGui",
		-- ^ Rendering method for signs. Can either be "SurfaceGui" or "Decal"; these render modes are described in the large comment block above

		-- [PERFORMANCE]
		BOUNDARY_MIN_FPS = 1, -- (recommended -> 1)
		BOUNDARY_MAX_FPS = 4, -- (recommended -> 3)
		-- ^ FPS of the Boundary function

		RENDER_MIN_FPS = 45, -- (recommended -> 45)
		RENDER_MAX_FPS = 59, -- (recommended -> 55)
		-- ^ FPS of the Render function
		--
		-- NOTE: If render FPS is low, it may go below `RENDER_MIN_FPS`.

		MAX_MPH = 12, -- (recommended -> 10)
		-- ^ Maximum speed in which the Boundary/Detect and Render system would run its fastest

		-- [POOLING]
		SURFACE_GUI_MIN_POOL_SIZE = 20, -- (recommended -> 20)
		SURFACE_GUI_MAX_POOL_SIZE = math.huge, -- (recommended -> math.huge)
		-- ^ Pool size of SurfaceGuis

		-- [ATTRIBUTES]
		BASE_INTENSITY_ATTRIBUTE = "LRBaseIntensity",
		-- ^ Base reflective intensity attribute name for both signs and reflectors

		-- [DEBUG]
		IS_RAYCAST_INDEXING_ENABLED = false, -- (recommended -> false)
		-- ^ Only set this to true if you actually need raycasting which is unneccesary (lots of lag).
		-- 	 Otherwise, leaving this as false processes all of the signs

		OCCLUSION_RAYCAST_QUALITY = 2.5, -- (recommended -> 2-5)
		-- ^ Controls occlusion sampling resolution (N x N rays across the surface).
		--   Higher valies reduce artifacts from small obstacles (e.g. poles); however, they increase
		--   raycast cost.

		BOUNDS = game, -- (No recommendation; default -> game)
		-- ^ If a part is not a descendant of the BOUNDS variable, it means that it should be removed
		-- Use `workspace` if your sources, reflectors, or signs are under `workspace`
		-- Use `game` if any of your sources, reflectors, or signs are not under `workspace`, but may be in a different service
		--
		LOOK_VECTOR_VISUALS = false -- (No recommendation; default -> false)
		-- DEBUG: Use this to show whether your source is orientated correctly or not

	},

	General = {

		showWarnings = true, -- (recommended -> true)
		-- ^ Show debug warnings in the output

		showPrints = true, -- (recommended -> false)
		-- ^ Show debug prints in the output

		showRegisteredPrints = true, -- (no recommendation)
		-- ^ Whether the register prints newly registered or unregistered entities

		-- [TIME]
		darkClockTimeStart =  17.2, -- (recommended -> 17.2)
		-- ^ ClockTime start of night

		darkClockTimeEnd =  6.3, -- (recommended -> 6.3)
		-- ^ ClockTime end of night

		-- [ANGLE]
		lightHalfAngle = math.rad(25), -- (recommended -> 10)
		-- ^ Half of the angle of the light cone in radians

		-- [OFFSETS]
		vehicleSeatOffset = Vector3.new(0, 2, 0), -- (recommended -> Vector3.new(0,2,0))
		-- ^ Offset of the vehicle seat

		GetPartsInBox = workspace.GetPartBoundsInBox,
		-- ^ Raycast function for getting parts in a box

		movingPartAttribute = "LRMoving",
		-- ^ Attribute name to identify moving reflectors or signs

		occlusionRaycastExclude = {placeholderPart,

		} :: {Instance},
		-- ^ Any additional instances you want to include in raycast exclusion.
		-- Do not remove `placeholderPart`

		occlusionRaycastExcludeTransparent = true
		-- ^ Automatically excludes transparent parts, BUT semi-transparent parts will not be excluded
		--   and would affect the intensity of the signs and/or reflectors.
		--
		--   More transparent = less intensity
		--   Less transparent = more intensity

	},

	-- [SIGN CONFIG]
	SignConfig = {

		isEnabled = true,
		-- ^ Enables or disables reflector functionality

		isTagsEnabled = true ,-- (recommended -> true)
		-- ^ It is recommended that you set this to true if your signs are parented under folders with many instances.
		--   Additionally, this uses CollectionService.

		tagName = "ReflectiveSign",
		-- ^ Sign tag name should you use tags.

		useRaycastForObstacles = false, -- (No recommendation; default -> false)
		-- Uses Raycasts to determine if a sign is obstructed from its light source(s)
		--
		-- Since there is usually less signs than reflectors in a map, lag would not be as heavy as pavement reflectors.
		--
		-- HOWEVER, it depends on whether you have "too many" signs when viewed in the client or not.
		--   so setting this to true or false is at your discretion.

		partRenderModeAttributeName = "LRRenderMode",
		-- ^ Part attribute name for render mode

		allowMultipleRenderModes = true,
		-- ^ If set to true, it will allow multiple render modes in the Sign System. Otherwise, it will use the primary render mode.

		decalIntensityMultiplier = 1.4, -- (recommended -> 1.4)
		-- ^ Decal intensity multiplier to match up with the appearance of the SurfaceGui
		--
		--   Decals relying on the base brightness itself appears darker than SurfaceGuis,
		--   so it would be best to add a multiplier.

		signIntensityMultiplier = .8,
		-- ^ Intensity multiplier that affects both SurfaceGuis and Decals

		maxFadeDistance = 2500, -- (recommended -> 2500)
		-- ^  Max fade distane of signs in studs

		minFadeDistance = 60, -- (recommended -> 60)
		-- ^ Minimum fade distance in studs

		signsFolders = {
		    workspace
		   -- workspace.Signs
		} :: {Instance},
		-- ^ Set this to your own signs folders separated by a comma

		isSign = function(part: BasePart): boolean
			if part.Name == "Sign" then
			    return true
			else
				return false
			end
		end,
		-- ^ Conditions that make an instance a sign
		--
		--   NOTE: If you have tags enabled, this function WILL be overriden should the part have the respective
		--   reflective tag.

		isDebugConeAngleEnabled = false,
		-- ^ Enabling this would show the cone of the light source for debug purposes
		--
		--   WARNING: This drastically affects performance as it spawns thousands of parts.

		isDebugBoxEnabled = false, -- Shows the debug box. THIS ONLY WORKS FOR RAYCASTING.
		debugBoxColor = Color3.fromRGB(0,255,0),
		debugBoxTransparency = 0.8,
		debugBoxName = "RaycastDebugBox",
		debugBoxMaterial = Enum.Material.Plastic,
		-- ^ DebugBox properties

		debugBoxFolder = nil, -- Setting to nil will automatically create a custom debug folder
		raycastBoxOffset = CFrame.new(0, 3, -625), -- offset to car
		raycastBoxSizeNear = Vector3.new(250, 150, 1250), -- smaller box close to headlights
		raycastBoxSizeFar = Vector3.new(500, 150, 1250), -- larger box far from headlights, unused at the moment
		raycastBoxOffsetNear = CFrame.new(0, 3, -625),
		raycastBoxOffsetFar = CFrame.new(0, 3, -625) * CFrame.new(0, 0, -CFrame.new(0, 3, -625).Z / 2),
		-- ^ DebugBox positioning

		noFadeOutFactor = 3, -- (recommended -> 3)
		lerpSpeed = 12, -- (recommended -> 9)
		-- ^ Fade out and lerp speed of signage

		decalFacingDotThreshold = 0, -- (recommended -> 0)
		-- ^ Threshold for whether a sign is faced away from a source or facing towards it.

		mainDecalName = "ACTUALMainDecal123",
		-- ^ Set this to something unique that no other decal has since that identifies the main decal

		isMainDecal = function(decal: Decal): boolean
			local name: string = decal.Name
			local isExcludedBottom: boolean = (name == "Decal" and decal.Face == Enum.NormalId.Bottom)

			return (name == "Front" or name == "F") or (name ~= "Back" and name ~= "B" and name ~= "Images/Metal Lined" and not isExcludedBottom)
		end,
		-- ^ Conditions that make an instance a main front decal or sign, and not the back of it

		inactiveTransparencyThreshold = 0.98, -- (recommended -> 0.98)
		-- ^ Number of what makes a sign nearly invisible

	},

	-- [REFLECTOR CONFIG + HYBRID SUBSYSTEM CONFIG]
	ReflectorConfig =  {

		isEnabled = true,
		-- ^ Enables or disables reflector functionality

		isTagsEnabled = true, -- (recommended -> true)
		-- ^ It is recommended that you set this to true if your reflectors are parented under folders with many instances.
		--   Additionally, this uses CollectionService.

		useRaycastForObstacles = false, -- (recommended -> false)
		-- Uses Raycasts to determine if a reflector is obstructed from its light source(s)
		-- Setting this to false is strongly recommended since it causes tremendous lag with the number of light
		--   reflectors for little visual benefit. This option is only provided should it be needed.

		tagName = "Reflector",
		-- ^ Reflector tag name should you use tags

		defaultCanKeepTextures = true,
		-- ^ Default value whether to keep textures on the MAIN reflector or not
		--
		--   Primarily affects BaseParts such as meshes.

		reflectorIntensityMultiplier = 1,
		-- ^ Intensity multiplier that affects all reflectors

		canKeepTexturesAttribute = "LRCanKeepTextures",
		-- ^ Attribute name to override whether to keep textures or not on the MAIN reflector.
		--
		--   If a part has this attribute, it WILL override the configuration default values.

		reflectorsFolders = {
		    workspace
	--	    workspace.Roads
		} :: {Instance},
		-- ^ Folders where your reflectors are, seperated by a comma. This will not be used if you have tags enabled.

		isReflector = function(p: BasePart): boolean
		    if p.Name == "Reflector" then
				return true
			else
			    return (p.Parent and typeof(p.Parent) == "Instance" and p.Parent.Name == "P" and not p:IsA("MeshPart")) == true
			end
		end,
		-- ^ Condition of what makes a BasePart a "reflector"
		--   NOTE: If you have tags enabled, this function WILL be overriden should the part have the respective
		--   reflective tag.

		minDistance = 50, -- (recommended -> 50)  -- studs
		maxDistance = 1900, -- (recommended -> 1900)  -- studs
		-- ^ Reflector Distances
		--
		--   NOTE: Enabling `useWedgeFacingDetection` may override maxDistance due to `:Dot()`

		useWedgeFacingDetection = true, -- (recommended -> true)
		-- ^ May have its own "maxDistance" based on wedge slope

		wedgeFacingDotThreshold = 0,  -- (recommended -> 0)
		-- ^ (BASED ON POINT OF SOURCE) higher number = stricter; lower number = less stricter
		--   (if the wedge should be active or not based on where the light source is pointing)

		activateIntensityThreshold = 0.06, -- (recommended -> 0.06)
		inactivateIntensityThreshold = 0.02, -- (recommended -> 0.02)
		neonActivationIntensity = 0.12, -- (recommended -> 0.12)
		neonWidth = 0.55, -- (recommended -> 0.55)
		-- ^ Reflector light logic

		lerpSpeed = 12, -- (recommended -> 10)
		-- ^ Lerp speed of reflectors

		activeMaterial = Enum.Material.Neon, -- (recommended -> Enum.Material.Neon)
		inactiveMaterial = Enum.Material.Plastic, -- (recommended -> Enum.Material.Plastic)
		-- ^ Material of reflectors

		partialDimmingBaseColor = Color3.fromRGB(120, 120, 120), -- (recommended -> Color3.fromRGB(120, 120, 120))
		minBrightness = 0, -- (recommended -> 0)
		maxBrightness = 400, -- (recommended -> 400)
		-- ^ Brightness of reflectors

		useMaxDOT = true,  -- (recommended -> true)
		-- ^ Uses `:Dot()` WITH the light half angle to determine part of the intensity, albeit not too strict.
		--
		--   NOTE: This may drastically affect how the reflectors light up based on the source's angle.

		--[HYBRID SUBSYSTEM]
		isHybridEnabled = true,
		-- ^ Enables or disables hybrid functionality (SurfaceGui transparency logic PLUS BasePart logic).
		--   Really you have to add a hybrid attribute anyway, but this is mainly for testing.

		isHybridFaceOffsetEnabled = true, -- (recommended -> true)
		-- ^ Enabling this offsets the hybrid reflector clone away from the selected face attribute if there is one

		faceAttributeName = "LRFace",
		-- ^ Attribute to identify the selected face of reflectors (Top, Bottom, Right, etc.)

		hybridOffset = 0.003, -- (recommended -> 0.003)
		-- ^ CFrame offset increment should `isHybridFaceOffsetEnabled` be set to true

		hybridCloneName = "LRHybridClone",
		-- ^ Name that would be given to hybrid clone parts.
		--   Make sure that no other part in the workspace is named as such.

		hybridCloneAttributeName = "LR_IsHybridClone",
		-- ^ Set this to something unique that no other part will have.
		--   This identifies hybrid clones to prevent maximum event re-entrancy depth

		hybridAttributeName = "LRHybrid",
		-- ^ Attribute to identify hybrid reflectors (you must add the Reflector tag too as the hybrid system is UNDER the reflector system)

		defaultHybridMaxDistance = 1600, -- (recommended -> 1600)
		-- ^ Default hybrid max fade distance should the respective hybrid reflector does NOT have its own max distance attribute

		defaultHybridMinDistance = 50, -- (recommended -> 50)
		-- ^ Default hybrid min fade distance should the respective hybrid reflector does NOT have its own min distance attribute

		hybridMinDistanceAttribute = "HybridMinDistance",
		-- ^ Attribute to identify the hybrid min distance of the hybrid reflector

		hybridMaxDistanceAttribute = "HybridMaxDistance",
		-- ^ Attribute to identify the hybrid max distance of the hybrid reflector

		hybridFacingDotThreshold = 0, -- (recommended -> 0)
		-- ^ (BASED ON POINT OF SOURCE) higher number = stricter; lower number = less stricter
		--   (if the reflectpr be active or not based on where the light source is pointing)

		defaultCanHybridKeepColors = false,
		-- ^ Enabling this prevents the hybrid system from tampering with the base colors by default
		--
		--   NOTE: If you have more parts that you wish to "keep colors" on (like unions that you cannot set `SetPartColor` to true),
		--   then set this to true, then create an attribute on the part you wish to NOT keep colors
		--   on and set it to false (attribute defined in `hybridKeepColorsAttribute`)

		hybridKeepColorsAttribute = "CanHybridKeepColors",
		-- ^ Attribute name to override the default CanHybridKeepColors per part

		defaultHybridTransparencyMultiplier = 2, -- (recommended -> more than 1 such as 2)
		-- ^ Default hybrid transparency multiplier

		hybridTransparencyAttribute = "HybridTransparencyMultiplier",
		-- ^ Attribute name to override the default hybrid transparency multiplier per part

		defaultHybridCanKeepTextures = false,
		-- ^ Default value whether to keep textures or not on the HYBRID clone, not the main reflector

		canHybridKeepTexturesAttribute = "HybridCanKeepTexturs",
		-- ^ Attrubute name to override whether to keep textures or not on the HYBRID clone, not the main reflector

		isMarkingEnabled = true,
		-- ^ Enable hybrid marking parts

		markingAttributeName = "LRMarking",
		-- ^ Attribute to identify hybrid marking parts

		splitMarkings = true,
		-- ^ Split markings based on maximum part size or not

		maxMarkingPartSize = 4,
		-- ^ Maximum part size. Anything that goes beyond will be split

		markingNoSplitAttribute = "LRNoSplit",
		-- ^ Attribute to determine if the marking gets split or not

		markingTransparencyMultiplier = 1.9, -- (recommended -> 1.9)
		-- ^ Transparency multiplier for markings. Higher = darker, lower = brighter

		defaultMarkingMaxDistance = 3600, -- (recommended -> 3600)
		-- ^ Default marking max fade distance

	}
}

--[=[
	Private: Custom warnings

	@private
	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function _warn(message: string): ()
	if BASE_CONFIG.General.showWarnings then
		warn(`[Light Reflector {BASE_CONFIG.Constraints.VERSION} -> Config] Warning: {message}`)
	end
end

--[=[
	Private: Invokes callbacks waiting on configuration change
	@private

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function _invoke_change_signal(): ()
	for _: number, callback: (BASE_CONFIG) -> () in WAITING_ON_CHANGE do
		callback(BASE_CONFIG)
	end
end

--[=[
	Public: Deep merges two dictionaries

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function _deepMerge(defaults: Dict, overrides: Dict, path: string?): ()
	path = path or ""

	for key, value in next, overrides do
		if typeof(key) ~= "string" then
			continue
		end

		const fullPath: string = if path ~= "" then `{path}.{key}` else tostring(key)

		if defaults[key] == nil then
			_warn(`Unknown configuration key: -> {fullPath} <-; are you sure it is spelled or capitalized correctly?`)
			continue
		end

		if typeof(value) == "table" and typeof(defaults[key]) == "table" then
			_deepMerge(defaults[key] :: Dict, value :: Dict, fullPath)
		else
			defaults[key] = value
		end
	end
end

--[=[
	Public: Assigns config via deep merge

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function applyOverrides(userConfig: any): BASE_CONFIG
	if typeof(userConfig) ~= "table" then
		return BASE_CONFIG
	end

	if userConfig["Constraints"] and LOCKED then
		_warn( "CONSTRAINTS is locked; cannot update configuration. Please remove CONSTRAINTS and try again.")

		return BASE_CONFIG
	end

	_deepMerge(BASE_CONFIG :: Dict, userConfig :: Dict)

	_invoke_change_signal()

	return BASE_CONFIG
end

--[=[
	Public: Locks the config and calls any calbacks

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function lock(): ()
	LOCKED = true
	BASE_CONFIG.Constraints.LOCKED = true

	table.freeze(BASE_CONFIG.Constraints)

	for _: number, callback: () -> () in WAITING_ON_LOCK do
		callback()
	end
end

--[=[
	Public: Unlocks the config

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function unlock(): ()
	const clone = table.clone(BASE_CONFIG.Constraints)
	BASE_CONFIG.Constraints = clone

	LOCKED = false
	BASE_CONFIG.Constraints.LOCKED = false
end

--[=[
	Public: Waits for the config to be locked with a callback

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function waitForLock(callback: () -> ()): ()
	if LOCKED then
		callback()
	else
		table.insert(WAITING_ON_LOCK, callback)
	end
end

--[=[
	Public: Waits for the config to be changed

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function onChange(callback: (BASE_CONFIG) -> ()): ()
	table.insert(WAITING_ON_CHANGE, callback)
end

--[=[
	Public: Returns a section of the config

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function getSection(section: string): Dict
	return (BASE_CONFIG :: BASE_CONFIG)[section]
end

--[=[
	Public: Returns a key from the config

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function getKey(section: string, key: string): any
	return (BASE_CONFIG :: BASE_CONFIG)[section][key]
end

--[=[
	Public: Overrides a key in the config

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function overrideKey(section: string, key: string, value: any): ()
	if section == "Constraints" and LOCKED then
		_warn( "CONSTRAINTS is locked; cannot update configuration.")
		return
	end

	_invoke_change_signal()

	BASE_CONFIG[section][key] = value
end

--[=[
	Public: Returns the entire config with typing

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function getConfig(): BASE_CONFIG
	return BASE_CONFIG
end

-- Types
export type BASE_CONFIG = typeof(BASE_CONFIG)
export type Dict = { [string | number]: any }

-- Return public variables and API
return table.freeze({
	name = "config",
	FLAGS = FLAGS,
	applyOverrides = applyOverrides,
	lock = lock,
	unlock = unlock,
	waitForLock = waitForLock,
	onChange = onChange,
	getKey = getKey,
	getSection = getSection,
	overrideKey = overrideKey,
	getConfig = getConfig,
})
