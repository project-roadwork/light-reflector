-- USAGE: lightreflector/shared/config.luau
-- Configuration file for Light Reflector

--[[

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at https://mozilla.org/MPL/2.0/.

]]

return {

	--[[

		SYSTEMS:
			I. Sign / Gantry System (Input: Decal & BasePart adornee)

				-> Manipulates real life light reflection on highway/road signs
				  DESPITE native light rendering limitations by utilizting a SurfaceGui to imitate brightness

				-> Provides SurfaceGui pooling to reduce lag and improve performance

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
		-- [GENERAL]
		IS_STREAMING_ENABLED = true,
		-- ^ Set this to true if you have a custom streaming system or have instance streaming enabled.

		MPH_SCALE = 2.23694 * 0.28, -- (recommended -> 2.23694 * 0.28 -> 0.28 meters = 1 stud)
		-- ^ (stud/sec) → mph (CHANGE THIS IF YOU HAVE A DIFFERENT SCALE)

		KEYS = { __mode = "k" }, -- (recommended -> { __mode = "k" } )
		-- ^ Keys to use on weak tables

		MAX_PCALL_RETRIES = 5,  -- (recommended -> 5)
		-- ^ Amount of times to retry a pcall

		SPAWN = task.defer, -- (recommended -> a defer function) - THIS MUST NOT YIELD
		-- ^ Function to spawn or resume threads/coroutines.
		--   this is provided in case you would want to switch to a custom function or task.spawn/coroutine.wrap

		-- [PERFORMANCE]
		BOUNDARY_MIN_FPS = 1, -- (recommended -> 1)
		BOUNDARY_MAX_FPS = 3, -- (recommended -> 3)
		-- ^ FPS of the Boundary function

		RENDER_MIN_FPS = 45, -- (recommended -> 45)
		RENDER_MAX_FPS = 55, -- (recommended -> 55)
		-- ^ FPS of the Render function

		-- [POOLING]
		SURFACE_GUI_MIN_POOL_SIZE = 20, -- (recommended -> 20)
		SURFACE_GUI_MAX_POOL_SIZE = math.huge, -- (recommended -> math.huge)
		-- ^ Pool size of SurfaceGuis

		-- [ATTRIBUTES]
		BASE_INTENSITY_ATTRIBUTE = "LRBaseIntensity",
		-- ^ Base reflective intensity attribute name for both signs and reflectors

		-- [DEBUG]
		IS_RAYCAST_ENABLED = false, -- (recommended -> false)
		-- ^ Only set this to true if you actually need raycasting which is unneccesary (lots of lag).
		-- 	 Otherwise, leaving this as false processes all of the signs
	},

	General = {

		showWarnings = true, -- (recommended -> true)
		-- ^ Show debug warnings in the output

		showPrints = true, -- (recommended -> false)
		-- ^ Show debug prints in the output

		-- [TIME]
		darkClockTimeStart =  17.2, -- (recommended -> 17.2)
		-- ^ ClockTime start of night

		darkClockTimeEnd =  6.3, -- (recommended -> 6.3)
		-- ^ ClockTime end of night

		-- [ANGLE]
		lightHalfAngle = math.rad(10), -- (recommended -> 10)
		-- ^ Half of the angle of the light cone in radians

		-- [OFFSETS]
		vehicleSeatOffset = Vector3.new(0,2,0), -- (recommended -> Vector3.new(0,2,0))
		-- ^ Offset of the vehicle seat

		GetPartsInBox = workspace.GetPartBoundsInBox

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

		maxFadeDistance = 2500, -- (recommended -> 2500)
		-- ^  Max fade distane of signs in studs

		minFadeDistance = 60, -- (recommended -> 60)
		-- ^ Minimum fade distance in studs

		signsFolders = { workspace.Signs },
		-- ^ Set this to your own signs folders separated by a comma

		isDebugBoxEnabled = false, -- Shows the debug box
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
		lerpSpeed = 5, -- (recommended -> 5)
		-- ^ Fade out and lerp speed of signage

		decalFacingDotThreshold = 0,

		mainDecalName = "ACTUALMainDecal123",
		-- ^ Set this to something unique that no other decal has since that identifies the main decal

		isMainDecal = function(decal)
			local name = decal.Name
			local isExcludedBottom = (name == "Decal" and decal.Face == Enum.NormalId.Bottom)

			return name == "F" or (name ~= "Back" and name ~= "B" and name ~= "Images/Metal Lined" and not isExcludedBottom)
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

		tagName = "Reflector",
		-- ^ Reflector tag name should you use tags

		defaultCanKeepTextures = true,
		-- ^ default value whether to keep textures on the MAIN reflector or not

		canKeepTexturesAttribute = "LRCanKeepTextures",
		-- ^ attribute name to override whether to keep textures or not on the MAIN reflector

		reflectorsFolder = { workspace.Roads },
		-- ^ Folders where your reflectors are, seperated by a comma. This will not be used if you have tags enabled.

		isReflector = function(p)
			return p:IsA("BasePart") and p.Parent and p.Parent.Name == "P" and not p:IsA("MeshPart")
		end,
		-- ^ Condition of what makes a BasePart a "reflector"

		minDistance = 50, -- (recommended -> 50)  -- studs
		maxDistance = 1900, -- (recommended -> 1900)  -- studs
		-- ^ Reflector Distances
		-- enabling `useWedgeFacingDetection` may override maxDistance

		useWedgeFacingDetection = true, -- (recommended -> true)
		-- ^ may have its own "maxDistance" based on wedge slope
		wedgeFacingDotThreshold = 0,  -- (recommended -> 0)
		-- ^ (BASED ON POINT OF SOURCE) higher number = stricter; lower number = less stricter
		--   (if the wedge should be active or not based on where the light source is pointing)

		activateIntensityThreshold = 0.06, -- (recommended -> 0.06)
		inactivateIntensityThreshold = 0.02, -- (recommended -> 0.02)
		neonActivationIntensity = 0.12, -- (recommended -> 0.12)
		-- ^ Reflector light logic

		lerpSpeed = 10, -- (recommended -> 10)
		-- ^ Lerp speed of reflectors

		activeMaterial = Enum.Material.Neon, -- (recommended -> Enum.Material.Neon)
		inactiveMaterial = Enum.Material.Plastic, -- (recommended -> Enum.Material.Plastic)
		-- ^ Material of reflectors

		partialDimmingBaseColor = Color3.fromRGB(120, 120, 120), -- (recommended -> Color3.fromRGB(120, 120, 120))
		minBrightness = 0, -- (recommended -> 0)
		maxBrightness = 400, -- (recommended -> 400)
		-- ^ Brightness of reflectors

		--[HYBRID SUBSYSTEM]
		isHybridEnabled = true,
		-- ^ Enables or disables hybrid functionality (SurfaceGui transparency logic PLUS BasePart logic)
		--   really you have to add a hybrid attribute anyway, but this is mainly for testing

		isHybridFaceOffsetEnabled = true, -- (recommended -> true)
		-- ^ enabling this offsets the hybrid reflector clone away from the selected face attribute if there is one

		hybridFaceAttributeName = "LRFace",
		-- ^ attribute to identify the selected face of the hybrid reflectors (Top, Bottom, Right, etc.)

		hybridOffset = 0.003, -- (recommended -> 0.003)
		-- ^ CFrame offset increment should `isHybridFaceOffsetEnabled` be set to true

		hybridCloneName = "LRHybridClone",
		-- ^ name that would be given to hybrid clone parts

		hybridCloneAttributeName = "LR_IsHybridClone",
		-- ^ set this to something unique that no other part will have. This identifies hybrid clones to prevent maximum event re-entrancy depth

		hybridAttributeName = "LRHybrid",
		-- ^ attribute to identify hybrid reflectors (you must add the Reflector tag too as the hybrid system is UNDER the reflector system)

		defaultHybridMaxDistance = 1600, -- (recommended -> 1600)
		-- ^ default hybrid max fade distance should the respective hybrid reflector does NOT have its own max distance attribute

		defaultHybridMinDistance = 50, -- (recommended -> 50)
		-- ^ default hybrid min fade distance should the respective hybrid reflector does NOT have its own min distance attribute

		hybridMinDistanceAttribute = "HybridMinDistance",
		-- ^ attribute to identify the hybrid min distance of the hybrid reflector

		hybridMaxDistanceAttribute = "HybridMaxDistance",
		-- ^ attribute to identify the hybrid max distance of the hybrid reflector

		hybridFacingDotThreshold = 0, -- (recommended -> 0)
		-- ^ (BASED ON POINT OF SOURCE) higher number = stricter; lower number = less stricter
		--   (if the reflectpr be active or not based on where the light source is pointing)

		defaultCanHybridKeepColors = false,
		-- ^ enabling this prevents the hybrid system from tampering with the base colors by default
		--   if you have more parts that you wish to "keep colors" on (like unions that you cannot set `SetPartColor` to true),
		--    then set this to true, then create an attribute on the part you wish to NOT keep colors
		--     on and set it to false (attribute defined in `hybridKeepColorsAttribute`)

		hybridKeepColorsAttribute = "CanHybridKeepColors",
		-- ^ attribute name to override the default CanHybridKeepColors per part

		defaultHybridTransparencyMultiplier = 2, -- (recommended -> more than 1 such as 2)
		-- ^ default hybrid transparency multiplier

		hybridTransparencyAttribute = "HybridTransparencyMultiplier",
		-- ^ attribute name to override the default hybrid transparency multiplier per part

		defaultHybridCanKeepTextures = false,
		-- ^ default value whether to keep textures or not on the HYBRID clone, not the main reflector

		canHybridKeepTexturesAttribute = "HybridCanKeepTexturs",
		-- ^ attrubute name to override whether to keep textures or not on the HYBRID clone, not the main reflector

	}
}
