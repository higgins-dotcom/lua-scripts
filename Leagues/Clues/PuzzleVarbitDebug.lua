--[[
Slide-puzzle varbit diagnostic and optional solve attempt.

Run this script while the slide-puzzle interface is open. It reports the
active struct/type and prints the 25 tile values before any solve attempt.
]]

local PuzzleModule = require("PuzzleModule2")

-- Set API_TOKEN before running if you want the solve attempt enabled.
local ATTEMPT_SOLVE = true
local API_TOKEN = ""

local function printPuzzleState(state)
	print("Flat tile values (zero-based position -> tile):")
	for position = 1, 25 do
		print(string.format("tile[%02d] = %d", position - 1, state[position]))
	end

	print("5x5 tile grid (24 is the blank):")
	for row = 0, 4 do
		local values = {}
		for column = 0, 4 do
			local position = row * 5 + column + 1
			values[#values + 1] = string.format("%2d", state[position])
		end
		print(string.format("row %d: %s", row, table.concat(values, " ")))
	end
end

local function main()
	print("=== Puzzle varbit debug (optional solve) ===")

	if not PuzzleModule.isPuzzleOpen() then
		print("No slide-puzzle interface is open; nothing was read.")
		return false
	end

	local puzzleType, structId = PuzzleModule.getActivePuzzleType()
	if not puzzleType then
		print("Could not identify the active slide-puzzle struct/type.")
		return false
	end

	print("Active struct ID: " .. tostring(structId))
	print("Active puzzle type: " .. tostring(puzzleType))

	local state = PuzzleModule.extractPuzzleState()
	if not state then
		print("Could not read a valid, synchronized 25-tile state.")
		return false
	end

	printPuzzleState(state)

	if not ATTEMPT_SOLVE then
		print("Debug complete; solve attempt disabled and no game action was performed.")
		return true
	end

	if API_TOKEN == "" then
		print("Solve attempt skipped: configure API_TOKEN in PuzzleVarbitDebug.lua first.")
		return false
	end

	print("Attempting to solve the printed puzzle state...")
	local solved = PuzzleModule.solvePuzzle(state, API_TOKEN)
	if solved then
		print("Solve attempt completed successfully.")
	else
		print("Solve attempt failed or returned no solution.")
	end
	return solved
end

main()
