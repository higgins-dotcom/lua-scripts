--[[
# Script Name:   TowersSmokeTest
# Description:   Read-only smoke test for the Towers/Skyscrapers clue puzzle
# Author:        Higgins
# Version:       1.0
# Date:          2026.08.29
--]]

-- while API.Read_LoopyLoop() do

local API = require("API")

local TOWERS_INTERFACE = 1934
local TOWERS_GRID_COMPONENT = 7
local TOWERS_SLOT_VARBIT_BASE = 39675
local TOWERS_HINT_VARBITS = {
	top = 39747,
	left = 39752,
	bottom = 39757,
	right = 39762,
}

local function readVarbit(id)
	local success, value = pcall(function()
		return API.GetVarbitValue(id)
	end)
	if not success or type(value) ~= "number" then
		return nil
	end
	return value
end

local function readRange(firstId, count)
	local values = {}
	for offset = 0, count - 1 do
		local value = readVarbit(firstId + offset)
		if value == nil then
			return nil
		end
		values[offset + 1] = value
	end
	return values
end

local function printGrid(values)
	print("Tower grid varbits (visual row/column order):")
	for row = 1, 5 do
		local line = {}
		for col = 1, 5 do
			-- CS2 names the slots slot_<column>_<row>, so the cache range
			-- is column-major even though the displayed grid is row-major.
			local index = (col - 1) * 5 + row
			line[col] = tostring(values[index])
		end
		print(string.format("row %d: %s", row, table.concat(line, " ")))
	end
end

local function printHints()
	print("Tower clue varbits:")
	for _, direction in ipairs({ "top", "left", "bottom", "right" }) do
		local values = readRange(TOWERS_HINT_VARBITS[direction], 5)
		if not values then
			print(direction .. ": FAILED TO READ")
		else
			print(direction .. ": " .. table.concat(values, " "))
		end
	end
end

local function inspectTileComponents()
	print("Scanning Towers tile components...")
	local success, tiles = pcall(function()
		return API.ScanForInterfaceTest2Get2(true, { TOWERS_INTERFACE, TOWERS_GRID_COMPONENT, -1, 0 })
	end)
	if not success or type(tiles) ~= "table" then
		print("FAILED: ScanForInterfaceTest2Get2 did not return a component list")
		return false
	end

	print("Scan returned " .. tostring(#tiles) .. " components")
	local seen = {}
	local validCount = 0
	for _, tile in ipairs(tiles) do
		local slot = tonumber(tile.id3)
		if slot and slot >= 0 and slot < 25 then
			local row = math.floor(slot / 5) + 1
			local col = (slot % 5) + 1
			if seen[slot] then
				print(string.format("DUPLICATE: id3=%d at row %d col %d", slot, row, col))
			else
				seen[slot] = true
				validCount = validCount + 1
				print(string.format("id3=%d -> row %d col %d", slot, row, col))
			end
		else
			print("INVALID: returned tile has id3=" .. tostring(tile.id3))
		end
	end

	for slot = 0, 24 do
		if not seen[slot] then
			local row = math.floor(slot / 5) + 1
			local col = (slot % 5) + 1
			print(string.format("MISSING: id3=%d expected at row %d col %d", slot, row, col))
		end
	end

	print(string.format("Valid unique tile slots: %d/25", validCount))
	return validCount == 25
end

local function main()
	print("=== Towers smoke test (read-only) ===")
	if not API.GetInterfaceOpenBySize(TOWERS_INTERFACE) then
		print("FAILED: Towers interface 1934 is not open")
		return false
	end

	local grid = readRange(TOWERS_SLOT_VARBIT_BASE, 25)
	if not grid then
		print("FAILED: Could not read Towers grid varbits 39675-39699")
		return false
	end

	printGrid(grid)
	printHints()
	local componentsOk = inspectTileComponents()
	if componentsOk then
		print("RESULT: Towers varbits and all 25 tile mappings look valid")
	else
		print("RESULT: Towers tile mapping is incomplete or invalid")
	end
	return componentsOk
end

main()
