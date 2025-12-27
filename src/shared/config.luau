-- USAGE: lightreflector/shared/config.luau
-- Configuration file for Light Reflector

return {

	-- Learn more:
	-- 		https://codeberg.org/project-roadwork/light-reflector.git

	-- [GENERAL]
	STREAMING = true,
	-- ^ Set this to true if you have a custom streaming system or have instance streaming enabled.

	MphScale = 2.23694 * 0.28, -- (recommended -> 2.23694 * 0.28 -> 028m = 1 stud)
	-- ^ (stud/sec) → mph

	UseRaycast = false, -- (recommended -> false)
	-- ^ Only set this to true if you actually need raycasting which is unneccesary (lots of lag).
	-- 	 Otherwise, leaving this as false processes all of the signs

	ShowWarnings = true, -- (recommended -> true)
	-- ^ Show debug warnings in the output

	ShowPrints = true, -- (recommended -> false)
	-- ^ Show debug prints in the output

	DarkClockTimeStart =  17.2, -- (recommended -> 17.2)
	-- ^ ClockTime start of night

	DarkClockTimeEnd =  6.3, -- (recommended -> 6.3)
	-- ^ ClockTime end of night

	LightHalfAngle = math.rad(10), -- (recommended -> 10)
	-- ^ Half of the angle of the light cone in radians

	MaxPcallRetries = 5,  -- (recommended -> 5)
	-- ^ Amount of times to retry a pcall

	-- [PERFORMANCE]
	BoundaryMinFPS = 1, -- (recommended -> 1)
	BoundaryMaxFPS = 3, -- (recommended -> 3)
	-- ^ FPS of the Boundary function

	RenderMinFPS = 45, -- (recommended -> 45)
	RenderMaxFPS = 55, -- (recommended -> 55)
	-- ^ FPS of the Render function

	-- [OFFSETS]
	VehicleSeatOffset = Vector3.new(0,2,0), -- (recommended -> Vector3.new(0,2,0))
	-- ^ Offset of the vehicle seat

	-- [POOLING]
	SurfaceGuiMinPoolSize = 20, -- (recommended -> 20)
	SurfaceGuiMaxPoolSize = math.huge, -- (recommended -> math.huge)
	-- ^ Pool size of SurfaceGuis

	-- [SIGN CONFIG]
	SignConfig = {
		FadeDistance = 2500, -- (recommended -> 2500)
		-- ^  Max fade distane of signs in studs

		MinFadeDistance = 60, -- (recommended -> 60)
		-- ^ Minimum fade distance in studs

		SignsFolders = { workspace.Signs },
		-- ^ Set this to your own signs folders separated by a comma

		DebugBoundary = false, -- Shows the debug box
		DebugBoxColor = Color3.fromRGB(0,255,0),
		DebugBoxTransparency = 0.8,
		DebugBoxName = "RaycastDebugBox",
		DebugBoxMaterial = Enum.Material.Plastic,
		-- ^ DebugBox properties

		DebugBoxFolder = nil, -- Setting to nil will automatically create a custom debug folder
		BoxOffset = CFrame.new(0, 3, -625), -- offset to car
		BoxSizeNear = Vector3.new(250, 150, 1250), -- smaller box close to headlights
		BoxSizeFar = Vector3.new(500, 150, 1250), -- larger box far from headlights
		BoxOffsetNear = CFrame.new(0, 3, -625),
		BoxOffsetFar = CFrame.new(0, 3, -625) * CFrame.new(0, 0, -CFrame.new(0, 3, -625).Z / 2),
		-- ^ DebugBox positioning

		FadeOutFactor = 3, -- (recommended -> 3)
		LerpSpeed = 5, -- (recommended -> 5)
		-- ^ Fade out and lerp speed of signage

		MainDecalName = "ACTUALMainDecal123",
		-- ^ Set this to something unique that no other decal has since that identifies the main decal

		MainDecalConditions = function(decal)
			local name = decal.Name
			local isExcludedBottom = (name == "Decal" and decal.Face == Enum.NormalId.Bottom)

			return name == "F" or (name ~= "Back" and name ~= "B" and name ~= "Images/Metal Lined" and not isExcludedBottom)
		end,
		-- ^ Conditions that make an instance a main front decal or sign, and not the back of it

		InactiveTransparency = 0.98, -- (recommended -> 0.98)
		-- ^ Number of what makes a sign nearly invisible

	},

	-- [REFLECTOR CONFIG]
	ReflectorConfig =  {
		Enabled = true,

		UseTags = true, -- (recommended -> true)
		-- ^ It is recommended that you set this to true if your reflectors are parented under folders with many instances.
		--   Additionally, this uses CollectionService.

		TagName = "Reflector",
		-- ^ Tag name should you use tags.

		ReflectorsFolder = { workspace.Roads },
		-- ^ Folders where your reflectors are, seperated by a comma. This will not be used if you have tags enabled.

		Condition = function(p)
			return p:IsA("BasePart") and p.Parent and p.Parent.Name == "P" and not p:IsA("MeshPart")
		end,
		-- ^ Condition of what makes a BasePart a "reflector"

		MinDistance = 40, -- (recommended -> 40)  -- studs
		MaxDistance = 1200, -- (recommended -> 1200)  -- studs
		-- ^ Reflector Distances

		UseWedgeFacingDetection = true, -- (recommended -> true)
		WedgeFacingDotThreshold = 0.35,  -- (recommended -> 0.35)
		-- ^ Reflector wedge logic

		ActivateThreshold = 0.06, -- (recommended -> 0.06)
		DeactivateThreshold = 0.02, -- (recommended -> 0.02)
		NeonMinIntensity = 0.12, -- (recommended -> 0.12)
		-- ^ Reflector light logic

		LerpSpeed = 10, -- (recommended -> 10)
		-- ^ Lerp speed of reflectors

		ActiveMaterial = Enum.Material.Neon, -- (recommended -> Enum.Material.Neon)
		InactiveMaterial = Enum.Material.Plastic, -- (recommended -> Enum.Material.Plastic)
		-- ^ Material of reflectors

		PartialDimmingBaseColor = Color3.fromRGB(120, 120, 120), -- (recommended -> Color3.fromRGB(120, 120, 120))
		DarkBrightness = 0, -- (recommended -> 0)
		LightBrightness = 400, -- (recommended -> 400)
		-- ^ Brightness of reflectors

	}
}
