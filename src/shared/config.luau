-- USAGE: lightreflector/shared/config.luau
-- Intensity equations for Light Reflector

return {

	STREAMING = true, -- Set this to true if you have a custom streaming system or have instance streaming enabled.
	MphScale = 2.23694 * 0.28, -- (stud/sec) → mph
	-- RAYCAST CONFIG --

	UseRaycast = false, -- only set this to true if you actually need raycasting which is unneccesary (lots of lag).
	-- Otherwise, leaving this as false processes all of the signs

	ShowWarnings = true,
	ShowPrints = true,

	DarkClockTimeStart =  17.2,
	DarkClockTimeEnd =  6.3,

	LightHalfAngle = math.rad(10),

	SignConfig = {
		FadeDistance = 2500, -- max fade distane of signs in studs
		MinFadeDistance = 60, -- studs

		SignsFolders = { workspace.Signs }, -- SET THIS TO YOUR OWN SIGNS FOLDERS SEPERATED BY A COMMA


		DebugBoundary = false, -- Shows the debug box
		BoxOffset = CFrame.new(0, 3, -625), -- offset to car
		BoxSizeNear = Vector3.new(250, 150, 1250), -- smaller box close to headlights
		BoxSizeFar = Vector3.new(500, 150, 1250), -- larger box far from headlights
		BoxOffsetNear = CFrame.new(0, 3, -625),
		BoxOffsetFar = CFrame.new(0, 3, -625) * CFrame.new(0, 0, -CFrame.new(0, 3, -625).Z / 2),

		FadeOutFactor = 3,
	},

	ReflectorConfig =  {
		Enabled = true,

		PartName = "W", -- white pavement reflector
		Material = Enum.Material.Neon,

		DarkBrightness = 0,
		LightBrightness = 400,

		MinDistance = 30,   -- studs
		MaxDistance = 1200,  -- studs

		SeparateSensors = true, -- each reflector does its own checks

		UseTags = true,

		ReflectorsFolder = { workspace.Roads },

		Condition = function(p) return p:IsA("BasePart") and p.Parent and p.Parent.Name == "P" and not p:IsA("MeshPart") end,

		-- Wedge logic
		UseWedgeFacingDetection = true,
		WedgeFacingDotThreshold = 0.35,

		ActivateThreshold = 0.06,
		DeactivateThreshold = 0.02,
		NeonMinIntensity = 0.12,

	}
}
