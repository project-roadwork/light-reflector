## Reflectors (general)

> [!NOTE]
> All images herein are taken by Illinois_Roadbuff (both in real life and his games), and do not come from other sources.

[Road] reflectors are safety devices that reflect by vehicle headlights.

![Diagram](../../assets/images/external/noncommons/il171_i355_lockport_night.jpg)

In games, it would usually be displayed as a neon or force field part.

![Diagram](../../assets/images/external/crossroads/il171_i355_lockport_night_crossroads_stil.jpg)

## Hybrid Reflectors

Hybrid reflectors are a type of reflector in Light Reflector that *includes* the logic used in the `Sign` system. Since standard reflectors may transition unsmoothly when enlarged, the base reflector is cloned and uses `.Transparency` to transition smoothly. They are best for reflective traffic light shields, reflective flags, and non-decal signs; however, they should not be used on too many parts clustered in one area.

![Diagram](../../assets/images/external/crossroads/il171_143st_lockport_night_crossroads_stil.jpg)

*(highlighted in red includes hybrid reflectors)*

Note that non-decal signs used as hybrid reflectors MUST have dark text (such as a standard U.S. MUTCD warning sign). Manipulating the brightness of `SurfaceGui`s, their accompanying `TextLabel`s, AND the sign part(s) itself concurrently will put a massive strain on performance.

![Diagram](../../assets/images/internal/figures/008_reflectors_fig1.png)

## Systems

### Base Reflector System
The base reflector system uses `.Color` and `.Material` on `BasePart`s to mimic reflectance. Before changing a part to neon, the original `BasePart` `Color3`'s are normalized into a lighter/darker color so dark-colored reflectors will not look too dark when the material is set to `Neon`, and vice versa for light-colored reflectors.

### Hybrid Subsystem
The hybrid subsytem works alongside the base reflector system, using `.Color`, `.Transparency` and `.Material` on reflector clones to mimic reflectance.

### Next, learn about configuration overrides per part/entity!
