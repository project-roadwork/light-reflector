--!native
--!strict
-- USAGE: lightreflector/client/grid.luau
-- Typed spatial grid for Light Reflector

--[[
    SPDX-FileCopyrightText: 2025-2026 Illinois_Roadbuff <illinois_roadbuff@proton.me>
    SPDX-FileCopyrightText: 2025-2026 Project Roadwork and Contributors

    SPDX-License-Identifier: MPL-2.0

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at https://mozilla.org/MPL/2.0/.

]]

--[[

	NOTE: This is an experimental grid module that includes a large amount of AI-generated
	code from a LLM. There may be unforseen issues with this module. Use at your own risk.

	More information:
	https://codeberg.org/project-roadwork/spatial-grid/src/branch/main/README.md

]]

--[[

	- - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -
	-                                                                             -
	-                 Sparse Uniform Spatial Grid Implementation                  -
	-                                                                             -
	-  A typed, spatial partitioning grid for fast proximity queries, where       -
	-   entities are stored in a uniform grid allowing for lookups of nearby      -
	-   objects without querying the entitre dataset.                             -
	-                                                                             -
	-  Language: Luau                                                             -
    -                                                                             -
    -  Repositories:                                                              -
    -   https://codeberg.org/project-roadwork/spatial-grid (Main)                 -
    -   https://github.com/project-roadwork/spatial-grid (Backup)                 -
    -                                                                             -
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

]]

-- Types

type Key = string | number

export type Grid = {
	CellSize: number,

	Position: {[Key]: Vector3},
	Part: {[Key]: BasePart}?,

	CellCoords: {[Key]: Vector2},
	Cells: {[number]: {[number]: {Key}}},
	Coarse: {[number]: {[number]: {x: number, z: number}}},

	CellIndex: {[Key]: {x: number, z: number, i: number}},
	Dirty: {[Key]: boolean},

	CellCache: {[number]: {Key}?},
	EntityMap: {[Key]: EntityId},

	_ReconciledThisQuery: {[Key]: boolean},
	_QueryLock: boolean,

	_scratchParts: {BasePart},
	_scratchIds: {EntityId},
}

const jecs = require("../shared/jecs")

export type EntityId = number | vector | jecs.Entity

-- Constants
const floor = math.floor
const ceil = math.ceil
const clear = table.clear
const COARSE_FACTOR: number = 4

local function getIdKey(entityId: EntityId): number | string
	if typeof(entityId) == "number" then
		return entityId
	elseif typeof(entityId) == "vector" then
		return entityId.x .. ":" .. entityId.y
	elseif typeof(entityId) == "Vector3" then
		return entityId.X .. ":" .. entityId.Y
	end
	error("Invalid EntityId type: ".. typeof(entityId))
end

-- Public: Create a new grid
const function newGrid(cellSize: number?): Grid
	return {
		CellSize = cellSize or 1900,

		Position = {},
		Part = {},

		CellCoords = {},
		Cells = {},
		Coarse = {},

		CellIndex = {},
		Dirty = {},
		EntityMap = {},

		CellCache = {},

		_ReconciledThisQuery = {},
		_QueryLock = false,

		_scratchParts = {},
		_scratchIds = {},
	}
end
-- Public: Get cell coordinates
const function getCellCoords(grid: Grid, pos: Vector3): (number, number)
	return floor(pos.X / grid.CellSize), floor(pos.Z / grid.CellSize)
end

-- Private: Get the key for the coarse grid
const function _coarseKey(x: number, z: number): number
	return bit32.bxor(x * 73856093, z * 19349663)
end

