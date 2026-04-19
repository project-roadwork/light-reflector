--!native
--!strict
-- USAGE: lightreflector/client/grid.luau
-- Typed spatial grid for Light Reflector

--[[

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at https://mozilla.org/MPL/2.0/.

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
	-  API:                                                                       -
	-  const grids = require(THIS_MODULE)                                         -
	-  const grid = gridModule.newGrid(1900)                                      -
	-  const entityId = grids.spawn(grid, part, Vector3)                          -
	-                                                                             -
	-  grids.updatePosition(grid, entityId, Vector3)                              -
	-  grids.remove(grid, entityId or part)                                       -
	-                                                                             -
	-  const parts = grids.query(grid, Vector3, radius?)                          -
    -  const entityIds = grids.queryAllInRadius(grid, Vector3, radius)            -
    -                                                                             -
    -  const x, z = grids.getCellCoords(grid, position)                           -
    -  const x, z = grids.getCellKey(grid, id or position)                        -
    -                                                                             -
    -  grids.empty(grid)                                                          -
    -  grids.destroy(grid)                                                        -
    -                                                                             -
    -  Copyright (c) 2026 Project Roadwork and Contributors                       -
    -                                                                             -
    -  Repositories:                                                              -
    -   https://codeberg.org/project-roadwork/spatial-grid (Main)                 -
    -   https://github.com/project-roadwork/spatial-grid (Backup)                 -
    -                                                                             -
    -  Authors:                                                                   -
    -  Illinois_Roadbuff (Rogue Jr) - April 1, 2026 - Created the file            -
    -                                                                             -
    - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - - -

]]

--!strict
--!native

-- Types
export type EntityId = number

export type Grid = {
	CellSize: number,

	Position: {[EntityId]: Vector3},
	Part: {[EntityId]: BasePart},
	CellCoords: {[EntityId]: Vector2},

	Cells: {[number]: {[number]: {EntityId}}},

	Coarse: {[number]: {[number]: {x: number, z: number}}},

	CellIndex: {[EntityId]: {x: number, z: number, i: number}},

	PartToId: {[BasePart]: EntityId},

	NextEntityId: EntityId,

	Dirty: {[EntityId]: boolean},

	CellCache: {[number]: {EntityId}?},

	_ReconciledThisQuery: {[EntityId]: boolean},
	_QueryLock: boolean,

	_scratchParts: {BasePart},
	_scratchIds: {EntityId},
}

-- Constants
const floor = math.floor
const ceil = math.ceil
const clear = table.clear
const COARSE_FACTOR = 4

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
		PartToId = {},
		NextEntityId = 1,

		Dirty = {},

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
const function spawn(grid: Grid, part: BasePart, pos: Vector3): EntityId
	const id = grid.NextEntityId
	grid.NextEntityId += 1

	grid.Position[id] = pos
	grid.Part[id] = part
	grid.PartToId[part] = id

	const x, z = getCellCoords(grid, pos)
	grid.CellCoords[id] = Vector2.new(x, z)

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
	cell[idx] = id

	grid.CellIndex[id] = {
		x = x,
		z = z,
		i = idx,
	}

	grid.Dirty[id] = false

	return id
end

-- Public: Update an entity's position
const function updatePosition(grid: Grid, entityId: EntityId, pos: Vector3): ()
	if not grid.Part[entityId] then return end
	grid.Position[entityId] = pos
	grid.Dirty[entityId] = true
end

-- Private: Remove entity from a cell
const function _removeFromCell(grid: Grid, entityId: EntityId, x: number, z: number): ()
	const column = grid.Cells[x]
	if not column then return end

	const cell = column[z]
	if not cell then return end

	const indexData = grid.CellIndex[entityId]
	if not indexData then return end

	const idx = indexData.i
	const lastId = cell[#cell]

	cell[idx] = lastId

	grid.CellIndex[lastId] = {
		x = x,
		z = z,
		i = idx,
	}

	cell[#cell] = nil
	grid.CellIndex[entityId] = nil

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
const function _reconcile(grid: Grid, entityId: EntityId): ()
	const pos = grid.Position[entityId]
	if not pos then return end

	const old = grid.CellCoords[entityId]
	const x, z = getCellCoords(grid, pos)

	if old and old.X == x and old.Y == z then
		grid.Dirty[entityId] = false
		return
	end

	if old then
		_removeFromCell(grid, entityId, old.X, old.Y)
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
	cell[idx] = entityId

	grid.CellIndex[entityId] = {
		x = x,
		z = z,
		i = idx,
	}

	if old then
		old.X = x
		old.Y = z
	else
		grid.CellCoords[entityId] = Vector2.new(x, z)
	end

	grid.Dirty[entityId] = false
end

-- Public: Remove an entity from the grid (by entityId or BasePart)
const function remove(grid: Grid, entityOrPart: EntityId | BasePart): ()
	const id = typeof(entityOrPart) == "number" and entityOrPart or grid.PartToId[entityOrPart]
	if not id then return end

	const indexData = grid.CellIndex[id]
	if indexData then
		_removeFromCell(grid, id, indexData.x, indexData.z)
	end

	const part = grid.Part[id]
	if part then
		grid.PartToId[part] = nil
	end

	grid.Position[id] = nil
	grid.Part[id] = nil
	grid.CellCoords[id] = nil
	grid.Dirty[id] = nil
end

-- Public: Query nearby entities
const function query(grid: Grid, pos: Vector3, radius: number?): {BasePart}?

	const results = grid._scratchParts
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

						if grid.Dirty[id] and not grid._ReconciledThisQuery[id] then
							grid._ReconciledThisQuery[id] = true
							_reconcile(grid, id)
						end

						const p = grid.Position[id]
						if p then
							const dx = p.X - px
							const dz = p.Z - pz

							if not r2 or (dx * dx + dz * dz) <= r2 then
								const part = grid.Part[id]
								if part then
									results[#results + 1] = part
								end
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
const function queryAllInRadius(grid: Grid, pos: Vector3, radius: number): {EntityId}?

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

						if grid.Dirty[id] and not grid._ReconciledThisQuery[id] then
							grid._ReconciledThisQuery[id] = true
							_reconcile(grid, id)
						end

						const p = grid.Position[id]
						if p then
							const dx = p.X - px
							const dz = p.Z - pz

							if (dx * dx + dz * dz) <= r2 then
								results[#results + 1] = id
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
const function getCellKey(grid: Grid, entityIdOrPos: EntityId | Vector3): (number?, number?)
	if typeof(entityIdOrPos) == "Vector3" then
		return getCellCoords(grid, entityIdOrPos)
	elseif typeof(entityIdOrPos) == "number" then
		const coords = grid.CellCoords[entityIdOrPos]
		if coords then
			return coords.X, coords.Y
		end
	end
	return nil, nil
end

-- Public: Empty the grid
const function empty(grid: Grid): ()
	clear(grid.Position)
	clear(grid.Part)
	clear(grid.CellCoords)
	clear(grid.Cells)
	clear(grid.CellIndex)
	clear(grid.PartToId)
	clear(grid.Dirty)
	clear(grid.Coarse)
	clear(grid._ReconciledThisQuery)

	clear(grid._scratchParts)
	clear(grid._scratchIds)

	grid.NextEntityId = 1
end

-- Public: Destroy the grid
const function destroy(grid: Grid?): ()
	if not grid then return end

	table.clear(grid)
end

-- Return API
return table.freeze({
	Name = "grid",
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
