## Non-Tags

### Overrides

In case that tags are not to your liking, you can still automatically register/unregister signs and reflectors through config overrides.

```luau
-- Light Reflector Handler
-- handler.client.luau (continued)

local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local lightreflector = require(ReplicatedStorage.Packages.lightreflector)
--                              ^ Set this to where you placed the module
local signsFolders = {workspace.Signs, workspace.NewSigns} -- Set this to your liking
local roadsFolders = {workspace.Roads, workspace.OldRoads} -- Set this to your liking

lightreflector.config.applyOverrides({
    -- This is just an example! You may want to configure more values than this.
    -- See the config module for reference
	SignConfig = {
	  isTagsEnabled = false,
		signsFolders = signsFolders.
		-- You add a function here that determines if a part is a sign
		isSign = function(part: BasePart)
		    if part.Name == "Sign" then
						return true
				else 
				    return false
				end
		end
	},
	
	ReflectorConfig = {
	  isTagsEnabled = false,
		reflectorsFolders = roadsFolders,
		-- You add a function here that determines if a part is a reflector
		isReflector = function(part: BasePart)
		    if part.Name == "Reflector" then
						return true
				else 
				    return false
				end
		end
	}
})
```

### External

You also have the ability to manually register/unregister reflectors and signs through public APIs; however, *it is only provided as needed and not recommended.*

```luau
-- Light Reflector Handler
-- handler.client.luau (continued)

local ReplicatedStorage: ReplicatedStorage = game:GetService("ReplicatedStorage")
local lightreflector = require(ReplicatedStorage.Packages.lightreflector)
--                              ^ Set this to where you placed the module
local signsFolders = {workspace.Signs, workspace.NewSigns} -- Set this to your liking
local roadsFolders = {workspace.Roads, workspace.OldRoads} -- Set this to your liking

for index: number, part: Instance in signsFolders:GetDescendants() do
    if part:IsA("BasePart") and part.Name == "Sign" then
        lightreflector.register.addSign(part)
    end
end

for index: number, part: Instance in roadsFolders:GetDescendants() do
    if part:IsA("BasePart") and part.Name == "Reflector" then
        lightreflector.register.addReflector(part)
    end
end
```

### Next, learn about signs in general!
