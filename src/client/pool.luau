--!strict
--!native
-- USAGE: lightreflector/client/pool.luau
-- FastPool module for Light Reflector

--[[

	FastPool
	Codeberg: https://codeberg.org/project-roadwork/FastPool.git
	GitHub: https://github.com/project-roadwork/FastPool.git

	Derived from: ObjectPool by qaltx (under the MIT License)
	ObjectPool: https://github.com/notqaltx/ObjectPool.git

  		SPDX-FileCopyrightText: 2026 Illinois_Roadbuff (Rogue Jr) <illinois_roadbuff@proton.me>
   		SPDX-FileCopyrightText: 2026 Project Roadwork and Contributors
   		SPDX-FileCopyrightText: 2024 qaltx

   		SPDX-License-Identifier: MIT OR Apache-2.0 WITH LLVM-exception

   	Modifications:
   		- Replaced class/metatable-based pools with closure-based pools
   		- Removed UsageMetrics table storage; metrics are stored as individual numbers
   		  and are only assembled into a table when requested
   		- Added lifecycle functions: Destroy(), Reset(), and Clear()
   		- Added utility functions: TogglePooling() and GetMetrics()
		- Renamed: ObjectPool.new() -> FastPool()
		- Renamed: Pool:GetObject() -> Pool.Get()
		- Renamed: Pool:ReturnObject() -> Pool.Return()
		- Tracks number of reused objects
		- Removed ActiveObjects table in order to reduce memory usage with many objects
		- Removed HierarchicalPools table
		- No longer traditional object-oriented programming (OOP)
		- Removed mutex
		- No longer Instance-centric
		- New destroy() argument
		- Removed debugger and signal module

]]

const SOURCE: string = "[FastPool]"
const __VERSION: string = "1.1.0"
const _DESTROY_ERROR: string  = `{SOURCE} Attempted to use a destroyed pool.`

