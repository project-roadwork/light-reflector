--!strict
-- USAGE: lightreflector/shared/readme.luau
-- README for Light Reflector.

--[[

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at https://mozilla.org/MPL/2.0/.

]]

return [[

	A. PROJECT ROADWORK HEADER
		-------[LIGHT-REFLECTOR]-------------------------------------------------------------
		  FILE:             Light-Reflector.luau
		  DESCRIPTION:      A light reflector that reflects decals for now at long distances.
		  functionality.
		  INIT USAGE:       Packages/lightreflector.luau - or somewhere client accessable
		  DEPENDENCIES:     N/A
		  LANGUAGE:         Luau

		  GROUP:            Project Roadwork
		  VERSION:          1.0.0-infdev.3
		  CREATED:          2025-10-26 2:03 PM CDT
		  LAST UPDATED:     2025-12-30 7:34 PM CST

		  SPDX-LICENSE-IDENTIFIER:   MPL-2.0

 		  CODEBERG REPO:    https://codeberg.org/project-roadwork/light-reflector.git (MAIN)
		  GITHUB REPO:      https://github.com/project-roadwork/light-reflector.git (BACKUP)

 		 NOTES: Use the accompanying repository links for documentation, help, or
		  to propose a suggestion or comment. The NOTICE file can be found in the respository
		  links.

		  LICENSE HEADER:
			Copyright 2024-2026 Illinois_Roadbuff ("Rogue Jr") and Project Roadwork

			This Source Code Form is subject to the terms of the Mozilla Public
			License, v. 2.0. If a copy of the MPL was not distributed with this
			file, You can obtain one at https://mozilla.org/MPL/2.0/.

		  AUTHORS:
		   Illinois_Roadbuff (RBX 2653606809) - October 26th, 2025 - Created the file
		-----------------------------------------------------------------------------------

	B. ABOUT

		LightReflector is a modular script that reflects decals and reflector baseparts at long distances,
		like a vehicle with headlights on at night seeing reflections on the road.

		This is meant to work with multiple A-Chassis vehicles operating as a "light source," but
		one can modify it to work with other chassis systems.

		Please note that enablind `UseRaycast` for signs and/or `.DescendantAdded` for pavement reflectors
		may cause severe performance issues and overhead in large maps.

		This script is not also fully complete and needs thorough testing.

	C. ASSISTANCE

		Join my communications server for assistance (ensure the link is valid):
			https://discord.gg/sd4XfAqNF9

	D. Changelog [MM/DD/YYYY]

		[12/26/2025 : Light-Reflector, Version 1.0.0] [Pre-release]
			Author: Illinois_Roadbuff "Rogue Jr"

			[Fixes]
				- Added more values into the config table which should have already been there
				- Resolve performance issues with dark conditions function (with TTP / Redon Tech weather system compatibility)
				- Resolve `OverlapParams` variable overwrite

				- Resolve SurfaceGui instance memory leak - 1.0.0-infdev.2
				- Resolve inaccurate contribution equations - 1.0.0-infdev.2
				- Resolve assert RunContext:IsClient() bug - 1.0.0-infdev.2

				- Improved comments on the init module - 1.0.0-infdev.2
				- More assertions - 1.0.0-infdev.2

				- Wedge logic or `:Dot` actually works correctly - 1.0.0-infdev.3
				- Resolved pool error where a gui not in the activeparts is returned which occurs in sudden changes of time - 1.0.0-infdev.3
				- Resolved debug spam printing when no weather system is detected - 1.0.0-infdev.3
				- Resolved sign flickering - 1.0.0-infdev.3

				- Actually fixed the SurfaceGui instance leak & pool malfunction - 1.0.0-alpha.0
				- Raycasting and debug boxes have been fixed - 1.0.0-alpha.0
				- `Cleanup()` function actually works properly - 1.0.0-alpha.0
				- Resolved some typing issues albiet this system/library is not fully typed - 1.0.0-alpha.0
				- Some sign flickering on the first few parts - 1.0.0-alpha.0

			[Features]
				- Full rewrite from a singular local script to a module with some attempt at type annotations and `--!strict`
				- Multi-source / Multi-vehicle support (experimental)
				- Pavement reflector / BasePart reflector support with separate configuration
				- Added `AddVehicle` and `RemoveVehicle` public functions to manage vehicles in the client ONLY
				- Exposed `ProcessReflecor` and `RemoveReflector` functions
				- New RunContext safety nets
				- Now utilizes a custom debugging system for logs
				- Configuration is now editable at runtime and is under a table
				- New separate `Cleanup` function
				- Improved in-script documentation
				- Equations and other important functions are moved into their own respective category files
				- Moved changelog and README into a separate file
				- New `_buildPartsCache` to improve performacy over legacy `InsertParts`
				- Modified `adaptiveWait` to work with multiple vehicles, and gets the fastest `VehicleSeat`
				- Now supports tags (CollectionService) for ONLY pavement / basepart reflectors for now over `.DescendantAdded`/`Raycast`.
					Compatibility scripts is provided in the Git repository.
				- More `Wally` and `Pesde` friendly so package managers can be used for this script in the future
				- PavementReflector baseColors will get lowered if it is too high
				- New asserts to be utilized as safety nets in certain functions
				- PavementReflector color clamps to prevent unexpected colors such as orange to lime
				- DebugBox clones for multiple vehicles if enabled (unsure? / untested)
				- Renamed `isNight` to `isDark` for clarity (now it is a separate `dark` module)
				- Specific new modules: `ver`, `config`, `debugger`, `logs`, `types`, `readme`, `dark`, `equations`, `sources`, `utils`

				- New modules "pool" and "mutex" - 1.0.0-infdev.2
				- New pcallRetry utility function - 1.0.0-infdev.2

				- Reflector tables and cached parts are now weak tables - 1.0.0-infdev.3
				- Ensures signs only light up when vehicle is actually facing the decal - 1.0.0-infdev.3
				- New configuration options and UPPER_SNAKE_CASE constraints - 1.0.0-infdev.3

				- Reduced the amount of `.Material` and `.Color` writes - 1.0.0-alpha.0
				- New hybrid subsystem that works alongside the Reflector system - 1.0.0-alpha.0
				- Many new configuration options - 1.0.0-alpha.0
				- The render loop now relies on a `RunService.PreRender` form of `wait()` for the loop - 1.0.0-alpha.0
				- New hybrid subsystem that works alongside the Reflector system - 1.0.0-alpha.0
				- Better and more specific varianle naming in the init module - 1.0.0-alpha.0
				- Separate vehicle light intensities are now compatible - 1.0.0-alpha.0
				- Functionality to keep textures or not on the Reflector system - 1.0.0-alpha.0
				- Renamed module `ver` to `version` - 1.0.0-alpha.0
				- Configuration deep merge safety check on keys and whether they exist or not - 1.0.0-alpha.0
				- Constraints are now frozen upon start - 1.0.0-alpha.0
				- Connections are now cleared out upon calling `Cleanup()` - 1.0.0-alpha.0
				- Computation optimizations by reducing `.Position` and `.CFrame` reads - 1.0.0-alpha.0
				- Reflectors now support assigning "reflecting" faces to be used on `:Dot()` or whether the light is
				  facing it or not - 1.0.0-alpha.0

			[API Changes]
				- `AddVehicle` has been changed to `RegisterVehicle` - 1.0.0-alpha.0
				- `RemoveVehicle` has been changed to `UnregisterVehicle` - 1.0.0-alpha.0
				- `ProcessReflector` has been changed to `RegisterReflector` - 1.0.0-alpha.0
				- 'RemoveReflector' has been changed to `UnregisterReflector` - 1.0.0-alpha.0
				- 'AssignConfig' has been changed to 'AssignConfiguration' - 1.0.0-alpha.0

			[Omitted (left out) or Removed]
				- Old debug functions
				- Old `isNight` function
				- Legacy weather system compatibility
				- Hard-coded configs

				- PoolerPlus dependency; replaced with custom pooler - 1.0.0-infdev.2
				- Certain assertions in `RegisterVehicle` since they error out the function when
				   it is just a safety check - 1.0.0-alpha.0

			[Other Notes]
				- AS THIS IS A PRE-RELEASE, SOME FUNCTIONS MAY NOT WORK CORRECTLY FROM v0.1.5 AND NEEDS FIXING
				- MOVING multiple vehicles have not been tested either at the time of writing
				- Merry Late Christmas to those who celebrate it :)

		[12/19/2025 : Light-Reflector, Version 0.1.5-alpha]
			Author: Illinois_Roadbuff "Rogue Jr"

			[Fixes]
				- now works without a weather system

			[Features]
				- add option to disable raycasting or not
				- another way to process signs via :GetDescendants() albeit it may lag when used frequently
				- add streaming variable

		[10/29/2025 : Light-Reflector, Version 0.1.4-alpha]
			Author: Illinois_Roadbuff "Rogue Jr"

			[Fixes]
				- move overlap params outside the loop
				- fix surfacegui safety net
				- adjust cleanup function although it does not work atm
				- adjust box radius and offset to be shorter (reflectivity is not that long on normal low beams)

			Raycast still lags badly on high part areas DESPITE overlap params

		[10/27/2025 : Light-Reflector, Version 0.1.3-alpha]
			Author: Illinois_Roadbuff "Rogue Jr"

			[Fixes]
				- remove car from include overlap param

			[Features]
				- add cleanup functionality
				- make sure that surfacegui pool is reused
				- automatically clean up when headlights are not enabled or when it is not night

		[10/27/2025 : Light-Reflector, Version 0.1.2-alpha]
			Author: Illinois_Roadbuff "Rogue Jr"
			WIP

		[10/27/2025 : Light-Reflector, Version 0.1.1-alpha]
			Author: Illinois_Roadbuff "Rogue Jr"
			WIP

		[10/27/2025 : Light-Reflector, Version 0.1.0-alpha]
			Author: Illinois_Roadbuff "Rogue Jr"
				- Initial release


]]
