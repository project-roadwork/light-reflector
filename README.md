# Light Reflector 
**Version: 1.0.0-alpha.1**

 **A vehicle-based light reflector system that reflects `Decals` and `BasePart` reflectors at long distances on roads.**

[![License: MPL 2.0](https://img.shields.io/badge/MPL_2.0-License-gray.svg?logo=mozilla&labelColor=28733f)](https://opensource.org/licenses/MPL-2.0) [![Codeberg](https://img.shields.io/badge/Codeberg-Main%20Repository-white?logo=codeberg)](https://codeberg.org/project-roadwork/light-reflector.git) [![GitHub](https://img.shields.io/badge/GitHub-Mirror/Backup%20Repository-darkgrey?logo=github)](https://github.com/project-roadwork/light-reflector.git) 

***Please use the main repository especially with contributions or commits!*** *Additionally, please **DO NOT** make any changes in the mirrored repository as it cannot be pulled into the main repo.*

 #### ⚠️ Unstable - This script is under `alpha` and some functions may not work correctly.

## Wally / Pesde Notice
*Older versions in Pesde or Wally are not accurate! Accurate older releases are in Codeberg (not GitHub).*

*Additionally, this is my first time using Pesde - apologies if something is not formatted correctly.*

## Current features
1. Adaptive waiting on performance-critical functions
2. Distance fall-off
3. Angle-based brightness
4. Utilizes `SurfaceGuis` for reflectivity
5. Non-tweened linear intoperlation for gradual brightness
6. Uses ImageTransparency, Brightness, and LightInfluence
7. SurfaceGui pooling
8. Multi-vehicle support (only tested for two vehicles)

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

## License
**License: [Mozilla Public License 2.0](https://mozilla.org/MPL/2.0/) (open source)**
