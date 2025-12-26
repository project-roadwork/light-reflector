-- USAGE: lightreflector/shared/readme.luau
-- README for Light Reflector.

return [[

	A. PROJECT ROADWORK HEADER
		-------[LIGHT-REFLECTOR]-------------------------------------------------------------
		  FILE:             Light-Reflector.luau
		  DESCRIPTION:      A light reflector that reflects decals for now at long distances.
		  functionality.
		  INIT USAGE:       Packages/lightreflector.luau - or somewhere client accessable
		  DEPENDENCIES:     POOLERPLUS
		  LANGUAGE:         Luau

		  GROUP:            Project Roadwork
		  VERSION:          1.0.0-infdev.1
		  CREATED:          2025-10-26 2:03 PM CDT
		  LAST UPDATED:     2025-12-26 5:45 AM CST

		  SPDX-LICENSE-IDENTIFIER:   Apache-2.0

 		  CODEBERG REPO:    https://codeberg.org/project-roadwork/light-reflector (MAIN)
		  GITHUB REPO:      https://github.com/project-roadwork/light-reflector (BACKUP)

 		 NOTES: Use the accompanying repository links for documentation, help, or
		  to propose a suggestion or comment. The NOTICE file can be found in the respository
		  links.

		  LICENSE HEADER:
			Copyright 2024-2026 Illinois_Roadbuff "Rogue Jr," Project Roadwork and Contributors

			Licensed under the Apache License, Version 2.0 (the "License");
		 	 http://www.apache.org/licenses/LICENSE-2.0

		  AUTHORS:
		   Illinois_Roadbuff (2653606809) - October 26th, 2025 - Created the file
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

		[12/26/2025 : Light-Reflector, Version 1.0.0-infdev]
			Author: Illinois_Roadbuff "Rogue Jr"

			[Fixes]
				- Added more values into the config table which should have already been there
				- Resolve performance issues with dark conditions function (with TTP / Redon Tech weather system compatibility)
				- Resolve `OverlapParams` variable overwrite

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

			[Omitted (left out) or Removed]
				- Old debug functions
				- Old `isNight` function
				- Legacy weather system compatibility
				- Hard-coded configs

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
