<br>

<div align="center">
    <img src="https://codeberg.org/project-roadwork/light-reflector/raw/branch/main/assets/images/internal/branding/large-logo-svg.svg" alt="light reflector logo" width="500" />
</div>

<br>

 **A light reflector system that simulates long-range reflections of `Decals` and `BaseParts`.**

[![License: MPL 2.0](https://img.shields.io/badge/MPL_2.0-License-gray.svg?logo=mozilla&labelColor=28733f)](https://opensource.org/licenses/MPL-2.0) [![Codeberg](https://img.shields.io/badge/Codeberg-Main%20Repository-white?logo=codeberg)](https://codeberg.org/project-roadwork/light-reflector.git) [![GitHub](https://img.shields.io/badge/GitHub-Mirror/Backup%20Repository-darkgrey?logo=github)](https://github.com/project-roadwork/light-reflector.git) [![Documentation](https://img.shields.io/static/v1?label=&message=Documentation&color=informational)](https://project-roadwork.codeberg.page/light-reflector/)

> [!IMPORTANT]
> **Use the [main repository in Codeberg](https://codeberg.org/project-roadwork/light-reflector.git) for issues, pull requests, and contributions.**
> **The [GitHub repository](https://github.com/project-roadwork/light-reflector.git) is a *read-only* mirror, and pull requests are not supported.**

> [!NOTE]
> ***You must have the new Luau type solver enabled in `Workspace` in order to receive proper types.***

## Features
* Supports `Decal` and `BasePart` reflectors
* Distance and angle-based falloff
* Multi-source support
* [Type-safe](https://en.wikipedia.org/wiki/Type_safety) [Luau](https://luau.org/) API
* `CollectionService` tag integration
* Reflection beyond the 120 stud limit
* Designed for vehicles, but accepts any `BasePart` as a light source
* States and caching; [view benchmarks (WIP) ➚](./docs/standalone/997_benchmarks.md)
* [ECS](https://en.wikipedia.org/wiki/Entity_component_system) architecture via [Jecs](https://github.com/Ukendio/jecs.git)

<details>
    <summary>Performance Strategies</summary>

## Performance
* State caching
* `SurfaceGui` and table pooling
* Avoids property writes unless needed
* Uses `vector`s in color processing rather than `Color3`s
  * `Color3`s are only used when writing to `Instances`
* Lookup table for smoothstep
* Adaptive frame timing based on the fastest `source`
* ECS for data-oriented iteration

</details>

***[Showcase (View on YouTube) (Outdated) ➚](https://www.youtube.com/watch?v=YK-_NzeLqjI)***

## Installation
You may get the `.rbxm` file directly from [Codeberg Releases](https://codeberg.org/project-roadwork/light-reflector/releases), or [install via Wally or Pesde](./docs/standalone/002_installation.md).

For more information, *read the [installation guide](./docs/standalone/002_installation.md).*

## Getting Started

After installation, follow the usage guide in the [documentation](https://project-roadwork.codeberg.page/light-reflector/) or check the accompanying examples in [./examples](./examples).

The accompanying examples and usage guide will provide you with practical setups for tags, configuration, initialization, and registering sources.

### Additional Support
Should you need additional support, *you may join my [Discord server](https://discord.gg/sd4XfAqNF9) and create a support post in the forum channel `#oss-support`.*

## Contributing
*By contributing to this project, you agree that your contributions may be used under the project's current or future open-source/open-content licenses such as Apache-2.0.*

**View the reason why this clause exists in [./CONTRIBUTING.md](CONTRIBUTING.md)**

<details>
    <summary>Miscellaneous</summary>

## TypeScript support?
I tried to add `TypeScript` support; however, I am unsure whether it works correctly or not... I did not cover all luau files with `d.ts` files.

</details>

## License
**License: [Mozilla Public License 2.0](https://mozilla.org/MPL/2.0/) (MPL-2.0)** 

<details>
  <summary>MPL 2.0 summary (not legal advice)</summary>

> ### Mozilla Public License 2.0 Summary
> **Warning: This summary does NOT act as a substitute for the entire legal text. This is also not legal advice**
> 
> **The Mozilla Public License 2.0 (MPL-2.0) is a weak copyleft license.**
> 
> **You are free to:**
> * Use, modify, and distribute the code
> * Use the code commercially (including games and/or proprietary software)
>
> **Under the following conditions:**
> * You must make the source code of MPL-licensed files available to recipients *(Section 3.3)*
> * MPL applies on a file-by-file basis; any files originally from MPL that you modify must remain licensed under MPL *(Section 3.2)*
> * You must keep the existing copyright, license, or attribution notices intact *(Section 3.4)*
> * Include a copy of the license or link to it, and clearly state that the MPL-covered code is provided under MPL terms *(Section 3.1)*
> 
> **In short:** You can use MPL code in closed-source and/or commercial projects; however, any changes to MPL-covered files must stay open under MPL.
>
> **Compared to GPL/GNU licenses:**
> * **GPL:** May require the entire project (like games) to be fully open-sourced under GPL if GPL code is included
> * **LGPL:** Allows use in proprietary projects, but requires that users can modify and swap out LGPL-covered code and still run the project with it, which is not very feasible with games and closed-source binary platforms such as ROBLOX. Additionally, this license allows users to reverse engineer entire projects
> * **MPL:** Only requires open-sourcing the specific modified files

### License Comparison (not legal advice)

| Feature / License        | Expat (aka "MIT")    | Apache 2.0 | MPL 2.0       | GPL / AGPL v3               |
| ------------------------ | ------ | ---------- | ------------- | ------------------------ |
| **Permissive**           | ✅      | ✅          | ℹ️ Partial    | ❌                        |
| **Patent Clause**         | ❌      | ✅          | ✅             | ✅                        |
| **Proprietary Use**   | ✅      | ✅          | ℹ️¹           | ❌  (Must release whole source)                       |
| **ROBLOX Asset Usage**   | ✅      | ✅          | ℹ️ Depends; must share any changes    | ❌ May violate terms      |

* ¹ Proprietary use in MPL is permitted (allowed) as long as the MPL-covered files remain open souce.

</details>

<details>
  <summary>I want to distribute MPL-licensed sorce code that I have modified. What do I have to do?</summary>

> ### I want to distribute MPL-licensed sorce code that I have modified. What do I have to do?
>
> **To see the full legal requirements, refer to the license text. In general, you must do the following:**
>
> **Inform recipients that the code is licensed under the MPL**
> * Include a copy of the license or a link to it, and clearly state that the source code is provided under MPL terms *(Section 3.1)*.
>
> **Grant the same rights that you have received to the recipients** 
> * This includes the rights to use, modify, and distribute the code, along with any applicable patent grants *(Section 2.1)*.
>
> **Keep existing notices intact**
> * Do not remove or alter copyright, license, or attribution notices in the source files *(Section 3.4)*.
>
> **Make the source code of modified files available**
> * Any files you modify that are covered by the MPL must be available in source form when you distribute them *(Section 3.2)*.
>
> **Keep modified MPL files under the MPL**
> * These files must remain licensed under the MPL, even when the rest of your project uses a different license *(Section 3.3)*.

</details>

**Note that some individual files may be under differing licenses; as a whole, the project is under the [Mozilla Public License 2.0](https://mozilla.org/MPL/2.0/).**

**For file-specific licensing information, including documentation and images, you may refer to [REUSE.toml](./REUSE.toml). You may also consult [NOTICE.txt](NOTICE.txt) for information regarding other softwares included in this project.**

## Attribution
### Vendored/Internal Packages
* *[ObjectPool](https://github.com/ntqltx/ObjectPool.git) v0.1 — by qaltx*
* *[Debugger](https://github.com/axiom-co/debugger.git) v1.0.3 — by Axiom (formally Lumin Labs) and contributors*
* *[Jecs](https://github.com/Ukendio/jecs.git) v0.11.0 — by Ukendio and jecs authors*
