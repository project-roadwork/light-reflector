# Light Reflector 
**Version: 1.0.0-alpha.0**

[![License: MPL 2.0](https://img.shields.io/badge/License-MPL_2.0-brightgreen.svg)](https://opensource.org/licenses/MPL-2.0)

 **A vehicle-based light reflector that reflects decals and basepart reflectors at long distances on roads.**
 #### ⚠️ Unstable - This script is under `infdev` and some functions may not work correctly.

**(ℹ️ Main) Codeberg Repo: https://codeberg.org/project-roadwork/light-reflector.git**

**(❌ Mirror/Backup) GitHub Repo: https://github.com/project-roadwork/light-reflector.git**

***Please use the main repository especially with contributions or commits!*** *Additionally, please **DO NOT** make any changes in the mirrored repository as it cannot be pulled into the main repo.*

## Module Prerequisites
**None;** *PoolerPlus in this module has been superseded by Light Reflector's own pool module.*

## Notice
*Older versions in Pesde or Wally are not accurate! Accurate older releases are in Codeberg (not GitHub).*

*Additionally, this is my first time using Pesde so my apologies if something is not formatted correctly.*

## TODO
1. ~~Make custom pooler module since PoolerPlus is neither in Wally nor Pesde~~ Finished v1.0.0-infdev.2

## Example Usage
```lua
local LightReflector = require(path.to.module)

local function determineIntensity(car)
  local finalIntensity = 1
-- logic to see if high beams are enabled or not (thus increase the intensity)
  return finalIntensity
end

LightReflector.AssignConfiguration({
  -- make any config changes here
})

LightReflector.Start()

workspace.Cars.ChildAdded:Connect(function(car)
	if car:IsA("Model") and car:FindFirstChildOfClass("VehicleSeat") then
		print("Indexed Vehicle")
		LightReflector.RegisterVehicle(car, true, determineIntensity) -- true is the placeholder of what "enables" the light source like a Headlight boolean value
	end
end)

workspace.Cars.ChildRemoved:Connect(function(car)
	if car:IsA("Model") and car:FindFirstChildOfClass("VehicleSeat") then
		LightReflector.UnregisterVehicle(car)
	end
end)
```
**Other examples such as server pre-tagging and a vehicle handler are provided in the examples folder.**

## Older YouTube Showcase
[![](https://utfs.io/f/nGnSqDveMsqxO7YMYJ0k5fKEn2LbBoPAuZ6XMTHDcNJ0QiG1)](https://www.youtube.com/watch?v=YK-_NzeLqjI)

***Not up to date***

## Current features
1. Adaptive waiting on performance-critical functions
2. Distance fall-off
3. Angle-based brightness
4. Utilizes `SurfaceGuis` for reflectivity
5. Non-tweened linear intoperlation for gradual brightness
6. Uses ImageTransparency, Brightness, and LightInfluence
7. SurfaceGui pooling
8. Multi-vehicle support (only tested for two vehicles)

## License
**License: [Mozilla Public License 2.0](https://mozilla.org/MPL/2.0/) (open source)**
