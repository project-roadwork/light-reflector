## Vehicles

### Helper Functions

***Before we go any further, you would first want to add helper functions.***

*1. Add a function determining the light strength of the provided vehicle:*
```luau
-- Light Reflector Handler
-- client.handler.luau (continued)

-- Assuming this is an A-Chassis vehicle
local function determineIntensity(vehicle: Model)
    -- This is just an example and every headlight system will be different.
    local values = vehicle.DriveSeat:FindFirstChild("Values")
    local intensity = 1

    -- If the high beams are enabled, then the intensity will be greater.
    if values and values.HighBeam.Value == true then
        intensity = 1.5
    end

    -- continue on....

    return intensity
end
```

*2. Add a function that returns the `ValueBase` that determines if any headlight is on in the provided vehicle:*
```luau
-- Light Reflector Handler
-- client.handler.luau (continued)

-- Assuming this is an A-Chassis vehicle
local function CheckForRegLightValue(vehicle: Model)
    -- This is just an example and every headlight system will be different.
    local values = vehicle.DriveSeat:FindFirstChild("Values")

    -- Just check if there is a headlight value
    if values and values:FindFirstChild("LowBeam") then
        return values.LowBeam
    end

    -- continue on....

    -- Use `true` as a fallback if you cannot return any values. 
    -- Note that this will enable the source for the respective vehicle regardless if the headlighs are on or not.
    return true
end
```

*3. Add a function that determines if a provided model is actually a vehicle:*
```luau
local function isAVehicle(model: Model)

    -- First check if the model is actually a model
    if not model:IsA("Model") then
        -- Not a model, so not a vehicle either!
        return false
    end     

    -- Add a variable to avoid repetition
    local VehicleSeat = vehicle:FindFirstChildOfClass("VehicleSeat")

 -- Something that is `nil` means that it does NOT exist
   if VehicleSeat == nil then
       -- Use a different method
       VehicleSeat = vehicle:WaitForChild("DriveSeat",5) -- Assuming A-Chassis vehicle
       -- Wait for 5 seconds in case the seat may pop up
   else 
        -- Since a VehicleSeat exists, it is inferred that the model IS a vehicle!
        return true
   end

 -- Check if the VehicleSeat exists again from the second method
   if VehicleSeat then
       -- The VehicleSeat exists! It is a vehicle!
       return true
   end

   -- This model failed the checks and is NOT a vehicle
   return false
end
```

### Registering/Unregistering

**Now that you have your helper functions, let's index the vehicles into Light Reflector!**

Your script should look similar to the accompanying sample below:
```luau
local vehicles: Folder = workspace.Vehicle

-- Find cars that are already existing
for index: number, vehicle: Instance in vehicles:GetChildren() do
    if isAVehicle(vehicle) then
        lightreflector.register.addVehicle(vehicle, CheckForRegLightValue(vehicle), determineIntensity)
    end
end

-- Find cars that MAY spawn
vehicles.ChildAdded:Connect(function(vehicle)
	task.wait() -- a-chassis init reasons
	if isAVehicle(vehicle) then
		print("Indexed vehicle")
		lightreflector.register.addVehicle(vehicle, CheckForRegLightValue(vehicle), determineIntensity)
	end
end)
```

**Do not stop yet! You must also unregister the vehicles upon deletion**

If you do not unregister the vehicles, *it WILL cause memory leaks and possibly brick the entire system.*

Your script should look similar to the accompanying sample below:
```luau
-- Find cars that are removed
vehicles.ChildRemoved:Connect(function(vehicle)
	if isAVehicle(vehicle) then
		print("Removing car")
		lightreflector.register.removeVehicle(vehicle)
	end
end)
```

### Next, learn how to tag reflectors and signs, as well as how to register or unregister them!

***A completed sample can be found at `root/examples/vehicle-reflector-handler.client.luau`!***
