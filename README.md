# light-reflector

 A vehicle-based light reflector that reflects decals and basepart reflectors at long distances on roads.
 #### ⚠️ Unstable - This script is under infdev and multi-vehicle support has not been tested thoroughly yet.

**(ℹ️ MAIN) CODEBERG REPO:** https://codeberg.org/project-roadwork/light-reflector

**(❌ MIRRORED/BACKUP) GITHUB REPO:** https://github.com/project-roadwork/light-reflector

***Please use the main repository especially with contributions!*** *Additionally, please **DO NOT** make any changes in the mirrored repository as it cannot be pulled into the main repo.*

## Prerequisites
Requires **PoolerPlus** parented under ReplicatedStorage, but you may try to replace it with your own object pool should it be neccesary.
Link: https://devforum.roblox.com/t/v14-poolerplus-advanced-object-pooling/3817379/

PoolerPlus is also not in Wally or Pesde, so you have to install it yourself via DevForum. Additionally, I plan to have a custom pooler module so that PoolerPlus is not needed.

## Notice
Older versions in Pesde or Wally are not accurate! Accurate older releases are in Codeberg (not GitHub).

## TODO
1. Make custom pooler module since PoolerPlus is neither in Wally nor Pesde

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
## Current features
1. Adaptive waiting on performance-critical functions
2. Distance fall-off
3. Angle-based brightness
4. Utilizes `SurfaceGuis` for reflectivity
5. Non-tweened linear intoperlation for gradual brightness
6. Uses ImageTransparency, Brightness, and LightInfluence
7. SurfaceGui pooling
8. Multi-vehicle support (untested)

---

License: Apache 2.0
