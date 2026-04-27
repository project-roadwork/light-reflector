--!strict
-- USAGE: lightreflector/shared/readme.luau
-- README for Light Reflector.

--[[
    SPDX-FileCopyrightText: 2025-2026 Illinois_Roadbuff (Rogue Jr) <illinois_roadbuff@proton.me>
	SPDX-FileCopyrightText: 2025-2026 Project Roadwork and Contributors

	SPDX-License-Identifier: MPL-2.0

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
		  VERSION:          2.2.0
		  CREATED:          2025-10-26 2:03 PM CDT
		  LAST UPDATED:     2026-04-24 11:11 PM CDT

		  SPDX-License-Identifier:   MPL-2.0
		  SPDX-FileCopyrightText:   2025-2026 Illinois_Roadbuff (Rogue Jr) <illinois_roadbuff@proton.me>
		  SPDX-FileCopyrightText:   2025-2026 Project Roadwork and Contributors

 		  CODEBERG REPO:    https://codeberg.org/project-roadwork/light-reflector.git (MAIN)
		  GITHUB REPO:      https://github.com/project-roadwork/light-reflector.git (BACKUP/MIRROR)

 		 NOTES: Use the accompanying repository links for documentation, help, or
		  to propose a suggestion or comment. The NOTICE file can be found in the respository
		  links.

		  LICENSE HEADER:
			Copyright 2025-2026 Illinois_Roadbuff (Rogue Jr)
			Copyright 2025-2026 Project Roadwork and Contributors

			This Source Code Form is subject to the terms of the Mozilla Public
			License, v. 2.0. If a copy of the MPL was not distributed with this
			file, You can obtain one at https://mozilla.org/MPL/2.0/.

		  AUTHORS:
		   Illinois_Roadbuff (Rogue Jr) (RBX 2653606809) - October 26th, 2025 - Created the file
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

	    [04/24/2026 : Light-Reflector, Version 2.3.1]
			Author: Illinois_Roadbuff "Rogue Jr"

			[Fixes]
			    - MAJOR: Fixed rojo
			    - Removed unused variables
				- Fixed some typing annotations

			[Features]
				- Added more descriptors for some config variables

		[04/23/2026 : Light-Reflector, Version 2.3.0]
			Author: Illinois_Roadbuff "Rogue Jr"

			[Fixes]
				- MAJOR: Fixed `.cleanup()` not deleting entities properly, causing pooling issues once the module started back up
				- MAJOR: Fixed signs not following the source's light angle and lighting up even when the source is turned away
				  by nearly 80 degrees
				- Fixed signs under the `decal` render mode not fading out properly compared to signs under the `SurfaceGui` mode.

			[Features]
				- New `states` module: Reflector, SurfaceGui, Decal, and global sign states are now recycled to reduce table creation
				  (experimental). Should this malfunction, you may enable the flag `NO_STATE_POOLING` in the `config` module.
				- The `dark` module has been optimized by checking whether the weather folder exists once rather than being called
				  every render frame.
				- Added a debug function that shows the light angle of the source. This can be enabled by the `isDebugConeAngleEnabled`
				  boolean in the `config` module
				- Added raycasting to detect obstacles between the source and signs. This can be enabled by the `useRaycastForObstacles`
				  boolean in the reflector and sign `config`. Please note that this may cause lag for multiple entities.
				- When `useRaycastForObstacles` is enabled, signs can now adjust brightness based on the obstacle's part transparency.

			[API CHANGES]
				- **Change:** `lightreflector.cleanup()` is now `lightreflector.reset()`
				- **Change:** `lightreflector.register.registerVehicle()` is now `lightreflector.register.addVehicle()`
				- **Change:** `lightreflector.register.unregisterVehicle()` is now `lightreflector.register.removeVehicle()`
				- **Change:** `lightreflector.register.registerReflector()` is now `lightreflector.register.addReflector()`
				- **Change:** `lightreflector.register.unregisterReflector()` is now `lightreflector.register.removeReflector()`
				- **New:** `lightreflector.register.addSign()`
				- **New:** `lightreflector.register.removeSign()`

			Please note that although you can register/unregister signs/reflectors manually via the `init` module, it is still recommended
			that you use `tags` via `CollectionService` to automatically register entities.

		[04/20/2026 : Light-Reflector, Version 2.2.0]
			Author: Illinois_Roadbuff "Rogue Jr"

			[Fixes]
				- MAJOR: Fixed sign malfunctioning by updating the state's CFrame and Size before computing sign intensity

			[Features]
				- Reduced the number of `.getConfig()` calls by adding `onChange()` (like `.Changed:Connect()`, etc) to the config
				- Removed unused ECS component `Vehicles` (`VehicleInstance` already exists)

		[04/19/2026 : Light-Reflector, Version 2.1.1]
			Author: Illinois_Roadbuff "Rogue Jr"

			[Fixes]
				- Disabled a debug FLAG that caused intense lag in certain games
				- Fixed version mismatch

		[04/19/2026 : Light-Reflector, Version 2.1.0]
			Author: Illinois_Roadbuff "Rogue Jr"

			[Fixes]
				- Resolved an issue where .DescedantRemoved on sign folders would "register" the sign again instead of "unregister"
				- Resolved an issue where `trackAncestryRemoval` connections would duplicate itself although the connection already
				 exists for the respective part
				- Fixed a spelling error ('trackAnsestryRemoval') in the `trackAncestryRemoval` function

			[Features]
				- Light Reflector now runs as an Entity Component System via [Jecs](https://github.com/Ukendio/jecs/)!
				- This module is now nearly or fully typed
				- Added an ability to check for updates (must be called on the server without requiring the main module)
				- Decentrialized the init module, and added three new modules: `detect`, `render`, and `register`
				- Config has the new functions: `lock`, `unlock`, `waitForLock`, `getKey`, `getSection`, `overrideKey`, and `getConfig`
				- Reduced the number of calls of `areColorsEqual`
				- Added FLAGS in the config. The current functional FLAGS are `PCALL`, and `TRACK_ANCESTRY_REMOVAL_CONNECTIONS`.
				- Organized the types module
				- New module `jecs` in `shared` (since Types must access it)
				- Added an ability to track connections for `TrackAncestryRemoval` which can be enabled via the FLAG `TRACK_ANCESTRY_REMOVAL_CONNECTIONS`
				- Added the new Luau variable `const` to wherever possible except in Jecs

			[Other Notes]
				- Added `MAX_MPH` in the config that would determine the maximum speed for the renderer and detector to run at.
				- Updated the spatial grid module to support the main ECS Entity Ids instead of creating new ones.

			[API CHANGES]
				- `lightreflector.Configure()` is now `lightreflector.config.applyOverrides()`
				- `lightreflector.RegisterVehicle()` is now `lightreflector.register.registerVehicle()`
				- `lightreflector.UnregisterVehicle()` is now `lightreflector.register.unregisterVehicle()`
				- 'lightreflector.RegisterReflector()' is now `lightreflector.register.registerReflector()`
				- 'lightreflector.UnregisterReflector()' is now `lightreflector.register.unregisterReflector()`
				- 'lightreflector.Cleanup()' is now `lightreflector.cleanup()`
				- 'config' (by itself) is now `config.getConfig()`

		[04/19/2026 : Light-Reflector, Version 2.0.0-alpha.0+NONECS] [Pre-release]
			Author: Illinois_Roadbuff "Rogue Jr"

			THIS IS AN ARCHIVE AND PRE-RELEASE, NOT TO BE USED IN PRODUCTION UNLESS PURELY NECESSARY.

			[Other Notes]
				- The last copy of Light Reflector WITHOUT Jecs
				- Fully typed

		[03/20/2026 : Light-Reflector, Version 1.2.0-alpha.0] [Pre-release]
			Author: Illinois_Roadbuff "Rogue Jr"

			[Fixes]
				- Resolved `Cleanup()` malfunction

			[Other Notes]
				- Added a spatial grid module for reflectors only
				- More cacheing and optimizations, making the module run about 3.4x faster
				- Enabling/disabling headlights will force update the reflectors in 1/15th of a second rather than per loop

		[03/20/2026 : Light-Reflector, Version 1.1.1-beta] [Pre-release]
			Author: Illinois_Roadbuff "Rogue Jr"

			[Fixes]
				- Resolved issue where reflector states may be nil

		[03/20/2026 : Light-Reflector, Version 1.1.0-beta] [Pre-release]
			Author: Illinois_Roadbuff "Rogue Jr"

			[Fixes]
				- Moved cleanup loops out of the `partDictionary` loop (why was it even there in the first place)
				- Modifying the constraints after startup now warns the user and returns the function
				- Main decals on a part are now cached to reduce repeated lookups

			[Features]
				- The Sign system now runs on two render modes: `SurfaceGui` and `Decal`
				- Added support for light reflection on the decal itself by increasing the Color3 above (255, 255, 255)
				- Improved version handling

			[Other Notes]
				- To reduce confusion, the `pool`, `debugger`, and `mutex` module are no longer dual-licensed, and now follows the overall
					project license (MPL-2.0). There are barely any changes to the original derived source, so users could
					simply head over to the repository and get the code under the original license (MIT) instead.

				- Bumped from version `1.0.0` to `1.1.0` since Wally and Psede packages are broken with the invalid `infdev` tag.
					Additionally, continuing to stay on `1.0.0` until the module is "stable" is unnecessary, and more features are
					being added anyway which are outside the scope of the original `1.0.0` plan.

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

				- Attempted to resolve reflector memory/instance leak - 1.0.0-alpha.1
				- Removed unused `.Color` and `.Material` reads which consumed A LOT of CPU resources - 1.0.0-alpha.1
				- Loops get `continued` if there is barely any difference in the reflector intensities - 1.0.0-alpha.1
				- New reflector state property `lastIntensity` - 1.0.0-alpha.1

				- Resolved `Cleanup()` not resetting reflectors properly - 1.0.0-alpha.2
				- The table `ObjectPool` and `Mutex` are now frozen - 1.0.0-alpha.2

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

				- `AssignConfiguration` has been changed to `Configure` - 1.0.0-alpha.2

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
