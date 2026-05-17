--!strict
--!native
-- USAGE: lightreflector/client/pool.luau
-- ObjectPool module for Light Reflector

--[[
	ObjectPool
	Derived from: https://github.com/notqaltx/ObjectPool.git
	Original Notice: MIT License (https://opensource.org/licenses/MIT), Copyright (c) 2024 qaltx

	 Used in Project Roadwork - Light Reflector
 	 Overall project licensed under Mozilla Public License 2.0 (https://mozilla.org/MPL/2.0/)

   SPDX-FileCopyrightText: 2025-2026 Illinois_Roadbuff (Rogue Jr) <illinois_roadbuff@proton.me>
   SPDX-FileCopyrightText: 2025-2026 Project Roadwork and Contributors
   SPDX-FileCopyrightText: 2024 qaltx

   SPDX-License-Identifier: MIT
]]

--[[
	# ObjectPool Module

	Overview:
	    The `ObjectPool` module provides a great mechanism for managing objects efficiently, without FPS drops.
	    It allows objects to be reused rather than recreated, optimizing performance and resource usage.

	Usage:
	    1. Initialization:
	       - Create an instance of `ObjectPool` using `ObjectPool.new()` with specified object template, creation, and reset functions.
	       The `create` function should create new objects based on the specified template.
	       The `reset` function should reset the object's state to be ready for reuse.

	    2. Object Retrieval:
	       - Retrieve objects from the pool using `:GetObject()` method.
	       New objects are created, if the pool is empty up to the maximum pool size limit.

	    3. Object Return:
	       - Return objects to the pool after use with `:ReturnObject(obj)`.
	       Objects are reset and made available for reuse.

	Example:
	```lua
    local ObjectPool = require(script.ObjectPool)

    -- Define object creation and reset functions
    local function createObject(template: Model)
        local newObj = template:Clone()
        return newObj
    end
    local function resetObject(obj)
        obj.Position = Vector3.new(0, 0, 0)
        obj.Parent = nil
    end

    local objectTemplate = Instance.new("Part")
    local minSize, maxSize = 10, 50
    local pool = ObjectPool.new(objectTemplate, createObject, resetObject, minSize, maxSize)

    -- Get an object from a pool
    -- And then return it to the pool
    local obj1 = pool:GetObject()
    wait(1)
    pool:ReturnObject(obj1)

    local obj2 = pool:GetObject()
    wait(1)
    pool:ReturnObject(obj2)
	```

	GitHub: https://github.com/notqaltx/ObjectPool.git
	Roblox DevForum: https://devforum.roblox.com/t/objectpool-module-for-cloning-objects-without-lags/3059330
	Creator's YouTube: https://youtube.com/@qaltx

	-- Programmed by notqaltx (@qaltx)
]]

local ObjectPool = {}
ObjectPool.__index = ObjectPool

local leakLogged: boolean = false

export type Object = Instance
export type Pool<T> = {
	Objects: {T},
	ActiveObjects: {[T]: boolean},
	HierarchicalPools: { [T]: Pool<T> },

	ObjectTemplate: T,
	CreateObject: (T) -> T,
	ResetObject: (T) -> (),

	MinSize: number,
	MaxSize: number,

	UsageMetrics: UsageMetrics,
	Logger: any,
	Mutex: any,

	ObjectTaken: any,
	ObjectReturned: any,

	GetObject: (Pool<T>) -> T?,
	ReturnObject: (Pool<T>, T) -> (boolean, string?),

	Prewarm: (Pool<T>, number) -> (),
	CreateLog: (Pool<T>, string, string) -> (),
}



export type Mutex = {
	locked: boolean,
	lockingThread: thread?,
	lockCount: number,
	lock: (self: Mutex, timeout: number?) -> (),
	unlock: (self: Mutex) -> (),
	isLocked: (self: Mutex) -> boolean,
	new: () -> Mutex,
}

type ObjectPoolClass = typeof(ObjectPool)

type ObjectPoolInstance = Pool<any> & {
	__index: ObjectPoolClass,
}

type UsageMetrics = {
	ActiveCount: number,
	AvailableCount: number,
	PeakActive: number,
}
const debugger: typeof(require("../shared/debugger")) = require("../shared/debugger")

const mutex = require("./mutex")

--- Creates a new object pool.
---@param objectTemplate Object  The template object used to create new objects in the pool.
---@param createObject function(Object):Object  Function to create a new object based on the template.
---@param resetObject function(Object):()  Function to reset an object before returning it to the pool.
---@param minSize number  Minimum initial size of the pool (optional, default 10).
---@param maxSize number  Maximum size limit of the pool (optional, default 50).
---@return Pool New instance of ObjectPool.
function ObjectPool.new(objectTemplate: Object, createObject: (Object) -> Object, resetObject: (Object) -> (), minSize: number, maxSize: number): Pool<any>
	local self = setmetatable({
		Objects = {} :: {Object},
		ActiveObjects = {} :: {[Object]: boolean},
		HierarchicalPools = {} :: {[Object]: Pool<any>},

		ObjectTemplate = objectTemplate,
		CreateObject = createObject,
		ResetObject = resetObject,

		Mutex = mutex.new(),

		MinSize = minSize or 10,
		MaxSize = maxSize or 50,
		UsageMetrics = {
			ActiveCount = 0,
			AvailableCount = 0,
			PeakActive = 0,
		} :: UsageMetrics,
	}, ObjectPool) :: Pool<any> -- these type errors are making me go insane :D

	self.Objects = {}
	self.ActiveObjects = {}
	self.HierarchicalPools = {}

	self.ObjectTemplate = objectTemplate
	self.CreateObject = createObject
	self.ResetObject = resetObject

	self.Mutex = mutex.new()

	self.MinSize = minSize or 10
	self.MaxSize = maxSize or 50
	self.UsageMetrics = {ActiveCount = 0, AvailableCount = 0, PeakActive = 0} :: UsageMetrics

	self:Prewarm(self.MinSize)
	return setmetatable(self, {
		__index = ObjectPool,
		__call = function(tbl)
			return tbl:GetObject()
		end,
	}) :: any
end

--- Creates a log entry with a specified level and message.
---@param level string  Logging level (INFO, WARNING, ERROR).
---@param message string  Message to log.
--function ObjectPool:CreateLog(level: string, message: string)
--	self.Logger:log(level, message)
--end

--- Prewarms the object pool with a specified number of objects.
---@param count number  Number of objects to prewarm the pool with.
function ObjectPool:Prewarm(count: number): ()
	--	debugger.print("Info", "Prewarming the pool with " .. count .. " objects.")
	for i: number = 1, count do
		const obj: Object = self.CreateObject(self.ObjectTemplate)
		table.insert(self.Objects, obj)
	end
	self.UsageMetrics.AvailableCount = #self.Objects
	--	debugger.print("Info", "Prewarming completed.")
end

local Returned: number = 0
--- Retrieves an object from the pool, creating a new one if necessary.
---@return Object  Object retrieved from the pool.
function ObjectPool:GetObject(): Object
	self.Mutex:lock()
	local obj: Object?
	if #self.Objects > 0 then
		const removed: Object? | any? = table.remove(self.Objects)

		if removed == nil then
			warn("ObjectPool: Object is nil")
		else
			obj = removed :: Object

			const UsageMetrics: UsageMetrics = self.UsageMetrics

			UsageMetrics.AvailableCount -= 1
		end


	else
		if self.UsageMetrics.ActiveCount < self.MaxSize then
			obj = self.CreateObject(self.ObjectTemplate)
			--		debugger.print("Info", "Created new object.")
		else
			debugger.fatal("Fatal",
				"Max pool size reached! Unable to create new object."
			);
			self.Mutex:unlock()
			error("ObjectPool: Max pool size reached!")
		end

		if self.UsageMetrics.ActiveCount > 350 and leakLogged == false then
			leakLogged = true
			--debugger.warn("Warning",
			--	"[POOL] Object pool exceeded 350 in active count."
		--	);
		end
	end
	self.ActiveObjects[obj] = true
	self.UsageMetrics.ActiveCount += 1

	self.UsageMetrics.PeakActive = math.max(self.UsageMetrics.PeakActive, self.UsageMetrics.ActiveCount)
	--debugger.print("Info",
	--	"Object retrieved from pool. Active count: " .. self.UsageMetrics.ActiveCount
	--);
--	if self.ObjectTaken then
		--	self.ObjectTaken:Fire(obj)
		--	end
		--
	self.Mutex:unlock()

	return obj :: Object
end

-- Returns an object to the pool, resetting it for future use.
--@param obj Object  Object to return to the pool.
function ObjectPool:ReturnObject(obj: Object): (boolean, string?)

	if obj.Parent ~= nil then
		obj.Parent = nil
	end

	self.Mutex:lock()
	const index: boolean? = self.ActiveObjects[obj]
	if index then
		self.ActiveObjects[obj] = nil

		const UsageMetrics: UsageMetrics = self.UsageMetrics

		UsageMetrics.ActiveCount -= 1
		self.ResetObject(obj)
		Returned += 1

		if #self.Objects < self.MaxSize then
			table.insert(self.Objects, obj)
			UsageMetrics.AvailableCount += 1
		else
			obj:Destroy()
			debugger.warn("Warning",
				"Object destroyed due to exceeding max pool size."
			);
		end
		--		debugger.print("Info",
		--			"Object returned to pool. Active count: " .. self.UsageMetrics.ActiveCount
		--		);
	--	if self.ObjectReturned then
			--	self.ObjectReturned:Fire(obj)
			--	end
			--
		if self.HierarchicalPools[obj] then
			local childPool: Pool<any> = self.HierarchicalPools[obj]
			for child: Object, boolean: boolean in childPool.ActiveObjects do
				childPool:ReturnObject(child)
			end
		end
		self.Mutex:unlock()
		return true, nil
	else
		debugger.warn("Warning",
			"Attempted to return an object that was not in the active list."
		);
		return false, "Attempted to return an object that was not in the active list"
	end

end

export type ObjectPool = typeof(ObjectPool)

return table.freeze(ObjectPool) :: ObjectPool
