--!native
--!strict
-- USAGE: lightreflector/client/grid.luau
-- Typed spatial grid for Light Reflector

--[[

   This Source Code Form is subject to the terms of the Mozilla Public
   License, v. 2.0. If a copy of the MPL was not distributed with this
   file, You can obtain one at https://mozilla.org/MPL/2.0/.

]]

-- Types: Not in the types module for now since it may not be final
export type EntityId = number

export type Grid = {
	CellSize: number,

	Position: {[EntityId]: Vector3},
	Part: {[EntityId]: BasePart},
	CellCoords: {[EntityId]: Vector2},

	Cells: {[number]: {[number]: {EntityId}}},
	CellIndex: {[EntityId]: number},

	PartToId: {[BasePart]: EntityId},

	NextEntityId: EntityId,
}

-- Public: Create a new grid
local function newGrid(cellSize: number?): Grid
	return {
		CellSize = cellSize or 1900,

		Position = {},      -- [entityId] = Vector3
		Part = {},          -- [entityId] = BasePart
		CellCoords = {},    -- [entityId] = Vector2 (x,z)
		Cells = {},         -- [x][z] = {entityId, ...}
		CellIndex = {},     -- [entityId] = index in cell
		PartToId = {},      -- [BasePart] = entityId
		NextEntityId = 1,   -- unique entity IDs
	}
end

-- Private: Get cell table for coordinates (creates if missing)
local function _getCellTable(grid: Grid, x: number, z: number): {EntityId}
	local column = grid.Cells[x]
	if not column then
		column = {}
		grid.Cells[x] = column
	end
	local cell = column[z]
	if not cell then
		cell = {}
		column[z] = cell
	end
	return cell
end

-- Public: Get cell coordinates
local function getCellCoords(grid: Grid, pos: Vector3): (number, number)
	return math.floor(pos.X / grid.CellSize), math.floor(pos.Z / grid.CellSize)
end

-- Private: Remove entity from a cell
local function _removeFromCell(grid: Grid, entityId: EntityId, x: number, z: number): ()
	local cell = grid.Cells[x] and grid.Cells[x][z]
	if not cell then return end

	local idx = grid.CellIndex[entityId]
	if idx then
		local lastId = cell[#cell]
		cell[idx] = lastId
		grid.CellIndex[lastId] = idx
		cell[#cell] = nil
		grid.CellIndex[entityId] = nil

		-- Optional: clean up empty cells
		if #cell == 0 then
			grid.Cells[x][z] = nil
			if next(grid.Cells[x]) == nil then
				grid.Cells[x] = nil
			end
		end
	end
end

-- Public: Spawn a new entity into the grid
local function spawn(grid: Grid, part: BasePart, pos: Vector3): EntityId
	local id = grid.NextEntityId
	grid.NextEntityId += 1

	grid.Position[id] = pos
	grid.Part[id] = part
	grid.PartToId[part] = id

	local x, z = getCellCoords(grid, pos)
	grid.CellCoords[id] = Vector2.new(x, z)

	local cell = _getCellTable(grid, x, z)
	local idx = #cell + 1
	cell[idx] = id
	grid.CellIndex[id] = idx

	return id
end

-- Public: Update an entity's position
local function updatePosition(grid: Grid, entityId: EntityId, pos: Vector3): ()
	local oldCoords = grid.CellCoords[entityId]
	local x, z = getCellCoords(grid, pos)
	grid.Position[entityId] = pos

	if oldCoords then
		local oldX, oldZ = oldCoords.X, oldCoords.Y
		if oldX ~= x or oldZ ~= z then
			_removeFromCell(grid, entityId, oldX, oldZ)

			local newCell = _getCellTable(grid, x, z)
			local idx = #newCell + 1
			newCell[idx] = entityId
			grid.CellIndex[entityId] = idx

			oldCoords.X = x
			oldCoords.Y = z
		end
	end
end

-- Public: Returns the cell coordinates for an entity or a Vector3
local function getCellKey(grid: Grid, entityIdOrPos: EntityId | Vector3): (number?, number?)
	if typeof(entityIdOrPos) == "Vector3" then
		local x, z = getCellCoords(grid, entityIdOrPos)
		return x, z
	elseif typeof(entityIdOrPos) == "number" then
		local coords = grid.CellCoords[entityIdOrPos]
		if coords then
			return coords.X, coords.Y
		end
	end
	return nil, nil
end

-- Remove an entity from the grid (by entityId or BasePart)
local function remove(grid: Grid, entityOrPart: EntityId | BasePart, old_pos: Vector3?): () -- old_pos for compatibility
	local entityId = typeof(entityOrPart) == "number" and entityOrPart or grid.PartToId[entityOrPart]
	if not entityId then return end

	local coords = grid.CellCoords[entityId]
	if coords then
		_removeFromCell(grid, entityId, coords.X, coords.Y)
	end

	local part = grid.Part[entityId]
	if part then grid.PartToId[part] = nil end
	grid.Position[entityId] = nil
	grid.Part[entityId] = nil
	grid.CellCoords[entityId] = nil
end

-- Public: Query nearby entities
local function query(grid: Grid, pos: Vector3, radius: number?): {BasePart}
	local results = {}
	local r2 = radius and radius * radius
	local cx, cz = getCellCoords(grid, pos)
	local cellRadius = radius and math.ceil(radius / grid.CellSize) or 1

	for x = cx - cellRadius, cx + cellRadius do
		for z = cz - cellRadius, cz + cellRadius do
			local cell = grid.Cells[x] and grid.Cells[x][z]
			if cell then
				for i = 1, #cell do
					local entityId = cell[i]
					local p = grid.Position[entityId]
					if p and (not r2 or (p - pos).Magnitude^2 <= r2) then
						results[#results + 1] = grid.Part[entityId]
					end
				end
			end
		end
	end

	return results
end

-- Public: Query nearby entities
local function queryAllInRadius(grid: Grid, pos: Vector3, radius: number): {EntityId}
	local results = {}
	local r2 = radius * radius
	local cx, cz = getCellCoords(grid, pos)
	local cellRadius = math.ceil(radius / grid.CellSize)

	for x = cx - cellRadius, cx + cellRadius do
		for z = cz - cellRadius, cz + cellRadius do
			local cell = grid.Cells[x] and grid.Cells[x][z]
			if cell then
				for i = 1, #cell do
					local entityId = cell[i]
					local p = grid.Position[entityId]
					if p and (p - pos).Magnitude^2 <= r2 then
						results[#results + 1] = entityId
					end
				end
			end
		end
	end

	return results
end

-- Public: Empty the grid
local function empty(grid: Grid): ()
	table.clear(grid.Position)
	table.clear(grid.Part)
	table.clear(grid.CellCoords)
	table.clear(grid.Cells)
	table.clear(grid.CellIndex)
	table.clear(grid.PartToId)

	grid.NextEntityId = 0
	grid.CellSize = 0

	--table.freeze(grid :: any)
end

-- Public: Destroy the grid
local function destroy(grid: Grid): ()
	table.clear(grid :: any)
end

return table.freeze({
	newGrid = newGrid,
	getCellCoords = getCellCoords,
	spawn = spawn,
	updatePosition = updatePosition,
	getCellKey = getCellKey,
	remove = remove,
	query = query,
	queryAllInRadius = queryAllInRadius,
	empty = empty,
	destroy = destroy
})
