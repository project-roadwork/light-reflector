# Light Reflector 

 **A vehicle-based light reflector system that reflects `Decals` and `BasePart` reflectors at long distances on roads.**

[![License: MPL 2.0](https://img.shields.io/badge/MPL_2.0-License-gray.svg?logo=mozilla&labelColor=28733f)](https://opensource.org/licenses/MPL-2.0) [![Codeberg](https://img.shields.io/badge/Codeberg-Main%20Repository-white?logo=codeberg)](https://codeberg.org/project-roadwork/light-reflector.git) [![GitHub](https://img.shields.io/badge/GitHub-Mirror/Backup%20Repository-darkgrey?logo=github)](https://github.com/project-roadwork/light-reflector.git) 

> [!IMPORTANT]
> ****Please use the [main repository](https://codeberg.org/project-roadwork/light-reflector.git) especially with contributions or commits!*** *Additionally, please **DO NOT** make any changes in the mirrored repository as it cannot be pulled into the main repo.**
> 
> **The main repository is in Codeberg; however, I provided a *push* mirror on GitHub (pulls are not supported).**

## Features
1. Adaptive waiting on performance-critical functions
2. Sign and reflector support
2. Distance fall-off
3. Angle-based brightness
4. Multi-vehicle support
5. Non-tweened fading/transitions for gradual brightness
6. Option to use `Tags` with `CollectionService`
7. Uses Entity Component System via [JECS](https://github.com/Ukendio/jecs.git)

[Showcase (View on YouTube) (Outdated)](https://www.youtube.com/watch?v=YK-_NzeLqjI)

## Contributing
**This section exists due to the file-level copyleft nature of the Mozilla Public License 2.0.**

*By contributing to this project, you agree that your contributions may be redistributed and relicensed under other open-source and/or open-content licenses.*

**View the reason why this clause exists in [./CONTRIBUTING.md](CONTRIBUTING.md)**

## License
**License: [Mozilla Public License 2.0](https://mozilla.org/MPL/2.0/)** 

<details>
  <summary>MPL 2.0 summary (not legal advice)</summary>

> [!NOTE]
> ### Mozilla Public License 2.0 Summary
> **Warning: This summary does NOT act as a subsitute for the entire legal text. This is also not legal advice**
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

| Feature / License        | Expact (aka "MIT")    | Apache 2.0 | MPL 2.0       | GPL / AGPL v3               |
| ------------------------ | ------ | ---------- | ------------- | ------------------------ |
| **Permissive**           | ✅      | ✅          | ℹ️ Partial    | ❌                        |
| **Patent Clause**         | ❌      | ✅          | ✅             | ✅                        |
| **Proprietary Use OK**   | ✅      | ✅          | ✅¹           | ❌  (Must release whole source)                       |
| **Roblox Asset Usage**   | ✅      | ✅          | ℹ️ Depends; must share any changes    | ❌ May violate terms      |

* ¹ Proprietary use in MPL is permitted (allowed) as long as the MPL-covered files remain open souce.

</details>