--[=[
	Public: Creates a new object pool.

	@param template Object The template object used to create new objects in the pool.
	@param create function(Object):Object  Function to create a new object based on the template.
	@param reset function(Object):()  Function to reset an object before returning it to the pool.
	@param destroy function(Object):()  Function to destroy an object when it is removed from the pool.
	@param minSize number Minimum initial size of the pool (optional, default 10).
	@param maxSize number Maximum size limit of the pool (optional, default 50).
	@return Pool New object pool
]=]
@checked
const function FastPool<T>(
	template: T,
	create: (T) -> T,
	reset: (T) -> (),
	destroy: (T) -> (),
	minSize: number?,
	maxSize: number?
): Pool<T>

	const minimumSize: number = minSize or 10
	const maximumSize: number = maxSize or 50

	local poolingEnabled: boolean = true
	local destroyed: boolean = false

	const objects: {T} = table.create(minimumSize)

	-- Not using a table for usage metrics for performance reasons
	-- However, the table will be created in GetMetrics()
	local activeCount: number = 0
	local availableCount: number = minimumSize
	local peakActive: number = 0
	local returnedCount: number = 0
	local recycledCount: number = 0
	local totalCreatedCount: number = minimumSize
	local getCalls: number = 0

	for i: number = 1, minimumSize do
		objects[i] = create(template)
	end

	-- Private: Destroys all available objects in the pool.
	-- @private
	const function _DestroyAvailableObjects(): ()
		for i: number = 1, availableCount do
			destroy(objects[i] :: T)
			objects[i] = nil
		end

		availableCount = 0
	end

	-- Public: Toggles pooling functionality
	const function TogglePooling(enabled: boolean): ()
		if destroyed then
			error(_DESTROY_ERROR, 2)
		end

		poolingEnabled = enabled
	end

	-- Public: Returns an object from the pool if one is available, otherwise creates a new object.
	const function Get(): T
		if destroyed then
			error(_DESTROY_ERROR, 2)
		end

		getCalls += 1

		if not poolingEnabled then
			totalCreatedCount += 1
			activeCount += 1

			if activeCount > peakActive then
				peakActive = activeCount
			end

			return create(template)
		end

		local object: T

		if availableCount > 0 then
			object = objects[availableCount] :: T
			objects[availableCount] = nil
			availableCount -= 1
			recycledCount += 1
		else
			object = create(template)
			totalCreatedCount += 1
		end

		activeCount += 1

		if activeCount > peakActive then
			peakActive = activeCount
		end

		return object
	end

	-- Public: Returns an object to the pool.
	const function Return(object: T): ()
		if destroyed then
			error(_DESTROY_ERROR, 2)
		end

		if not poolingEnabled then
			destroy(object)
			activeCount -= 1
			return
		end

		activeCount -= 1
		returnedCount += 1

		reset(object)

		if availableCount < maximumSize then
			availableCount += 1
			objects[availableCount] = object
		else
			destroy(object)
		end
	end

	-- Public: Prewarms the pool with the given number of objects.
	const function Prewarm(count: number): ()
		if destroyed then
			error(_DESTROY_ERROR, 2)
		end

		if not poolingEnabled then
			return
		end

		const remaining: number = maximumSize - availableCount

		if remaining <= 0 then
			return
		end

		count = math.max(0, math.min(count, remaining))

		for i: number = 1, count do
			availableCount += 1
			objects[availableCount] = create(template)
			totalCreatedCount += 1
		end
	end

	-- Public: Removes every pooled object and resets metrics; however, pool remains usable. Note that active count does not change.
	const function Clear(): ()
		if destroyed then
			error(_DESTROY_ERROR, 2)
		end

		if activeCount > 0 then
			warn(`{SOURCE} Clearing pool with {activeCount} objects still in use. It is the caller's responsibility to clear the rest of the objects.`)
		end

		_DestroyAvailableObjects()

		peakActive = 0
		returnedCount = 0
		recycledCount = 0
		totalCreatedCount = 0
		getCalls = 0
	end

	-- Public: Restores the pool to its initial state and recreates the pool.
	const function Reset(): ()
		if destroyed then
			error(_DESTROY_ERROR, 2)
		end

		if activeCount > 0 then
			error(`{SOURCE} Attempted to reset pool with {activeCount} objects still in use. Cannot reset pool with active objects.`)
		end

		Clear()

		for i: number = 1, minimumSize do
			objects[i] = create(template)
		end

		availableCount = minimumSize
		totalCreatedCount = minimumSize
	end

	-- Public: Permanently destroys the pool; further uses throws an error.
	const function Destroy(): ()
		if destroyed then
			return
		end

		if activeCount > 0 then
			warn(`{SOURCE} Destroying pool with {activeCount} objects still in use. It is the caller's responsibility to destroy the rest of the objects.`)
		end

		destroyed = true
		_DestroyAvailableObjects()
	end

	-- Public: Gets metrics of the pool.
	const function GetMetrics(): UsageMetrics
		if destroyed then
			error(_DESTROY_ERROR, 2)
		end

		return {
			ActiveCount = activeCount,
			AvailableCount = availableCount,
			PeakActive = peakActive,
			ReturnedCount = returnedCount,
			RecycledCount = recycledCount,
			TotalCreatedCount = totalCreatedCount,
			GetCalls = getCalls,
			Destroyed = destroyed
		}
	end

	return table.freeze({
		__VERSION = __VERSION,
		Get = Get,
		Return = Return,
		Prewarm = Prewarm,
		Clear = Clear,
		Reset = Reset,
		Destroy = Destroy,
		GetMetrics = GetMetrics,
		TogglePooling = TogglePooling,
	})
end

-- Types

export type UsageMetrics = {
	ActiveCount: number,
	AvailableCount: number,
	PeakActive: number,
	ReturnedCount: number,
	RecycledCount: number,
	TotalCreatedCount: number,
	GetCalls: number,
	Destroyed: boolean
}

export type Pool<T> = {
	read __VERSION: string,
	read Get: () -> T,
	read Return: (T) -> (),
	read Prewarm: (number) -> (),
	read Clear: () -> (),
	read Reset: () -> (),
	read Destroy: () -> (),
	read GetMetrics: () -> UsageMetrics,
	read TogglePooling: (boolean) -> ()
}

export type FastPool = <T>(
    template: T,
    create: (T) -> T,
    reset: (T) -> (),
    destroy: (T) -> (),
    minSize: number?,
    maxSize: number?
) -> Pool<T>

return FastPool
