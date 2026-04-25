## Init

**First, `require` Light Reflector by creating a `LocalScript` in a client service such as `StarterPlayerScripts`.**

Your script should look similar to the accompanying sample below:
```luau
-- Light Reflector Handler
-- handler.client.luau

local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local lightreflector = require(ReplicatedStorage.Packages.lightreflector)
--                              ^ Set this to where you placed the module
```

**Second, init the module.**

```luau
lightreflector.init()
```

**Third, configure the settings during runtime by calling `lightreflector.config.applyOverrides()`.**

> [!NOTE]
> You can also modify `BASE_CONFIG` in the `config` module before runtime; however, it is not recommended since you would have to change every modified value when you upgrade Light Reflector to a newer version.

```luau
lightreflector.config.applyOverrides({
    -- This is just an example! You may want to configure more values than this.
    -- See the config module for reference
	SignConfig = {
		signsFolders = {workspace.Signs}
	}
})
```

**Fourth, start the module.**

```luau
lightreflector.start()
```

***A completed sample can be found at `root/examples/vehicle-reflector-handler.client.luau`!***