-- Public: Spawn a new entity into the grid
const function spawn(grid: Grid, entityId: EntityId, pos: Vector3): ()
	local key = getIdKey(entityId)

	if grid.Position[key] then
		return
	end

	-- store original ECS entity
	grid.EntityMap[key] = entityId
	grid.Position[key] = pos

	const x, z = getCellCoords(grid, pos)
	grid.CellCoords[key] = Vector2.new(x, z)

	local column = grid.Cells[x]
	if not column then
		column = {} :: {[number]: {Key}}
		grid.Cells[x] = column
	end
	grid.Cells[x] = column

	local cell = column[z]
	if not cell then
		cell = {}
		column[z] = cell

		const cx = floor(x / COARSE_FACTOR)
		const cz = floor(z / COARSE_FACTOR)
		const ck = _coarseKey(cx, cz)

		local coarse = grid.Coarse[ck]
		if not coarse then
			coarse = {} :: {[number]: {x: number, z: number}}
			grid.Coarse[ck] = coarse
		end
		grid.Coarse[ck] = coarse

		coarse[x * 10000 + z] = { x = x, z = z }
	end

	local idx = #cell + 1
	cell[idx] = key

	grid.CellIndex[key] = {
		x = x,
		z = z,
		i = idx,
	}

	grid.Dirty[key] = false
end
-- Public: Update an entity's position
const function updatePosition(grid: Grid, entityId: EntityId, pos: Vector3): ()
	local key = getIdKey(entityId)

	if not grid.Position[key] then return end
	grid.Position[key] = pos
	grid.Dirty[key] = true
