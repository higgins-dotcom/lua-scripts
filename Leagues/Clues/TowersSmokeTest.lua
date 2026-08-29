--[[
# Script Name:   TowersSmokeTest
# Description:   Smoke test and optional no-submit solver for Towers puzzle
# Author:        Higgins
# Version:       1.0
# Date:          2026.08.29
--]]

-- while API.Read_LoopyLoop() do

local API = require("API")
local PuzzleModule = require("PuzzleModule2")

local TOWERS_INTERFACE = 1934
local TOWERS_GRID_COMPONENT = 7
local TOWERS_SLOT_VARBIT_BASE = 39675
local TOWERS_HINT_VARBITS = {
	top = 39747,
	left = 39752,
	bottom = 39757,
	right = 39762,
}

-- This test fills the puzzle but never clicks the Check button.
local RUN_SOLVER = true

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
	print("Using direct Towers tile targets; no interface scan required")
	print("Parent component: 1934,7")
	print("Expected action mapping: visible 1->operation 2, 2->3, 3->4, 4->5, 5->6")

	for slot = 0, 24 do
		local row = math.floor(slot / 5) + 1
		local col = (slot % 5) + 1
		print(string.format("slot %02d -> row %d col %d | DoAction(..., 1934, 7, %d, ...)", slot, row, col, slot))
	end

	return true
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
	if not componentsOk then
		print("RESULT: Towers tile mapping is incomplete or invalid")
		return false
	end

	if not RUN_SOLVER then
		print("RESULT: Towers varbits and direct targets look valid; solver disabled")
		return true
	end

	print("Starting solver; the Check button will NOT be clicked")
	local solved = PuzzleModule.solveTowersPuzzle(false)
	if solved then
		print("RESULT: Towers solution placed; Check button was skipped")
	else
		print("RESULT: Towers solver failed before completion")
	end
	return solved
end

main()
