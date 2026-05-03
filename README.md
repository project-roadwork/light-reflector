<br>

<div align="center">
    <img src="https://codeberg.org/project-roadwork/light-reflector/raw/branch/main/assets/images/internal/branding/large-logo-svg.svg" alt="light reflector logo" width="500" />
</div>

<br>

 **A light reflector system that simulates long-range reflections of `Decals` and `BaseParts`.**

[![License: MPL 2.0](https://img.shields.io/badge/MPL_2.0-License-gray.svg?logo=mozilla&labelColor=28733f)](https://opensource.org/licenses/MPL-2.0) [![Codeberg](https://img.shields.io/badge/Codeberg-Main%20Repository-white?logo=codeberg)](https://codeberg.org/project-roadwork/light-reflector.git) [![GitHub](https://img.shields.io/badge/GitHub-Mirror/Backup%20Repository-darkgrey?logo=github)](https://github.com/project-roadwork/light-reflector.git) [![Documentation](https://img.shields.io/static/v1?label=&message=Documentation&color=informational)](./docs/standalone)

> [!IMPORTANT]
> **Use the [main repository in Codeberg](https://codeberg.org/project-roadwork/light-reflector.git) for issues, pull requests, and contributions.**
> **The [GitHub repository](https://github.com/project-roadwork/light-reflector) is a *read-only* mirror, and pull requests are not supported.**

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
* [ECS](https://en.wikipedia.org/wiki/Entity_component_system) architecture via [Jecs](https://github.com/Ukendio/jecs.git)

***[Showcase (View on YouTube) (Outdated) ➚](https://www.youtube.com/watch?v=YK-_NzeLqjI)***

## Installation
You may get the `.rbxm` file directly from [Codeberg Releases](https://codeberg.org/project-roadwork/light-reflector/releases), or [install via Wally or Pesde](./docs/standalone/002_installation.md).

For more information, *read the [installation guide](./docs/standalone/002_installation.md).*

## Getting Started

After installation, follow the usage guide in the [documentation](./docs/standalone/001_index.md) or check the accompanying examples in [./examples](./examples).

### Additional Support
Should you need additional support, *you may join my [Discord server](https://discord.gg/sd4XfAqNF9) and create a support post in the forum channel `#oss-support`.*

## Contributing
*By contributing to this project, you agree that your contributions may be used under the project's current or future open-source/open-content licenses such as Apache-2.0.*

**View the reason why this clause exists in [./CONTRIBUTING.md](CONTRIBUTING.md)**

## License
**License: [Mozilla Public License 2.0](https://mozilla.org/MPL/2.0/) (MPL-2.0)** 

<details>
  <summary>MPL 2.0 summary (not legal advice)</summary>

> [!NOTE]
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
> * Any files originally from MPL that you modify must remain licensed under MPL
> * You must make the source code of MPL-licensed files publicly available
> * MPL-covered code must remain in separate files
> 
> **In short:** You can use MPL code in closed-source and/or commercial projects; however, any changes to MPL-covered files must stay open under MPL.
> **Compared to GPL/GNU licenses:**
> * **GPL:** May require the entire project (like games) to be fully open-sourced under GPL if GPL code is included
> * **LGPL:** Allows use in proprietary projects, but requires that users can modify and swap out LGPL-covered code and still run the project with it, which is not very feasible with games and closed-source binary platforms such as ROBLOX. Additionally, this license allows users to reverse engineer entire projects
> * **MPL:** Only requires open-sourcing the specific modified files

### License Comparison (not legal advice)

| Feature / License        | Expat (aka "MIT")    | Apache 2.0 | MPL 2.0       | GPL / AGPL v3               |
| ------------------------ | ------ | ---------- | ------------- | ------------------------ |
| **Permissive**           | ✅      | ✅          | ℹ️ Partial    | ❌                        |
| **Patent Clause**         | ❌      | ✅          | ✅             | ✅                        |
| **Proprietary Use OK**   | ✅      | ✅          | ✅¹           | ❌  (Must release whole source)                       |
| **Roblox Asset Usage**   | ✅      | ✅          | ℹ️ Depends; must share any changes    | ❌ May violate terms      |

* ¹ Proprietary use in MPL is permitted (allowed) as long as the MPL-covered files remain open souce.

</details>

## Attribution
### Vendored Packages
* *[ObjectPool](https://github.com/ntqltx/ObjectPool) 0.1*
* *[Debugger](https://github.com/axiom-co/debugger) 1.0.3*
* *[Jecs](https://github.com/Ukendio/jecs) 0.11.0*
