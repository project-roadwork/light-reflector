--!native
--!strict
-- USAGE: lightreflector/client/grid.luau
-- Typed spatial grid for Light Reflector

--[[
    SPDX-FileCopyrightText: 2025-2026 Illinois_Roadbuff (Rogue Jr) <illinois_roadbuff@proton.me>
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

-- Types
type Key = string | number

type Grid = {
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

type IndexData = {
	x: number,
	z: number,
	i: number,
}

const jecs: typeof(require("../shared/jecs")) = require("../shared/jecs")

type EntityId = jecs.Entity

-- Constants
const floor: (number) -> number = math.floor
const ceil: (number) -> number = math.ceil
const clear: ({}) -> () = table.clear
const COARSE_FACTOR: number = 4


--[=[
    Public: Gets ID key

	[Git Repository](https://codeberg.org/project-roadwork/spatial-grid.git)
]=]
const function getIdKey(entityId: EntityId | number | vector): number | string
	if typeof(entityId) == "number" then
		return entityId
	elseif typeof(entityId) == "vector" then
		return entityId.x .. ":" .. entityId.y .. ":" .. entityId.z
	elseif typeof(entityId) == "Vector3" then
		return entityId.X .. ":" .. entityId.Y .. ":" .. entityId.Z
	end
	error("Invalid EntityId type: ".. typeof(entityId))
end

--[=[
    Public: Create a new grid

	[Git Repository](https://codeberg.org/project-roadwork/spatial-grid.git)
]=]
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

--[=[
    Public: Get cell coordinates

	[Git Repository](https://codeberg.org/project-roadwork/spatial-grid.git)
]=]
const function getCellCoords(grid: Grid, pos: Vector3): (number, number)
	return floor(pos.X / grid.CellSize), floor(pos.Z / grid.CellSize)
end

--[=[
    Private: Get the key for the coarse grid
    @private

	[Git Repository](https://codeberg.org/project-roadwork/spatial-grid.git)
]=]
const function _coarseKey(x: number, z: number): number
	return bit32.bxor(x * 73856093, z * 19349663)
end

--[=[
    Public: Spawn a new entity into the grid

	[Git Repository](https://codeberg.org/project-roadwork/spatial-grid.git)
]=]
const function spawn(grid: Grid, entityId: EntityId, pos: Vector3): ()
	const key: number | string = getIdKey(entityId)

	if grid.Position[key] then
		return
	end

	grid.EntityMap[key] = entityId
	grid.Position[key] = pos

	const x: number, z: number = getCellCoords(grid, pos)
	grid.CellCoords[key] = Vector2.new(x, z)

	local column: {[number]: {Key}} = grid.Cells[x]
	if not column then
		column = {} :: {[number]: {Key}}
		grid.Cells[x] = column
	end
	grid.Cells[x] = column

	local cell: {Key}? = column[z]
	if not cell then
		cell = {} :: {Key}
		column[z] = cell

		const cx: number = floor(x / COARSE_FACTOR)
		const cz: number = floor(z / COARSE_FACTOR)
		const ck: number = _coarseKey(cx, cz)

		local coarse: {[number]: {x: number, z: number}} = grid.Coarse[ck]
		if not coarse then
			coarse = {} :: {[number]: {x: number, z: number}}
			grid.Coarse[ck] = coarse
		end
		grid.Coarse[ck] = coarse

		coarse[x * 10000 + z] = { x = x, z = z }
	end

	if not cell then return end -- adding this because of type checker

	const idx: number = #cell + 1
	cell[idx] = key

	const indexData: IndexData = grid.CellIndex[key]

	if indexData then
		indexData.x = x
		indexData.z = z
		indexData.i = idx
	else
		grid.CellIndex[key] = { x = x, z = z, i = idx }
	end

	grid.Dirty[key] = false
end

--[=[
    Public: Update an entity's position

	[Git Repository](https://codeberg.org/project-roadwork/spatial-grid.git)
]=]
const function updatePosition(grid: Grid, entityId: EntityId, pos: Vector3): ()
	const key: number | string = getIdKey(entityId)

	if not grid.Position[key] then return end
	grid.Position[key] = pos
	grid.Dirty[key] = true
end

--[=[
    Private: Remove entity from a cell
    @private

	[Git Repository](https://codeberg.org/project-roadwork/spatial-grid.git)
]=]
const function _removeFromCell(grid: Grid, key: Key, x: number, z: number): ()
	const column: {[number]: {Key}} = grid.Cells[x]
	if not column then return end

	const cell: {Key}?  = column[z]
	if not cell then return end

	const indexData: IndexData = grid.CellIndex[key]
	if not indexData then return end

	const idx: number = indexData.i

	if idx ~= #cell then
		const lastKey: Key = cell[#cell]
		cell[idx] = lastKey
		grid.CellIndex[lastKey].i = idx
	end

    cell[#cell] = nil
    grid.CellIndex[key] = nil

	if #cell == 0 then
		column[z] = nil

		if next(column) == nil then
			grid.Cells[x] = nil
		end

		const cx: number = floor(x / COARSE_FACTOR)
		const cz: number = floor(z / COARSE_FACTOR)
		const ck: number = _coarseKey(cx, cz)

		const coarse: {[number]: {x: number, z: number}}? = grid.Coarse[ck]
		if coarse then
			coarse[x * 10000 + z] = nil
			if next(coarse) == nil then
				grid.Coarse[ck] = nil
			end
		end
	end
end

--[=[
    Private: Move entity from one cell to another
    @private

	[Git Repository](https://codeberg.org/project-roadwork/spatial-grid.git)
]=]
const function _reconcile(grid: Grid, key: Key): ()
	const pos: Vector3 = grid.Position[key]
	if not pos then return end

	const old: Vector2 = grid.CellCoords[key]
	const x: number, z: number = getCellCoords(grid, pos)

	if old and old.X == x and old.Y == z then
		grid.Dirty[key] = false
		return
	end

	if old then
		_removeFromCell(grid, key, old.X, old.Y)
	end

	local column: {[number]: {Key}}? = grid.Cells[x]
	if not column then
		column = {} :: {[number]: {Key}}
		grid.Cells[x] = column
	end

	if not column then return end -- adding this because of type checker

	local cell: {Key}? = column[z]
	if not cell then
		cell = {} :: {Key}
		column[z] = cell

		const cx: number = floor(x / COARSE_FACTOR)
		const cz: number = floor(z / COARSE_FACTOR)
		const ck: number = _coarseKey(cx, cz)

		local coarse: {[number]: {x: number, z: number}}? = grid.Coarse[ck]
		if not coarse then
			coarse = {} :: {[number]: {x: number, z: number}}
			grid.Coarse[ck] = coarse
		end

		if not coarse then return end -- have to add this because of types

		coarse[x * 10000 + z] = { x = x, z = z }
	end

	if not cell then return end -- have to add this again because of type checker

	const idx: number = #cell + 1
	cell[idx] = key

	const indexData: IndexData = grid.CellIndex[key]

	if indexData then
		indexData.x = x
		indexData.z = z
		indexData.i = idx
	else
		grid.CellIndex[key] = { x = x, z = z, i = idx }
	end

	if old then
		old.X = x
		old.Y = z
	else
		grid.CellCoords[key] = Vector2.new(x, z)
	end

	grid.Dirty[key] = false
end

--[=[
    Public: Remove an entity from the grid by entityId

	[Git Repository](https://codeberg.org/project-roadwork/spatial-grid.git)
]=]
const function remove(grid: Grid, entityId: EntityId): ()
	const key: number | string = getIdKey(entityId)

	const indexData: IndexData = grid.CellIndex[key]
	if indexData then
		_removeFromCell(grid, key, indexData.x, indexData.z)
	end

	grid.Position[key] = nil
	grid.CellCoords[key] = nil
	grid.Dirty[key] = nil
	grid.EntityMap[key] = nil
end

--[=[
    Public: Query nearby entities

	[Git Repository](https://codeberg.org/project-roadwork/spatial-grid.git)
]=]
const function query(grid: Grid, pos: Vector3, radius: number?): {jecs.Entity<nil>}
	const results: {[number]: EntityId} = grid._scratchIds -- This may get mutated over time
	clear(results)

	clear(grid._ReconciledThisQuery)

	const cx: number, cz: number = getCellCoords(grid, pos)
	const cs: number = grid.CellSize

	const cellRadius: number = if radius then ceil(radius / cs) else 1

	const r2: number? = if radius then radius * radius else nil

	const px: number, pz: number = pos.X, pos.Z

	if cellRadius <= COARSE_FACTOR then
		for x: number = cx - cellRadius, cx + cellRadius do
			const col: {[number]: {Key}}? = grid.Cells[x]
			if col then
				for z: number = cz - cellRadius, cz + cellRadius do
					const cell: {Key}? = col[z]
					if cell then
						for i: number = 1, #cell do
							const id: Key = cell[i]
							-- reconcile if dirty
							if grid.Dirty[id] and not grid._ReconciledThisQuery[id] then
								grid._ReconciledThisQuery[id] = true
								_reconcile(grid, id)
							end

							const p: Vector3 = grid.Position[id]
							if p then
								const dx: number = p.X - px
								const dz: number = p.Z - pz

								if not r2 or (dx * dx + dz * dz) <= r2 then
									results[#results + 1] = grid.EntityMap[id]
								end
							end
						end
					end
				end
			end
		end
	else
		const ccx: number = floor(cx / COARSE_FACTOR)
		const ccz: number = floor(cz / COARSE_FACTOR)

        const coarseRadius: number = ceil(cellRadius / COARSE_FACTOR)

        for icx: number = ccx - coarseRadius, ccx + coarseRadius do
			for icz: number = ccz - coarseRadius, ccz + coarseRadius do
				const ck: number = _coarseKey(icx, icz)
				const coarse: {[number]: {x: number, z: number}}? = grid.Coarse[ck]

				if coarse then
					for _, coord: {x: number, z: number} in pairs(coarse) do
						const x: number = coord.x
						const z: number = coord.z

						const col: {[number]: {Key}}? = grid.Cells[x]
						if col then
							const cell: {Key}? = col[z]
							if cell then
								for i: number = 1, #cell do
									const id: Key = cell[i]

									-- reconcile if dirty
									if grid.Dirty[id] and not grid._ReconciledThisQuery[id] then
										grid._ReconciledThisQuery[id] = true
										_reconcile(grid, id)
									end

									const p: Vector3 = grid.Position[id]
									if p then
										const dx: number = p.X - px
										const dz: number = p.Z - pz

										if not r2 or (dx * dx + dz * dz) <= r2 then
											results[#results + 1] = grid.EntityMap[id]
										end
									end
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

--[=[
    Public: Returns the cell coordinates for an entity or a Vector3

	[Git Repository](https://codeberg.org/project-roadwork/spatial-grid.git)
]=]
const function getCellKey(grid: Grid, entityIdOrPos: EntityId | Vector3): (number?, number?)
	if typeof(entityIdOrPos) == "Vector3" then
		return getCellCoords(grid, entityIdOrPos)

	elseif typeof(entityIdOrPos) == "number" or typeof(entityIdOrPos) == "vector" then
		const key: number | string = getIdKey(entityIdOrPos)
		const coords: Vector2 = grid.CellCoords[key]

		if coords then
			return coords.X, coords.Y
		end
	end

	return nil, nil
end

--[=[
    Public: Empties the grid

	[Git Repository](https://codeberg.org/project-roadwork/spatial-grid.git)
]=]
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

--[=[
    Public: Destroys the grid

	[Git Repository](https://codeberg.org/project-roadwork/spatial-grid.git)
]=]
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
	empty = empty,
	destroy = destroy,
})
