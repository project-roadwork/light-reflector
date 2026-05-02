--!native
--!strict
-- USAGE: lightreflector.luau
-- Init module for Light Reflector.

--[[
    SPDX-FileCopyrightText:   Copyright 2025-2026 Illinois_Roadbuff (Rogue Jr) <illinois_roadbuff@proton.me>
	SPDX-FileCopyrightText:   Copyright 2025-2026 Project Roadwork and Contributors

	SPDX-License-Identifier:   MPL-2.0

	This Source Code Form is subject to the terms of the Mozilla Public
	License, v. 2.0. If a copy of the MPL was not distributed with this
	file, You can obtain one at https://mozilla.org/MPL/2.0/.

	VIEW README FILE FOR MORE INFORMATION LOCATED AT:
		LUAU: lightreflector/shared/readme.luau
		GIT: ./README.md

	GIT REPOSITORIES:
		Codeberg / Forgejo (main): https://codeberg.org/project-roadwork/light-reflector.git
		GitHub (mirror): https://github.com/project-roadwork/light-reflector.git
]]

-- IMPORTANT: Services
const RunService: RunService = game:GetService("RunService")

-- IMPORTANT: Types, Debugger and Setup
const types = require("@self/shared/types")
const debugger: types.Debugger = require("@self/shared/debugger")
const logs: types.DebuggerLogs  = require("@self/shared/logs")
const version: string = require("@self/shared/version")._VERSION

debugger.set(`Light Reflector {version}`, logs.Ids, logs.URL) -- URL will be omitted or left out if not in Studio

-- IMPORTANT: RunContext Safety Net
debugger.assert(RunService:IsClient(), "RunContext", "Init module can only be run from the client.")

-- IMPORTANT: Initialize Modules
const config: types.Configuration = require("@self/shared/config")
const register: types.Register = require("@self/client/register")
const detect: types.Detect = require("@self/client/detect")
const render: types.Render = require("@self/client/render")

-- Local Variables
local isRunning: boolean = false
local hasInit: boolean = false

-- Functions

const function init(): ()
	if hasInit then
		return
	end

	debugger.print("Info", "[INIT] 🟡 Initializing Light Reflector...")

	register.init()
	detect.init()
	render.init()

	hasInit = true

	debugger.print("Info", "[INIT] 🟢 Light Reflector Initialized!")
end
--[=[
	Public: Starts the module

	```lua
	LightReflector.Start()
	```

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function start() : ()
	debug.profilebegin(`Start Light Reflector {version}`)

	debugger.assert(not isRunning, "AlreadyStarting")

	isRunning = true

	debugger.print("Info","[INIT] 🟡 Starting...")

	init() -- Backwards compatibility

	config.lock()

	register.start()
	detect.start()
	render.start()
	-- ^ two separate loops since both are in different frequencies
	debugger.print("Info","[INIT] 🟢 Successfully started!")

	debug.profileend()
end

--[=[
	Public: Cleans up the module

	```lua
	LightReflector.Cleanup()
	```

	[Git Repository](https://codeberg.org/project-roadwork/light-reflector.git)
]=]
const function reset(): ()
	debugger.assert(isRunning, "Warning", "[INIT] Cleanup called before Start().")

	debugger.print("Info","[INIT] Cleaning up!")

	register.clearConnections()

	detect.safeCancelThread()
	render.safeCancelThread()

	register.reset()

	detect.reset()

	config.unlock()

	isRunning = false
end

-- Return public variables and API
return table.freeze({
	init = init,
	start = start,
	reset = reset,
	config = config,
	register = register,
})
