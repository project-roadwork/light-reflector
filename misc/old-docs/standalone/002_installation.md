# Installation

## Using Direct `.rbxm` Download

### Installing via Codeberg Releases

Head over to releases and download the `.rbxm` file from the latest version on [Codeberg](https://codeberg.org/project-roadwork/light-reflector/releases). 
**It's recommended to place the module in `ReplicatedStorage` under a folder named `Packages`; however, you may place it wherever you'd like.** 

### Inserting into Roblox Studio

Right click `ReplicatedStorage` in the explorer, then press `Insert Roblox model` and insert the `.rbxm` file you downloaded from Codeberg into Roblox Studio.

## Using Package Managers

### Installing via `pesde`

> [!WARNING]
> **The package in `pesde` is outdated since [I was not able to publish newer versions using the new `const` keyword](https://github.com/pesde-pkg/pesde/issues/71), causing the package manager to believe that it includes invalid `Luau` files.**

Type this into your terminal:
```bash
pesde add project_roadwork/light_reflector@version
pesde install
```
Replace version with the current version of the package.

### Installing via `wally`

> [!WARNING]
> **The package in `wally` may not be structured properly. Use at your own risk.**

Add this to your `wally.toml` file:

```toml
[dependencies]
lightreflector = "illinois-roadbuff/light-reflector@version"
```
Replace version with the current version of the package.

Then, type this into your terminal and press enter:
```bash
wally install
```

## Next, learn about initializing and starting the module!

---

[Previous Page](./001_index.md) | [Next Page](./003_init.md)
