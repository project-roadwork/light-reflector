# light-reflector

**README WIP**

 A vehicle-based light reflector that reflects decals and basepart reflectors at long distances on roads.
 ### ⚠️ LIMITED FUNCTIONALITY; really just works for the local player for now.

**(ℹ️ MAIN) CODEBERG REPO:** https://codeberg.org/project-roadwork/light-reflector

**(❌ MIRRORED/BACKUP) GITHUB REPO:** https://github.com/project-roadwork/light-reflector

***Please use the main repository especially with contributions!*** *Additionally, please **DO NOT** make any changes in the mirrored repository as it cannot be pulled into the main repo.*

## Prerequisites
Requires **PoolerPlus** parented under ReplicatedStorage, but you may try to replace it with your own object pool should it be neccesary.
Link: https://devforum.roblox.com/t/v14-poolerplus-advanced-object-pooling/3817379/

## Current features
1. Adaptive waiting on performance-critical functions
2. Distance fall-off
3. Angle-based brightness
4. Utilizes `SurfaceGuis` for reflectivity
5. Non-tweened linear intoperlation for gradual brightness
6. Uses ImageTransparency, Brightness, and LightInfluence
7. SurfaceGui pooling
8. Multi-vehicle support

---

License: Apache 2.0
