# Light Reflector 
**Latest Pre-Release Version: N/A**

**Latest Partially Stable Version: 2.3.0**

 **A vehicle-based light reflector system that reflects `Decals` and `BasePart` reflectors at long distances on roads, built using [Jecs](https://github.com/Ukendio/jecs.git).**

[![License: MPL 2.0](https://img.shields.io/badge/MPL_2.0-License-gray.svg?logo=mozilla&labelColor=28733f)](https://opensource.org/licenses/MPL-2.0) [![Codeberg](https://img.shields.io/badge/Codeberg-Main%20Repository-white?logo=codeberg)](https://codeberg.org/project-roadwork/light-reflector.git) [![GitHub](https://img.shields.io/badge/GitHub-Mirror/Backup%20Repository-darkgrey?logo=github)](https://github.com/project-roadwork/light-reflector.git) 


> [!IMPORTANT]
> ****Please use the [main repository](https://codeberg.org/project-roadwork/light-reflector.git) especially with contributions or commits!*** *Additionally, please **DO NOT** make any changes in the mirrored repository as it cannot be pulled into the main repo.**
> 
> **The main repository is in Codeberg; however, I provided a *push* mirror on GitHub (pulls are not supported). Open an issue in Codeberg if you have concerns with this.**

> [!NOTE]
> ### Codeberg Releases (`.rbxm` download)
> ***https://codeberg.org/project-roadwork/light-reflector/releases***

> [!WARNING]
> **This script is under `alpha` and some functions may not work correctly or be unstable. Additionally, there is no *external* documentation for this module at the moment.**

### Wally / Pesde Notice
**The Wally and Pesde packages are outdated! Unfortunately I cannot publish Pesde packages due to `const` usage.**

*Additionally, this is my first time using Pesde AND Wally - apologies if something is not formatted correctly.*

### Issues
1. **Broken Wally and Pesde packages, with mismatched versioning**
2. **Rojo may not work correctly?**
3. **Possible BasePart memory leak on games with Instance Streaming**
4. ~~**Many `:GetAttribute` calls popping up in the Microprofiler**~~
5. **No external documentation**
6. **Some signs and reflectors may not work at all in very rare occasions**

## Global features
1. Adaptive waiting on performance-critical functions
2. Distance fall-off
3. Angle-based brightness
4. Multi-vehicle support
5. Non-tweened fading/transitions for gradual brightness
6. Option to use `Tags` with `CollectionService`
7. Uses Entity Component System via [Jecs](https://github.com/Ukendio/jecs.git)

## Sign/Gantry System Features
1. Utilizes `SurfaceGuis` and `ImageLabel` OR `Decals` by itself for reflectivity
2. Uses `.ImageTransparency`, `.Brightness`, and `.LightInfluence`
3. SurfaceGui pooling to increase performance
4. Automatic sign `:Dot` support
   * This determines if the vehicle is facing the sign or not to determine reflectiveness
5. Automatic part rotation for `Top` faces
   * Part rotation is needed since the orientation of images in `Decals` and `SurfaceGuis` are NOT the same
   * This may break the visuals of actual non-square parts due to rotations
6. Best for large reflective highway signs on gantries

## Reflector System Features
1. Utilizes `BaseParts` for reflectivity
2. Uses `.Color` and `.Material`
3. Wedge `:Dot` support, with face (`Enum.NormalId`) selection on non-wedges
   * This determines if the vehicle is facing the part or not to determine reflectiveness
4. Best for pavement reflectors on the road

### Hybrid System Features
1. Works alongside the Reflector System with no separate loop needed
2. Uses `.Color`, `.Material`, AND `.Transparency` with similar equations to the Sign/Gantry System
3. Face (`Enum.NormalId`) selection
4. Best for reflective traffic light shields, non-decal signs, etc.

## Essential Public API
1. `.start()` - Starts the module
2. `.cleanup()` - Resets states and cleans up the module
3. `.config.applyOverrides({})` - Parses user configuration before starting (if you cannot do it IN the module first)
4. `.register.registerVehicle(car: Instance, isHeadlightEnabled: () -> boolean, getIntensity: () -> number)` - Registers vehicles into the module
5. `.register.unregisterVehicle(car: Instance)` - Unregisters vehicles from the module

## Example Usage
```lua
local LightReflector = require(path.to.module)

local function determineIntensity(car)
  local finalIntensity = 1
-- logic to see if high beams are enabled or not (thus increase the intensity)
  return finalIntensity
end

LightReflector.config.applyOverrides({
  -- make any config changes here
})

LightReflector.start()

workspace.Cars.ChildAdded:Connect(function(car)
	if car:IsA("Model") and car:FindFirstChildOfClass("VehicleSeat") then
		print("Indexed Vehicle")
		LightReflector.register.registerVehicle(car, true, determineIntensity) -- true is the placeholder of what "enables" the light source like a Headlight boolean value
	end
end)

workspace.Cars.ChildRemoved:Connect(function(car)
	if car:IsA("Model") and car:FindFirstChildOfClass("VehicleSeat") then
		LightReflector.register.unregisterVehicle(car)
	end
end)
```
**Other examples such as server pre-tagging and a vehicle handler are provided in the examples folder.**

## Systems Diagram
![Diagram](assets/images/light_reflector_systems.png)

## Older YouTube Showcase
***Not up to date, uses 0.1.x***
[![](https://utfs.io/f/nGnSqDveMsqxO7YMYJ0k5fKEn2LbBoPAuZ6XMTHDcNJ0QiG1)](https://www.youtube.com/watch?v=YK-_NzeLqjI)


## Contributing
**This section exists due to the file-level copyleft nature of the Mozilla Public License 2.0.**

*By contributing to this project, you agree that your contributions may be redistributed and relicensed by this project under other open-source and/or open-content licenses in the future (such as Apache-2.0).*

**View the reason why this clause exists in [./CONTRIBUTING.md](CONTRIBUTING.md)**

## License
**License: [Mozilla Public License 2.0](https://mozilla.org/MPL/2.0/) (open source).** 

*This may be changed to a more permissive license in the future, but unlikely.*

> [!NOTE]
> ### Mozilla Public License 2.0 Summary
> **Warning: This summary does NOT act as a subsitute for the entire legal text. This is also not legal advice**
> 
> **The Mozilla Public License 2.0 (MPL-2.0) is a weak copyleft license.**
> 
> **You are free to:**
> * Use, modify, and distribute the code
> * Use the code commercially (including games and/or proprietary software)
>
> **Under the following conditions:**
> * Any files originally from MPL that you modify must remain licensed under MPL
> * You must make the source code of MPL-licensed files publicly available
> * MPL-covered code must remain in separate files
> 
> **In short:** You can use MPL code in closed-source and/or commercial projects; however, any changes to MPL-covered files must stay open under MPL.
>
> **Compared to GPL/GNU licenses:**
> * **GPL:** May require the entire project (like games) to be fully open-sourced under GPL if GPL code is included
> * **LGPL:** Allows use in proprietary projects, but requires that users can modify and swap out LGPL-covered code and still run the project with it, which is not very feasible with games and closed-source binary platforms such as ROBLOX. Additionally, this license allows users to reverse engineer entire projects
> * **MPL:** Only requires open-sourcing the specific modified files

### License Comparison (not legal advice)

| Feature / License        | Expact (aka "MIT")    | Apache 2.0 | MPL 2.0       | GPL / AGPL v3               |
| ------------------------ | ------ | ---------- | ------------- | ------------------------ |
| **Permissive**           | ✅      | ✅          | ℹ️ Partial    | ❌                        |
| **Patent Clause**         | ❌      | ✅          | ✅             | ✅                        |
| **Proprietary Use OK**   | ✅      | ✅          | ✅¹           | ❌  (Must release whole source)                       |
| **Roblox Asset Usage**   | ✅      | ✅          | ℹ️ Depends; must share any changes    | ❌ May violate terms      |

* ¹ Proprietary use in MPL is permitted (allowed) as long as the MPL-covered files remain open souce.
