--!strict
--!native
-- USAGE: lightreflector/client/mutex.luau
-- Mutex module for the pool module (could be used in other modules too)

--[[
	ObjectPool - Mutex module
	Derived from: https://github.com/notqaltx/ObjectPool.git
	Original Notice: MIT License (https://opensource.org/licenses/MIT), Copyright (c) 2024 qaltx

	 Used in Project Roadwork - Light Reflector
 	 Overall project licensed under Mozilla Public License 2.0 (https://mozilla.org/MPL/2.0/)

   SPDX-FileCopyrightText: 2025-2026 Illinois_Roadbuff <illinois_roadbuff@proton.me>
   SPDX-FileCopyrightText: 2025-2026 Project Roadwork and Contributors
   SPDX-FileCopyrightText: 2024 qaltx

   SPDX-License-Identifier: MIT

]]

-- IMPORTANT: Services
const RunService: RunService = game:GetService("RunService")

-- IMPORTANT: Modules
const debugger: typeof(require("../shared/debugger")) = require("../shared/debugger")

-- Types
export type Mutex = {
	locked: boolean,
	lockingThread: thread?,
	lockCount: number,
	lock: (self: Mutex, timeout: number?) -> (),
	unlock: (self: Mutex) -> (),
	isLocked: (self: Mutex) -> boolean,
	new: () -> Mutex,
}

type MutexClass = {
	__index: MutexClass,
	new: () -> Mutex,


	lock: (self: Mutex, timeout: number?) -> (),
	unlock: (self: Mutex) -> (),
	isLocked: (self: Mutex) -> boolean,
}

-- Variables and Class
local Mutex: MutexClass = {} :: MutexClass
Mutex.__index = Mutex

--[=[
	Public: Constructor for creating a new mutex object

	[Git Repository](https://github.com/notqaltx/ObjectPool.git)
]=]
function Mutex.new(): setmetatable<{}, MutexClass>
	const self: setmetatable<{}, MutexClass> = setmetatable({
		locked = false,
		lockingThread = nil,
		lockCount = 0,
	}, Mutex)
	return self
end

--[=[
	Public: Locks the mutex, blocking if it is already locked

	[Git Repository](https://github.com/notqaltx/ObjectPool.git)
]=]
function Mutex:lock(timeout: number?): ()
	const startTime: number = tick()
	const currentThread: thread? = coroutine.running()

	while self.locked and self.lockingThread ~= currentThread do
		if timeout and (tick() - startTime) >= timeout then
			debugger.fatal("Fatal", "Mutex lock timeout")
		end
		RunService.Heartbeat:Wait()
	end

	self.locked = true
	self.lockingThread = currentThread
	self.lockCount += 1
end

--[=[
	Public: Unlocks the mutex

	[Git Repository](https://github.com/notqaltx/ObjectPool.git)
]=]
function Mutex:unlock(): ()
	const currentThread: thread? = coroutine.running()
	if not self.locked or self.lockingThread ~= currentThread then
		debugger.fatal("Fatal","Mutex unlock attempt by non-locking thread or when mutex is not locked")
	end

	self.lockCount -= 1
	if self.lockCount == 0 then
		self.locked = false
		self.lockingThread = nil
	end
end

--[=[
	Public: Checks if the mutex is locked

	[Git Repository](https://github.com/notqaltx/ObjectPool.git)
]=]
function Mutex:isLocked(): boolean
	return self.locked
end

-- Return public API
return table.freeze(Mutex) :: Mutex
