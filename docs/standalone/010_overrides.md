## Overrides

Overrides are ways to temporarily change behavior of a certain sign or part wihtout modifying the base configuration. Overrides are typically enabled via attributes on the sign or reflector part.

### Global Overrides

| Name | Type | Description |
| -------- | -------- | ---- |
| LRBaseIntensity | `number` | Controls how reflective the sign or reflector is |
| LRMoving | `boolean` | Lets the system know if sign or reflector moves |

### Sign Overrides

| Name | Type | Description |
| -------- | -------- | ---- |
| LRRenderMode | `string` | `SurfaceGui` or `Decal`. Specifies what render mode the sign should be in |

### Base Reflector Overrides

| Name | Type | Description |
| -------- | -------- | ---- |
| LRCanKeepTextures | `boolean` | Whether the reflector should keep its texture or not. Primarily affects meshes |

### Hybrid Reflector Overrides

| Name | Type | Description |
| -------- | -------- | ---- |
| HybridMinDistance | `number` | Minimum distance for a hybrid reflector to reflect |
| HybridMaxDistance | `number` | Maximum distance for a hybrid reflector to reflect |
| CanHybridKeepColors | `boolean` | Whether the hybrid reflector should keep its color or not (not recommended). Primarily affects unions |
| HybridTransparencyMultiplier | `number` | Transparency multiplier for the hybrid clone |
| HybridCanKeepTexturs | `number` | Whether the hybrid clone should keep its textures. This does not affect the main reflector |

## Next, learn about the public API!

---

[Previous Page](./009_config.md) | [Next Page](./011_api.md)
