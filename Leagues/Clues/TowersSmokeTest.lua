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

local function getReturnedInfo(result)
	if type(result) == "table" then
		if result.id3 ~= nil then
			return result
		end
		return result[1]
	end

	local success, id3 = pcall(function()
		return result.id3
	end)
	if success and id3 ~= nil then
		return result
	end
	return nil
end

local function probeTile(slot, targetUnder)
	local success, result = pcall(function()
		return API.ScanForInterfaceTest2Get2(
			targetUnder,
			{ TOWERS_INTERFACE, TOWERS_GRID_COMPONENT, slot, 0 }
		)
	end)
	if not success then
		return nil, "call failed: " .. tostring(result)
	end

	local info = getReturnedInfo(result)
	if not info then
		return nil, "type=" .. type(result)
	end
	return info
end

local function inspectTileComponents()
	print("Probing Towers tile components individually...")
	print("Expected action mapping: visible 1->operation 2, 2->3, 3->4, 4->5, 5->6")

	local validCount = 0
	for slot = 0, 24 do
		local row = math.floor(slot / 5) + 1
		local col = (slot % 5) + 1
		local tile, errorMessage = probeTile(slot, false)

		-- Some API builds interpret target_under differently. Probe the alternate
		-- mode as diagnostics, without performing any action.
		if not tile then
			local alternateTile, alternateError = probeTile(slot, true)
			if alternateTile then
				tile = alternateTile
				errorMessage = "found with target_under=true"
			else
				errorMessage = tostring(errorMessage) .. "; alternate: " .. tostring(alternateError)
			end
		end

		if tile then
			validCount = validCount + 1
			print(string.format(
				"slot %02d -> row %d col %d | returned id1=%s id2=%s id3=%s | %s",
				slot,
				row,
				col,
				tostring(tile.id1),
				tostring(tile.id2),
				tostring(tile.id3),
				errorMessage or "target_under=false"
			))
		else
			print(string.format("MISSING: slot %02d expected at row %d col %d (%s)", slot, row, col, errorMessage))
		end
	end

	print(string.format("Valid individually resolved tile slots: %d/25", validCount))
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
