## Init

**First, `require` Light Reflector by creating a `LocalScript` in a client service such as `StarterPlayerScripts`.**

Your script should look similar to the accompanying sample below:
```luau
-- Light Reflector Handler
-- client.handler.luau

local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local lightreflector = require(ReplicatedStorage.Packages.lightreflector)
--                              ^ Set this to where you placed the module
```

**Second, init the module.**

```luau
lightreflector.init()
```

**Third, configure the settings during runtime by calling `lightreflector.config.applyOverrides()`.**

```luau
lightreflector.config.applyOverrides({
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
