## Issues
Common issues you may encounter while using Light Reflector.

## Global Issues
### Neither reflectors nor signs work at all!

**Did you do the following:**
1. Ensure that the reflector tags `Reflector` and sign tags `ReflectiveSign` are present on the part? (if applicable)
2. Checked if your vehicle is actually registered in Light Reflector? Usually prints "Indexed Vehicle" in the output.
3. Try passing `true` on the `CheckForRegLightValue` function and seeing if it works without checking for the regular light value
4. Ensure that Light Reflector loaded properly (no `Requested module failed to load` errors)

## Sign Issues
### My sign appears distorted and/or does not light up properly using the decal renderer!

![Diagram](../../assets/images/internal/figures/012_issues_sign_issue_1.png)

**Did you do the following:**

1. Checked off all possible global issues
2. Ensure that the material is NOT `Metal`, AND have used another material such as `SmoothPlastic`

### My sign is orientated incorrectly while using the SurfaceGui renderer!

**Unfortunately, this may happen if the Decal's face is `Top` or `Bottom`.** 

**You could try the following:**
1. Using the decal renderer instead of the SurfaceGui renderer
2. Rotating/resizing a part to NOT use the `Top` or `Bottom` face

## Reflector Issues
### My base reflectors are tagged, but do not work!

**Did you do the following:**
1. Ensure that there are NO textures whatsoever, and that the base reflector is a standard `BasePart`?
2. Ensure that reflectors are properly indexed (usually there should be a BaseColor attribute showing during runtime)

## Hybrid Reflector Issues
### My hybrid reflectors are tagged, but do not work!

**Did you do the following:**
1. Ensure that if it is a `Union`, that `KeepColors` is disabled? (Or you could pass an override)
2. Ensure that you have the required attributes `LRHybrid` (boolean) and `LRFace` (string)?
3. Ensure that `LRFace` is a valid `Enum.NormalId` value? (`Front`, `Back`, `Right`, `Top`, etc.)

## Next, learn about errors!

---

[Previous Page](./011_api.md) | [Next Page](./013_errors.md)
