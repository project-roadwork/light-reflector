# Light Reflector 
**Version: 1.0.0-infdev.2**

 **A vehicle-based light reflector that reflects decals and basepart reflectors at long distances on roads.**
 #### ⚠️ Unstable - This script is under infdev and some functions may not work correctly.

**(ℹ️ Main) CODEBERG REPO:** https://codeberg.org/project-roadwork/light-reflector.git

**(❌ MIRRORED/BACKUP) GITHUB REPO:** https://github.com/project-roadwork/light-reflector.git

***Please use the main repository especially with contributions!*** *Additionally, please **DO NOT** make any changes in the mirrored repository as it cannot be pulled into the main repo.*

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

LightReflector.AssignConfig({
  -- make any config changes here
})

LightReflector.Start()

workspace.Cars.ChildAdded:Connect(function(car)
	if car:IsA("Model") and car:FindFirstChildOfClass("VehicleSeat") then
		print("Indexed Vehicle")
		LightReflector.AddVehicle(car, true) -- true is the placeholder of what "enables" the light source like a Headlight boolean value
	end
end)

workspace.Cars.ChildRemoved:Connect(function(car)
	if car:IsA("Model") and car:FindFirstChildOfClass("VehicleSeat") then
		LightReflector.RemoveVehicle(car)
	end
end)
```
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
**License: [Apache License 2.0](https://www.apache.org/licenses/LICENSE-2.0) (open source)**