end
-- Private: Remove entity from a cell
const function _removeFromCell(grid: Grid, key: Key, x: number, z: number): ()

	const column = grid.Cells[x]
	if not column then return end

	const cell = column[z]
	if not cell then return end

	const indexData = grid.CellIndex[key]
	if not indexData then return end

	const idx = indexData.i
	const lastKey = cell[#cell]

	cell[idx] = lastKey

	grid.CellIndex[lastKey] = {
		x = x,
		z = z,
		i = idx,
	}

	cell[#cell] = nil
	grid.CellIndex[key] = nil

	if #cell == 0 then
		column[z] = nil

		if next(column) == nil then
			grid.Cells[x] = nil
		end

		const cx = floor(x / COARSE_FACTOR)
		const cz = floor(z / COARSE_FACTOR)
		const ck = _coarseKey(cx, cz)

		const coarse = grid.Coarse[ck]
		if coarse then
			coarse[x * 10000 + z] = nil
			if next(coarse) == nil then
				grid.Coarse[ck] = nil
			end
		end
	end
end

-- Private: Move entity from one cell to another
const function _reconcile(grid: Grid, key: Key): ()

	const pos = grid.Position[key]
	if not pos then return end

	const old = grid.CellCoords[key]
	const x, z = getCellCoords(grid, pos)

	if old and old.X == x and old.Y == z then
		grid.Dirty[key] = false
		return
	end

	if old then
		_removeFromCell(grid, key, old.X, old.Y)
	end

	local column = grid.Cells[x]
	if not column then
		column = {}
		grid.Cells[x] = column
	end

	local cell = column[z]
	if not cell then
		cell = {}
		column[z] = cell

		const cx = floor(x / COARSE_FACTOR)
		const cz = floor(z / COARSE_FACTOR)
		const ck = _coarseKey(cx, cz)

		local coarse = grid.Coarse[ck]
		if not coarse then
			coarse = {}
			grid.Coarse[ck] = coarse
		end

		coarse[x * 10000 + z] = { x = x, z = z }
	end

	const idx = #cell + 1
	cell[idx] = key

	grid.CellIndex[key] = {
		x = x,
		z = z,
		i = idx,
	}

	if old then
		old.X = x
		old.Y = z
	else
		grid.CellCoords[key] = Vector2.new(x, z)
	end

	grid.Dirty[key] = false
end

-- Public: Remove an entity from the grid (by entityId or BasePart)
const function remove(grid: Grid, entityId: EntityId): ()
	local key = getIdKey(entityId)

	const indexData = grid.CellIndex[key]
	if indexData then
		_removeFromCell(grid, key, indexData.x, indexData.z)
	end

	grid.Position[key] = nil
	grid.CellCoords[key] = nil
	grid.Dirty[key] = nil
	grid.EntityMap[key] = nil
end

-- Public: Query nearby entities
const function query(grid: Grid, pos: Vector3, radius: number?): {EntityId}
	const results = grid._scratchIds
	clear(results)

	clear(grid._ReconciledThisQuery)

	const cx, cz = getCellCoords(grid, pos)
	const cs = grid.CellSize

	const cellRadius = if radius then ceil(radius / cs) else 1
	const r2 = if radius then radius * radius else nil

	const px, pz = pos.X, pos.Z

	for x = cx - cellRadius, cx + cellRadius do
		const col = grid.Cells[x]
		if col then
			for z = cz - cellRadius, cz + cellRadius do
				const cell = col[z]
				if cell then
					for i = 1, #cell do
						const id = cell[i]

						-- reconcile if dirty
						if grid.Dirty[id] and not grid._ReconciledThisQuery[id] then
							grid._ReconciledThisQuery[id] = true
							_reconcile(grid, id)
						end

						const p = grid.Position[id]
						if p then
							const dx = p.X - px
							const dz = p.Z - pz

							if not r2 or (dx * dx + dz * dz) <= r2 then
								results[#results + 1] = grid.EntityMap[id]
							end
						end
					end
				end
			end
		end
	end

	return results
end

-- Public: Query all entities in a given radius
const function queryAllInRadius(grid: Grid, pos: Vector3, radius: number): {EntityId}
	const results = grid._scratchIds
	clear(results)

	clear(grid._ReconciledThisQuery)

	const cx, cz = getCellCoords(grid, pos)
	const cs = grid.CellSize

	const cellRadius = ceil(radius / cs)
	const r2 = radius * radius

	const px, pz = pos.X, pos.Z

	for x = cx - cellRadius, cx + cellRadius do
		const col = grid.Cells[x]
		if col then
			for z = cz - cellRadius, cz + cellRadius do
				const cell = col[z]
				if cell then
					for i = 1, #cell do
						const id = cell[i]

						-- reconcile dirty entities once per query
						if grid.Dirty[id] and not grid._ReconciledThisQuery[id] then
							grid._ReconciledThisQuery[id] = true
							_reconcile(grid, id)
						end

						const p = grid.Position[id]
						if p then
							const dx = p.X - px
							const dz = p.Z - pz

							if (dx * dx + dz * dz) <= r2 then
								results[#results + 1] = grid.EntityMap[id]
							end
						end
					end
				end
			end
		end
	end

	return results
end


-- Public: Returns the cell coordinates for an entity or a Vector3
local function getCellKey(grid: Grid, entityIdOrPos: EntityId | Vector3): (number?, number?)
	if typeof(entityIdOrPos) == "Vector3" then
		return getCellCoords(grid, entityIdOrPos)

	elseif typeof(entityIdOrPos) == "number" or typeof(entityIdOrPos) == "vector" then
		local key = getIdKey(entityIdOrPos)
		local coords = grid.CellCoords[key]

		if coords then
			return coords.X, coords.Y
		end
	end

	return nil, nil
end

-- Public: Empty the grid
const function empty(grid: Grid): ()
	clear(grid.Position)
	clear(grid.CellCoords)
	clear(grid.Cells)
	clear(grid.CellIndex)
	clear(grid.Dirty)
	clear(grid.Coarse)
	clear(grid._ReconciledThisQuery)

	clear(grid._scratchParts)
	clear(grid._scratchIds)
end

-- Public: Destroy the grid
const function destroy(grid: Grid?): ()
	if not grid then return end

	table.clear(grid)
end

-- Return API
return table.freeze({
	name = "grid",
	newGrid = newGrid,
	getCellCoords = getCellCoords,
	spawn = spawn,
	updatePosition = updatePosition,
	getCellKey = getCellKey,
	remove = remove,
	query = query,
	queryAllInRadius = queryAllInRadius,
	empty = empty,
	destroy = destroy,
})
