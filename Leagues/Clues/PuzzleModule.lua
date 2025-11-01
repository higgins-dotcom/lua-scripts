--[[
====================================================================================================
Puzzle Module for Clue Solver
====================================================================================================
Version: 1.0
Author: Higgins
Description: Module for extracting and solving slide puzzles in clue scrolls

Functions:
- extractPuzzleState() - Gets current puzzle state from interface
- solvePuzzle(puzzleState) - Solves the puzzle and executes moves
====================================================================================================
]]

local API = require("API")

local PuzzleModule = {}

-- Single interface path for slide puzzle (gets all 25 tiles at once)
local SLIDE_PUZZLE_PATH = { { 1931, 11, -1, -1, 0 }, { 1931, 21, -1, 11, 0 }, { 1931, 18, -1, 21, 0 } }

-- Goal state for 5x5 puzzle (tiles 0-23 in order, 24 as blank)
local GOAL_STATE = {
	{ 0, 1, 2, 3, 4 },
	{ 5, 6, 7, 8, 9 },
	{ 10, 11, 12, 13, 14 },
	{ 15, 16, 17, 18, 19 },
	{ 20, 21, 22, 23, 24 },
}

-- Extract current puzzle state from game interface using single scan
function PuzzleModule.extractPuzzleState()
	print("DEBUG: Starting puzzle state extraction...")

	local interfaces = API.ScanForInterfaceTest2Get(true, SLIDE_PUZZLE_PATH)
	if not interfaces or #interfaces == 0 then
		print("Could not extract puzzle state - no interfaces found")
		return nil
	end

	print("DEBUG: Found", #interfaces, "interfaces")

	local tile_ids = {}
	for i, interface in ipairs(interfaces) do
		local success, tile_id = pcall(function()
			return API.Mem_Read_int(interface.memloc + API.I_slides)
		end)
		if success and tile_id then
			tile_ids[i] = tile_id
			print("DEBUG: Position", i, "tile_id:", tile_id)
		end
	end

	if #tile_ids ~= 25 then
		print("ERROR: Expected 25 tiles, got", #tile_ids)
		return nil
	end

	-- Sort tile IDs to create ordering
	local sorted_tiles = {}
	for i, tile_id in ipairs(tile_ids) do
		sorted_tiles[i] = tile_id
	end
	table.sort(sorted_tiles)

	local positions = {}
	for i = 1, 25 do
		local tile_id = tile_ids[i]
		-- Find position in sorted array
		for j = 1, 25 do
			if sorted_tiles[j] == tile_id then
				if j == 1 then
					positions[i] = 24 -- Empty space (lowest value)
				else
					positions[i] = j - 2 -- Map to 0-23 range
				end
				break
			end
		end
	end

	print("Extracted puzzle state:", table.concat(positions, ", "))
	return positions
end

-- Fallback extraction method using different approach
function PuzzleModule.extractPuzzleStateFallback()
	print("DEBUG: Trying fallback puzzle state extraction...")

	-- Try to get puzzle state using alternative method
	local positions = {}
	for i = 1, 25 do
		positions[i] = (i - 1) -- Default sequential state for testing
	end
	positions[25] = 24 -- Set last position as blank

	print("DEBUG: Using fallback puzzle state (for testing):", table.concat(positions, ", "))
	return positions
end

-- Convert flat list to 5x5 board
local function createBoardFromList(list)
	local board = {}
	local index = 1
	for y = 1, 5 do
		board[y] = {}
		for x = 1, 5 do
			board[y][x] = list[index]
			index = index + 1
		end
	end
	return board
end

-- Convert board to string for hashing
local function boardToString(board)
	local flat_board = {}
	for y = 1, 5 do
		for x = 1, 5 do
			table.insert(flat_board, tostring(board[y][x]))
		end
	end
	return table.concat(flat_board, ",")
end

-- Calculate Manhattan distance heuristic
local function manhattanDistance(board)
	local distance = 0
	for y = 1, 5 do
		for x = 1, 5 do
			local tile = board[y][x]
			if tile ~= 24 then
				local correct_y = math.floor(tile / 5) + 1
				local correct_x = (tile % 5) + 1
				distance = distance + math.abs(correct_x - x) + math.abs(correct_y - y)
			end
		end
	end
	return distance
end

-- Check if puzzle is solvable
local function isSolvable(board)
	local flat_board = {}
	for y = 1, 5 do
		for x = 1, 5 do
			local tile = board[y][x]
			if tile ~= 24 then
				table.insert(flat_board, tile)
			end
		end
	end

	local inversions = 0
	for i = 1, #flat_board do
		for j = i + 1, #flat_board do
			if flat_board[i] > flat_board[j] then
				inversions = inversions + 1
			end
		end
	end

	return inversions % 2 == 0
end

-- Find blank tile position
local function findBlank(board)
	for y = 1, 5 do
		for x = 1, 5 do
			if board[y][x] == 24 then
				return y, x
			end
		end
	end
end

-- Generate possible moves from current state
local function getNextStates(board)
	local next_states = {}
	local blank_y, blank_x = findBlank(board)

	local moves = { { 0, 1 }, { 0, -1 }, { 1, 0 }, { -1, 0 } }
	for _, move in ipairs(moves) do
		local new_y = blank_y + move[1]
		local new_x = blank_x + move[2]

		if new_y >= 1 and new_y <= 5 and new_x >= 1 and new_x <= 5 then
			local new_board = {}
			for y = 1, 5 do
				new_board[y] = {}
				for x = 1, 5 do
					new_board[y][x] = board[y][x]
				end
			end

			new_board[blank_y][blank_x] = new_board[new_y][new_x]
			new_board[new_y][new_x] = 24
			table.insert(next_states, new_board)
		end
	end
	return next_states
end

-- Get move direction name
local function getMoveName(from_board, to_board)
	local from_y, from_x = findBlank(from_board)
	local to_y, to_x = findBlank(to_board)

	if from_y > to_y then
		return "down"
	elseif from_y < to_y then
		return "up"
	elseif from_x > to_x then
		return "right"
	elseif from_x < to_x then
		return "left"
	end
end

-- local function getPuzzleSolutionFromAPI(puzzleState, apiToken)
-- 	print("Requesting puzzle solution from API...")

-- 	-- Check if API token is provided
-- 	if not apiToken or apiToken == "" then
-- 		print("ERROR: No API token provided for puzzle solver authentication")
-- 		return nil
-- 	end

-- 	-- Convert puzzle state to JSON format
-- 	local tiles_json = "["
-- 	for i = 1, #puzzleState do
-- 		tiles_json = tiles_json .. tostring(puzzleState[i])
-- 		if i < #puzzleState then
-- 			tiles_json = tiles_json .. ", "
-- 		end
-- 	end
-- 	tiles_json = tiles_json .. "]"

-- 	local json_data = '{"tiles" : ' .. tiles_json .. "}"
-- 	print("Sending JSON data:", json_data)

-- 	-- Create temporary files for cURL request
-- 	local temp_data_file = os.tmpname()
-- 	local temp_response_file = os.tmpname()

-- 	-- Write JSON data to temporary file
-- 	local data_file = io.open(temp_data_file, "w")
-- 	if not data_file then
-- 		print("ERROR: Could not create temporary data file")
-- 		return nil
-- 	end
-- 	data_file:write(json_data)
-- 	data_file:close()

-- 	-- Execute cURL command with Bearer token authentication
-- 	local curl_command = string.format(
-- 		'curl --insecure --location "api.rs3bot.com/puzzle" --header "Content-Type: application/json" --header "Authorization: Bearer %s" --data @"%s" --output "%s" --silent',
-- 		apiToken,
-- 		temp_data_file,
-- 		temp_response_file
-- 	)

-- 	print("Executing cURL command...")
-- 	local success = os.execute(curl_command)

-- 	if not success then
-- 		print("ERROR: cURL request failed")
-- 		-- Clean up temporary files
-- 		os.remove(temp_data_file)
-- 		os.remove(temp_response_file)
-- 		return nil
-- 	end

-- 	-- Read response from temporary file
-- 	local response_file = io.open(temp_response_file, "r")
-- 	if not response_file then
-- 		print("ERROR: Could not read response file")
-- 		-- Clean up temporary files
-- 		os.remove(temp_data_file)
-- 		os.remove(temp_response_file)
-- 		return nil
-- 	end

-- 	local response = response_file:read("*all")
-- 	response_file:close()

-- 	-- Clean up temporary files
-- 	os.remove(temp_data_file)
-- 	os.remove(temp_response_file)

-- 	print("API Response:", response)

-- 	-- Parse JSON response (simple parsing for expected format)
-- 	local result_start = response:find('"result":%s*%[')
-- 	local result_end = response:find("%]", result_start)

-- 	if not result_start or not result_end then
-- 		print("ERROR: Could not parse API response")
-- 		return nil
-- 	end

-- 	local result_json = response:sub(result_start + 9, result_end)
-- 	local moves = {}

-- 	-- Extract moves from JSON array
-- 	for move in result_json:gmatch('"([^"]+)"') do
-- 		table.insert(moves, move)
-- 	end

-- 	if #moves == 0 then
-- 		print("ERROR: No moves found in API response")
-- 		return nil
-- 	end

-- 	print("Received", #moves, "moves from API:", table.concat(moves, ", "))
-- 	return moves
-- end

-- Get puzzle solution from API using cURL
local function getPuzzleSolutionFromAPI(puzzleState, apiToken)
	print("Requesting puzzle solution from API...")

	-- Check if API token is provided
	if not apiToken or apiToken == "" then
		print("ERROR: No API token provided for puzzle solver authentication")
		return nil
	end

	-- Convert puzzle state to JSON format
	local tiles_json = "["
	for i = 1, #puzzleState do
		tiles_json = tiles_json .. tostring(puzzleState[i])
		if i < #puzzleState then
			tiles_json = tiles_json .. ", "
		end
	end
	tiles_json = tiles_json .. "]"

	local json_data = '{"tiles" : ' .. tiles_json .. "}"
	print("Sending JSON data:", json_data)

	local headers = {
		"Authorization: " .. apiToken,
	}

	local response = Http:Post("http://api.rs3bot.com/puzzle", json_data, headers)
	print("statusCode", response.statusCode, response.body)

	if not response.statusCode == 200 then
		print("ERROR: cURL request failed")
		return nil
	end

	if response.statusCode == 200 then
		print("API Response:", response.body)
		local data = API.JsonDecode(response.body)

		local data = response.GetBodyAsJson()
		if data and next(data) ~= nil then
			-- Process JSON data safely
			print(data)
		end

		print("DEBUG: Raw JSON moves count:", data.moves)
		print("DEBUG: Raw JSON result array length:", #data.result)

		-- Manual JSON parsing as backup to ensure we get all moves
		local manual_moves = {}
		local result_start = response.body:find('"result":%s*%[')
		local result_end = response.body:find("%]", result_start)

		if result_start and result_end then
			local result_json = response.body:sub(result_start + 9, result_end)
			print("DEBUG: Manual parsing result section:", result_json:sub(1, 100) .. "...")

			-- Extract moves manually
			for move in result_json:gmatch('"([^"]+)"') do
				table.insert(manual_moves, move)
			end

			print("DEBUG: Manual parsing found", #manual_moves, "moves")
			if #manual_moves > 0 then
				print(
					"DEBUG: First 5 manual moves:",
					table.concat(
						{ manual_moves[1], manual_moves[2], manual_moves[3], manual_moves[4], manual_moves[5] },
						", "
					)
				)
			end
		end

		-- Debug: Print the raw result array to see what's actually there
		print("DEBUG: JsonDecode result array contents:")
		for i, move in ipairs(data.result) do
			print(string.format("  JsonDecode[%d] = %s", i, tostring(move)))
		end

		-- Use manual parsing if it found more moves than JsonDecode
		local moves = data.result
		if #manual_moves > #moves then
			print("DEBUG: Using manual parsing (found", #manual_moves, "vs", #moves, "moves)")
			moves = manual_moves
		else
			print("DEBUG: Using JsonDecode result")
		end

		print("DEBUG: Final moves array length:", #moves)

		if #moves == 0 then
			print("ERROR: No moves found in API response")
			return nil
		end

		-- Check if we lost a move
		if data.moves and #moves ~= data.moves then
			print("WARNING: Move count mismatch!")
			print("  API says:", data.moves, "moves")
			print("  We got:", #moves, "moves")
			print("  Missing:", data.moves - #moves, "moves")
		end

		-- Debug: Print each move with its index
		print("DEBUG: Individual moves:")
		for i, move in ipairs(moves) do
			print(string.format("  [%d] = %s", i, move))
		end

		print("Received", #moves, "moves from API:", table.concat(moves, ", "))
		print("DEBUG: First move is:", moves[1])
		print("DEBUG: Last move is:", moves[#moves])

		return moves
	end
end

-- Check for "Puzzle complete" chat message
local function waitForPuzzleComplete()
	print("Waiting for 'Puzzle complete' message...")
	local startTime = os.time()
	local timeout = 10 -- 10 second timeout

	while os.time() - startTime < timeout do
		local chatMessages = API.GatherEvents_chat_check()
		if chatMessages then
			for _, message in ipairs(chatMessages) do
				if message and message.text then
					local messageText = tostring(message.text):lower()
					if messageText:find("puzzle complete") then
						print("Puzzle complete message detected!")
						return true
					end
				end
			end
		end
		API.RandomSleep2(100, 50, 50) -- Short sleep to avoid busy waiting
	end

	print("Timeout waiting for puzzle complete message")
	return false
end

-- Complete the clue step after puzzle is solved
local function completeClueStep()
	print("Completing clue step...")

	-- Wait a moment for any interface changes
	API.RandomSleep2(1000, 500, 500)

	-- Check if there are any dialogue options or interfaces to handle
	local dialogueState = API.VB_FindPSettinOrder(2874) -- VB_DIALOGUE_STATE
	if dialogueState and dialogueState.state ~= 12 then
		print("Dialogue detected, handling...")
		-- Handle any dialogue that might appear after puzzle completion
		API.RandomSleep2(500, 200, 200)
	end

	-- Check for any reward interfaces or continue buttons
	local continueInterface =
		API.ScanForInterfaceTest2Get(true, { { 1188, 5, -1, -1, 0 }, { 1188, 3, -1, 5, 0 }, { 1188, 3, 14, 3, 0 } })
	if continueInterface and #continueInterface > 0 then
		print("Continue interface detected, clicking...")
		API.DoAction_Interface(0x24, 0xffffffff, 1, 1188, 3, 14, API.OFF_ACT_GeneralInterface_route)
		API.RandomSleep2(1000, 500, 500)
	end

	-- Check if puzzle interface is still open and close it
	if PuzzleModule.isPuzzleOpen() then
		print("Puzzle interface still open, closing...")
		API.KeyboardPress2(0x1B, 50, 60) -- ESC key
		API.RandomSleep2(500, 200, 200)
	end

	print("Clue step completed - ready for next action")
	return true
end

-- Execute puzzle moves from API response
local function executeMoves(moves)
	print("Executing puzzle solution...")

	-- Check varbit 39326 before executing moves
	local puzzleVarbit = API.GetVarbitValue(39326)
	if puzzleVarbit == 0 then
		print("Puzzle interface not ready (varbit 39326 = 0), clicking to enable...")
		API.DoAction_Interface(0x2e, 0xffffffff, 1, 1931, 26, -1, API.OFF_ACT_GeneralInterface_route)
		API.RandomSleep2(1000, 500, 500)

		-- Check again after clicking
		puzzleVarbit = API.GetVarbitValue(39326)
		if puzzleVarbit and puzzleVarbit == 1 then
			print("Puzzle interface now ready (varbit 39326 = 1)")
		else
			print("WARNING: Puzzle interface still not ready after clicking")
		end
	elseif puzzleVarbit and puzzleVarbit == 1 then
		print("Puzzle interface ready (varbit 39326 = 1)")
	else
		print("WARNING: Could not read puzzle varbit 39326")
	end

	print("Waiting before moves")
	API.RandomSleep2(2000, 1000, 1000)

	for i = 1, #moves do
		-- Check if puzzle interface is still open before each move
		if not PuzzleModule.isPuzzleOpen() then
			print("Puzzle interface closed during move execution at move", i, "- puzzle may be complete")
			return true
		end

		local move = moves[i]
		print("Move " .. i .. "/" .. #moves .. ": " .. move)

		local keycode = 0
		if move == "left" then
			keycode = 0x25
		elseif move == "up" then
			keycode = 0x26
		elseif move == "right" then
			keycode = 0x27
		elseif move == "down" then
			keycode = 0x28
		end

		if keycode > 0 then
			API.KeyboardPress2(keycode, 60, 80)
			API.RandomSleep2(150, 150, 150)
		end
	end

	print("Puzzle solution completed!")

	-- Check if puzzle interface is still open (it may have auto-completed)
	if not PuzzleModule.isPuzzleOpen() then
		print("Puzzle interface already closed - puzzle auto-completed!")
		-- Wait for the "Puzzle complete" message
		if waitForPuzzleComplete() then
			print("Puzzle completion confirmed")
			return true
		else
			print("Puzzle interface closed but no completion message detected - assuming success")
			return true
		end
	end

	-- Press the Check button to complete the puzzle
	print("Pressing Check button to complete puzzle...")
	API.DoAction_Interface(0x24, 0xffffffff, 1, 1931, 34, -1, API.OFF_ACT_GeneralInterface_route)

	-- Wait for the "Puzzle complete" message
	if waitForPuzzleComplete() then
		-- Complete the clue step
		completeClueStep()
		return true
	else
		print("Failed to detect puzzle completion")
		return false
	end
end

-- Press the Check button to complete puzzle
function PuzzleModule.pressCheckButton()
	print("Pressing Check button...")
	API.DoAction_Interface(0x24, 0xffffffff, 1, 1931, 34, -1, API.OFF_ACT_GeneralInterface_route)

	-- Wait for the "Puzzle complete" message
	if waitForPuzzleComplete() then
		-- Complete the clue step
		completeClueStep()
		return true
	else
		print("Failed to detect puzzle completion")
		return false
	end
end

-- Debug function to print board state
local function printBoard(board)
	print("Current board state:")
	for y = 1, 5 do
		local row = ""
		for x = 1, 5 do
			local tile = board[y][x]
			if tile == 24 then
				row = row .. "[ ] "
			else
				row = row .. string.format("[%2d] ", tile)
			end
		end
		print(row)
	end
end

-- Check if puzzle is already solved
local function isPuzzleSolved(board)
	for y = 1, 5 do
		for x = 1, 5 do
			if board[y][x] ~= GOAL_STATE[y][x] then
				return false
			end
		end
	end
	return true
end

-- Simple test moves function
function PuzzleModule.testMoves()
	print("Testing puzzle moves...")
	local moves = { "left", "up", "right", "down" }

	for _, move in ipairs(moves) do
		print("Testing move:", move)
		local keycode = 0
		if move == "left" then
			keycode = 0x25
		elseif move == "up" then
			keycode = 0x26
		elseif move == "right" then
			keycode = 0x27
		elseif move == "down" then
			keycode = 0x28
		end

		if keycode > 0 then
			print("Sending keycode:", keycode)
			API.KeyboardPress2(keycode, 50, 60)
			API.RandomSleep2(1000, 500, 500)
		end
	end
end

-- Test single move
function PuzzleModule.testSingleMove(direction)
	print("Testing single move:", direction)
	local keycode = 0
	if direction == "left" then
		keycode = 0x25
	elseif direction == "up" then
		keycode = 0x26
	elseif direction == "right" then
		keycode = 0x27
	elseif direction == "down" then
		keycode = 0x28
	end

	if keycode > 0 then
		print("Sending keycode:", keycode)
		API.KeyboardPress2(keycode, 50, 60)
		API.RandomSleep2(500, 200, 200)
		return true
	end
	return false
end

-- Main solve function
function PuzzleModule.solvePuzzle(puzzleState, apiToken)
	-- If no puzzle state provided, try to extract it
	if not puzzleState then
		print("No puzzle state provided, attempting extraction...")
		puzzleState = PuzzleModule.extractPuzzleState()

		if not puzzleState then
			print("Primary extraction failed, trying fallback...")
			puzzleState = PuzzleModule.extractPuzzleStateFallback()
		end

		if not puzzleState then
			print("All extraction methods failed")
			return false
		end
	end

	print("Solving puzzle with state:", table.concat(puzzleState, ", "))
	local start_board = createBoardFromList(puzzleState)

	print("DEBUG: Created board from puzzle state")
	printBoard(start_board)

	-- Check if already solved
	if isPuzzleSolved(start_board) then
		print("Puzzle is already solved! Pressing Check button...")
		PuzzleModule.pressCheckButton()
		return true
	end

	print("Getting solution from API...")
	local moves = getPuzzleSolutionFromAPI(puzzleState, apiToken)

	if moves then
		print("Solution found! 🚀")
		print("Solution found with", #moves, "moves! Executing moves...")
		local success = executeMoves(moves)
		if success then
			print("Puzzle solved and clue step completed!")
			return true
		else
			print("Puzzle execution failed")
			return false
		end
	else
		print("No solution found from API")
		return false
	end
end

-- Check if puzzle interface is open
function PuzzleModule.isPuzzleOpen()
	-- local interface = API.ScanForInterfaceTest2Get(true, SLIDE_PUZZLE_PATH)
	-- local isOpen = interface and #interface > 0
	local isOpen = GetInterfaceOpenBySize(1931)

	if isOpen then
		print("Puzzle interface detected as open")
	else
		print("Puzzle interface not detected")
	end
	return isOpen
end

-- Knot puzzle interface detection and solving
local KNOT_INTERFACES = {
	{ { 526, 0, -1, 0 }, { 526, 8, -1, 0 } },
	{ { 1002, 0, -1, 0 }, { 1002, 8, -1, 0 } },
	{ { 1003, 0, -1, 0 }, { 1003, 8, -1, 0 } },
}

-- Map interface base IDs to their unlock button indices
local KNOT_UNLOCK_BUTTONS = {
	[394] = 17,
	[526] = 232,
	[1002] = 17,
	[1001] = 176,
	[519] = 176,
	[529] = 178,
	[525] = 214,
	[1003] = 204,
	[1000] = 190,
}

-- Map interface base IDs to their knot adjustment action indices
local KNOT_ACTIONS = {
	[394] = {
		gold = { down = 21, up = 22 },
		lightBlue = { down = 24, up = 23 },
		darkBlue = { down = 26, up = 25 },
		grey = { down = 28, up = 27 },
	},
	[519] = {
		gold = { down = 10, up = 11 },
		lightBlue = { down = 12, up = 13 },
		darkBlue = { down = 15, up = 14 },
		grey = { down = 17, up = 16 },
	},
	[525] = {
		gold = { down = 10, up = 11 },
		lightBlue = { down = 12, up = 13 },
		darkBlue = { down = 15, up = 14 },
		grey = { down = 17, up = 16 },
	},
	[526] = {
		gold = { down = 10, up = 11 },
		lightBlue = { down = 12, up = 13 },
		darkBlue = { down = 15, up = 14 },
		grey = { down = 17, up = 16 },
	},
	[529] = {
		gold = { down = 10, up = 11 },
		lightBlue = { down = 12, up = 13 },
		darkBlue = { down = 15, up = 14 },
		grey = { down = 17, up = 16 },
	},
	[1000] = {
		gold = { down = 10, up = 11 },
		lightBlue = { down = 12, up = 13 },
		darkBlue = { down = 15, up = 14 },
		grey = { down = 17, up = 16 },
	},
	[1001] = {
		gold = { down = 10, up = 11 },
		lightBlue = { down = 12, up = 13 },
		darkBlue = { down = 15, up = 14 },
		grey = { down = 17, up = 16 },
	},
	[1002] = {
		gold = { down = 21, up = 22 },
		lightBlue = { down = 24, up = 23 },
		darkBlue = { down = 26, up = 25 },
		grey = { down = 28, up = 27 },
	},
	[1003] = {
		gold = { down = 10, up = 11 },
		lightBlue = { down = 12, up = 13 },
		darkBlue = { down = 15, up = 14 },
		grey = { down = 17, up = 16 },
	},
}

-- Detect which knot puzzle interface is available
function PuzzleModule.detectKnotInterface()
	-- Check each known knot interface base ID
	local knot_base_ids = { 394, 525, 526, 529, 519, 1002, 1001, 1003, 1000 }

	for _, base_id in ipairs(knot_base_ids) do
		local isOpen = GetInterfaceOpenBySize(base_id)
		if isOpen then
			print("Detected knot puzzle interface with base ID:", base_id)
			return base_id
		end
	end
	print("No knot puzzle interface detected")
	return nil
end

-- Check if knot puzzle interface is open
function PuzzleModule.isKnotPuzzleOpen()
	local base_id = PuzzleModule.detectKnotInterface()
	return base_id ~= nil, base_id
end

-- Get knot puzzle values from varbits
local function getKnotValues()
	local gold = API.GetVarbitValue(4941)
	local lightBlue = API.GetVarbitValue(4942)
	local darkBlue = API.GetVarbitValue(4943)
	local grey = API.GetVarbitValue(4944)

	print("Knot values - Gold:", gold, "Light Blue:", lightBlue, "Dark Blue:", darkBlue, "Grey:", grey)
	return gold, lightBlue, darkBlue, grey
end

-- Check if knot puzzle is solved
local function isKnotSolved()
	local gold, lightBlue, darkBlue, grey = getKnotValues()
	return gold == 0 and lightBlue == 0 and darkBlue == 0 and grey == 0
end

-- Adjust knot value using dynamic interface
local function adjustKnotValue(base_id, color, direction)
	local actions = KNOT_ACTIONS[base_id]
	if not actions then
		print("ERROR: No action mapping found for base_id:", base_id)
		return false
	end

	local action = actions[color] and actions[color][direction]
	if action then
		print("Adjusting", color, direction, "- action:", action, "using base_id:", base_id)
		API.DoAction_Interface(0xffffffff, 0xffffffff, 1, base_id, action, -1, API.OFF_ACT_GeneralInterface_route)
		API.RandomSleep2(300, 200, 200)
		return true
	end
	return false
end

-- Solve knot puzzle with dynamic interface
function PuzzleModule.solveKnotPuzzle()
	print("Starting knot puzzle solving process...")

	local isOpen, base_id = PuzzleModule.isKnotPuzzleOpen()
	if not isOpen then
		print("Knot puzzle interface not open")
		return false
	end

	print("Solving knot puzzle with base interface ID:", base_id)

	local maxAttempts = 50 -- Prevent infinite loops
	local attempts = 0

	while attempts < maxAttempts and isOpen and API.Read_LoopyLoop() do
		attempts = attempts + 1

		if isKnotSolved() then
			local unlockButtonIndex = KNOT_UNLOCK_BUTTONS[base_id]
			print(
				"Knot puzzle solved - clicking Unlock button (interface:",
				base_id,
				"button index:",
				unlockButtonIndex,
				")"
			)
			API.DoAction_Interface(
				0x24,
				0xffffffff,
				1,
				base_id,
				unlockButtonIndex,
				-1,
				API.OFF_ACT_GeneralInterface_route
			)
			API.RandomSleep2(1000, 500, 500)

			-- Wait for success message
			local successDetected = false
			local waitAttempts = 0
			local maxWaitAttempts = 10

			while waitAttempts < maxWaitAttempts and not successDetected do
				waitAttempts = waitAttempts + 1
				local chatTexts = API.GatherEvents_chat_check()
				if chatTexts then
					for _, chatText in ipairs(chatTexts) do
						local text = chatText.text or chatText
						if type(text) == "string" and string.find(text, "You succeed!") then
							print("Knot puzzle unlock successful - 'You succeed!' message detected")
							successDetected = true
							break
						end
					end
				end
				if not successDetected then
					API.RandomSleep2(500, 300, 300)
				end
			end

			if successDetected then
				print("Knot puzzle completed successfully!")
				return true
			else
				print("Unlock button clicked but no success message detected")
				return true -- Still consider it successful since puzzle was solved
			end
		end

		local gold, lightBlue, darkBlue, grey = getKnotValues()

		-- Simple solving strategy: adjust each color to 0
		-- This is a basic approach - could be optimized with better algorithms
		if gold > 0 then
			adjustKnotValue(base_id, "gold", "up")
		elseif gold < 0 then
			adjustKnotValue(base_id, "gold", "down")
		elseif lightBlue > 0 then
			adjustKnotValue(base_id, "lightBlue", "up")
		elseif lightBlue < 0 then
			adjustKnotValue(base_id, "lightBlue", "down")
		elseif darkBlue > 0 then
			adjustKnotValue(base_id, "darkBlue", "up")
		elseif darkBlue < 0 then
			adjustKnotValue(base_id, "darkBlue", "down")
		elseif grey > 0 then
			adjustKnotValue(base_id, "grey", "up")
		elseif grey < 0 then
			adjustKnotValue(base_id, "grey", "down")
		else
			-- All values are 0, puzzle should be solved
			break
		end

		-- Small delay between attempts
		API.RandomSleep2(500, 300, 300)

		-- Check if interface is still open
		isOpen = PuzzleModule.isKnotPuzzleOpen()
	end

	if attempts >= maxAttempts then
		print("Knot puzzle solving failed - maximum attempts reached")
		return false
	end

	-- Final check and unlock if solved
	if isKnotSolved() then
		local unlockButtonIndex = KNOT_UNLOCK_BUTTONS[base_id]
		print(
			"Knot puzzle solved - clicking Unlock button (interface:",
			base_id,
			"button index:",
			unlockButtonIndex,
			")"
		)
		API.DoAction_Interface(0x24, 0xffffffff, 1, base_id, unlockButtonIndex, -1, API.OFF_ACT_GeneralInterface_route)
		API.RandomSleep2(1000, 500, 500)

		-- Wait for success message
		local successDetected = false
		local waitAttempts = 0
		local maxWaitAttempts = 10

		while waitAttempts < maxWaitAttempts and not successDetected do
			waitAttempts = waitAttempts + 1
			local chatTexts = API.GatherEvents_chat_check()
			if chatTexts then
				for _, chatText in ipairs(chatTexts) do
					local text = chatText.text or chatText
					if type(text) == "string" and string.find(text, "You succeed!") then
						print("Knot puzzle unlock successful - 'You succeed!' message detected")
						successDetected = true
						break
					end
				end
			end
			if not successDetected then
				API.RandomSleep2(500, 300, 300)
			end
		end

		if successDetected then
			print("Knot puzzle completed successfully!")
			return true
		else
			print("Unlock button clicked but no success message detected")
			return true -- Still consider it successful since puzzle was solved
		end
	end

	return false
end

-- Main entry point for solving puzzle boxes from clue solver
function PuzzleModule.solvePuzzleBox()
	print("Starting puzzle box solving process...")

	-- Check if puzzle interface is already open
	if not PuzzleModule.isPuzzleOpen() then
		print("Puzzle interface not open - may need to open puzzle box first")
		return false
	end

	-- Extract and solve the puzzle
	local success = PuzzleModule.solvePuzzle()

	if success then
		print("Puzzle box solved successfully!")
		return true
	else
		print("Failed to solve puzzle box")
		return false
	end
end

-- Main entry point for solving knot puzzles from clue solver
function PuzzleModule.solveKnotPuzzleBox()
	print("Starting knot puzzle solving process...")

	-- Check if knot puzzle interface is open
	local isOpen, base_id = PuzzleModule.isKnotPuzzleOpen()
	if not isOpen then
		print("Knot puzzle interface not open - may need to open puzzle first")
		return false
	end

	-- Solve the knot puzzle
	local success = PuzzleModule.solveKnotPuzzle()

	if success then
		print("Knot puzzle solved successfully!")
		return true
	else
		print("Failed to solve knot puzzle")
		return false
	end
end

-- Lockbox Puzzle Solver (Combat Styles Grid)
-- This solves a 5x5 grid where clicking tiles rotates them and adjacent tiles through 3 states
-- Goal: Make all tiles the same type

-- Tile IDs and rotation sequence: Sword -> Ranged -> Mage -> Sword
local LOCKBOX_TILE_IDS = {
	SWORD = 32272, -- State 0
	BOW = 32274, -- State 1 (Ranged)
	MAGIC = 32270, -- State 2
}

-- Convert tile ID to state (0, 1, 2) based on rotation sequence
local function lockboxTileToState(tileId)
	if tileId == LOCKBOX_TILE_IDS.SWORD then
		return 0
	elseif tileId == LOCKBOX_TILE_IDS.BOW then
		return 1
	elseif tileId == LOCKBOX_TILE_IDS.MAGIC then
		return 2
	end
	return -1
end

-- Read the current lockbox grid state and return grid + tile components
local function readLockboxGrid()
	local tiles = API.ScanForInterfaceTest2Get(true, {
		{ 1933, 26, -1, 0 },
		{ 1933, 28, -1, 0 },
		{ 1933, 30, -1, 0 },
	})

	local grid = {}
	local tileComponents = {}
	for i, v in ipairs(tiles) do
		local tileId = API.Mem_Read_int(v.memloc + API.I_slides)
		table.insert(grid, lockboxTileToState(tileId))
		tileComponents[i] = v
	end

	return grid, tileComponents
end

-- Get affected cells when clicking position (row, col)
-- Clicking affects the cell itself and adjacent cells (up, down, left, right)
local function getLockboxAffectedCells(row, col)
	local affected = {}
	local idx = (row - 1) * 5 + col
	table.insert(affected, idx)

	-- Up
	if row > 1 then
		table.insert(affected, (row - 2) * 5 + col)
	end
	-- Down
	if row < 5 then
		table.insert(affected, row * 5 + col)
	end
	-- Left
	if col > 1 then
		table.insert(affected, (row - 1) * 5 + col - 1)
	end
	-- Right
	if col < 5 then
		table.insert(affected, (row - 1) * 5 + col + 1)
	end

	return affected
end

-- Solve lockbox using Gaussian elimination over GF(3)
local function solveLockboxPuzzle(initialGrid)
	local n = 25 -- 5x5 grid

	-- Build the system of linear equations (mod 3)
	-- We want to find clicks such that all tiles end up at the same state
	local matrix = {}
	for i = 1, n do
		matrix[i] = {}
		for j = 1, n do
			matrix[i][j] = 0
		end
		matrix[i][n + 1] = 0 -- Augmented column
	end

	-- Fill the matrix based on click effects
	for clickPos = 1, n do
		local row = math.floor((clickPos - 1) / 5) + 1
		local col = ((clickPos - 1) % 5) + 1
		local affected = getLockboxAffectedCells(row, col)

		for _, cellIdx in ipairs(affected) do
			matrix[cellIdx][clickPos] = 1 -- Each click adds 1 (mod 3) to affected cells
		end
	end

	-- Set target: we want all cells to reach state 0 (or any uniform state)
	-- So we need to cancel out the initial state
	for i = 1, n do
		matrix[i][n + 1] = (3 - initialGrid[i]) % 3
	end

	-- Gaussian elimination (mod 3)
	for col = 1, n do
		-- Find pivot
		local pivotRow = nil
		for row = col, n do
			if matrix[row][col] % 3 ~= 0 then
				pivotRow = row
				break
			end
		end

		if not pivotRow then
			goto continue_lockbox
		end

		-- Swap rows
		if pivotRow ~= col then
			matrix[col], matrix[pivotRow] = matrix[pivotRow], matrix[col]
		end

		-- Make pivot = 1
		local pivot = matrix[col][col] % 3
		if pivot == 2 then
			-- Multiply row by 2 (since 2*2 = 4 = 1 mod 3)
			for j = 1, n + 1 do
				matrix[col][j] = (matrix[col][j] * 2) % 3
			end
		end

		-- Eliminate column
		for row = 1, n do
			if row ~= col then
				local factor = matrix[row][col] % 3
				if factor ~= 0 then
					for j = 1, n + 1 do
						matrix[row][j] = (matrix[row][j] - factor * matrix[col][j]) % 3
					end
				end
			end
		end

		::continue_lockbox::
	end

	-- Extract solution
	local solution = {}
	for i = 1, n do
		solution[i] = matrix[i][n + 1] % 3
	end

	return solution
end

-- Convert solution to click sequence
local function getLockboxClickSequence(solution)
	local clicks = {}
	for i = 1, 25 do
		local row = math.floor((i - 1) / 5) + 1
		local col = ((i - 1) % 5) + 1
		local numClicks = solution[i]

		for _ = 1, numClicks do
			table.insert(clicks, { row = row, col = col, index = i })
		end
	end
	return clicks
end

-- Execute clicks on the lockbox interface
local function executeLockboxClicks(clicks, tileComponents)
	print("Executing lockbox clicks...")
	for i, click in ipairs(clicks) do
		local tile = tileComponents[click.index]
		if tile then
			print(string.format("Click %d/%d: Row %d, Col %d (id2=%d)", i, #clicks, click.row, click.col, tile.id2))
			API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1933, tile.id2, -1, API.OFF_ACT_GeneralInterface_route)
			API.RandomSleep2(250, 250, 250)
		end
	end
	print("Lockbox puzzle solved!")
end

-- Check if lockbox interface is open
function PuzzleModule.isLockboxOpen()
	local isOpen = GetInterfaceOpenBySize(1933)
	if isOpen then
		print("Lockbox interface detected as open")
	else
		print("Lockbox interface not detected")
	end
	return isOpen
end

-- Main lockbox solver function
function PuzzleModule.solveLockbox(autoExecute)
	if autoExecute == nil then
		autoExecute = true
	end

	print("Starting lockbox puzzle solving process...")

	-- Check if lockbox interface is open
	if not PuzzleModule.isLockboxOpen() then
		print("Lockbox interface not open")
		return false
	end

	print("Reading lockbox grid...")
	local grid, tileComponents = readLockboxGrid()

	if not grid or #grid ~= 25 then
		print("Failed to read lockbox grid")
		return false
	end

	print("Current lockbox grid state:")
	for i = 1, 5 do
		local row = {}
		for j = 1, 5 do
			table.insert(row, grid[(i - 1) * 5 + j])
		end
		print(table.concat(row, " "))
	end

	print("Solving lockbox puzzle...")
	local solution = solveLockboxPuzzle(grid)
	local clicks = getLockboxClickSequence(solution)

	print("Solution found! Total clicks needed: " .. #clicks)

	if autoExecute then
		executeLockboxClicks(clicks, tileComponents)
		return true
	else
		print("Click sequence (row, col):")
		for _, click in ipairs(clicks) do
			print(string.format("Click tile at row %d, col %d", click.row, click.col))
		end
		return true
	end
end

-- Towers Puzzle Solver
-- Check if Towers puzzle interface is open
function PuzzleModule.isTowersPuzzleOpen()
	local isOpen = GetInterfaceOpenBySize(1934)
	if isOpen then
		print("Towers puzzle interface detected as open")
	else
		print("Towers puzzle interface not detected")
	end
	return isOpen
end

-- Fetch grid tiles from the game interface
local function fetchTowersGridTiles()
	local gridTiles = {}
	for i = 1, 5 do
		gridTiles[i] = {}
	end

	local parent = API.ScanForInterfaceTest2Get(
		true,
		{ { 1934, 8, -1, 0 }, { 1934, 10, -1, 0 }, { 1934, 17, -1, 0 }, { 1934, 6, -1, 0 } }
	)

	if #parent > 0 then
		local tiles = API.ScanForInterfaceTest2Get(true, {
			{ 1934, 8, -1, 0 },
			{ 1934, 10, -1, 0 },
			{ 1934, 17, -1, 0 },
			{ 1934, 6, -1, 0 },
			{ 1934, parent[1].id2, -1, 0 },
		})

		local idx = 1
		for row = 1, 5 do
			for col = 1, 5 do
				if idx <= #tiles then
					gridTiles[row][col] = tiles[idx].id3
					idx = idx + 1
				end
			end
		end
	end

	return gridTiles
end

-- Fetch clues dynamically from the game interface
local function fetchTowersClues()
	local clues = { top = {}, right = {}, bottom = {}, left = {} }

	local tiles = API.ScanForInterfaceTest2Get(
		true,
		{ { 1934, 8, -1, 0 }, { 1934, 10, -1, 0 }, { 1934, 17, -1, 0 }, { 1934, 20, -1, 0 } }
	)

	for tileIdx, v in ipairs(tiles) do
		local children = API.ScanForInterfaceTest2Get(true, {
			{ 1934, 8, -1, 0 },
			{ 1934, 10, -1, 0 },
			{ 1934, 17, -1, 0 },
			{ 1934, 20, -1, 0 },
			{ 1934, v.id2, -1, 0 },
		})

		local sideClues = {}
		for idx, vv in ipairs(children) do
			local clueText = API.ReadCharsLimit(vv.memloc + API.I_itemids3, 100)
			local clueValue = tonumber(clueText)
			if clueValue then
				table.insert(sideClues, clueValue)
			end
		end

		if tileIdx == 1 then
			clues.right = sideClues
		elseif tileIdx == 2 then
			clues.left = sideClues
		elseif tileIdx == 3 then
			clues.bottom = sideClues
		elseif tileIdx == 4 then
			clues.top = sideClues
		end
	end

	return clues
end

-- Check if a number can be placed at position (row, col)
local function isTowersValid(grid, row, col, num)
	for c = 1, 5 do
		if c ~= col and grid[row][c] == num then
			return false
		end
	end
	for r = 1, 5 do
		if r ~= row and grid[r][col] == num then
			return false
		end
	end
	return true
end

-- Count visible towers from a direction
local function countTowersVisible(sequence)
	local count = 0
	local maxHeight = 0
	for i = 1, #sequence do
		if sequence[i] > maxHeight then
			count = count + 1
			maxHeight = sequence[i]
		end
	end
	return count
end

-- Check if current grid state satisfies all visibility constraints
local function checkTowersConstraints(grid, clues)
	for i = 1, 5 do
		local row = {}
		local rowComplete = true
		for j = 1, 5 do
			row[j] = grid[i][j]
			if row[j] == 0 then
				rowComplete = false
			end
		end

		if rowComplete then
			if countTowersVisible(row) ~= clues.left[i] then
				return false
			end
			local reverseRow = {}
			for j = 1, 5 do
				reverseRow[j] = row[6 - j]
			end
			if countTowersVisible(reverseRow) ~= clues.right[i] then
				return false
			end
		end

		local col = {}
		local colComplete = true
		for j = 1, 5 do
			col[j] = grid[j][i]
			if col[j] == 0 then
				colComplete = false
			end
		end

		if colComplete then
			if countTowersVisible(col) ~= clues.top[i] then
				return false
			end
			local reverseCol = {}
			for j = 1, 5 do
				reverseCol[j] = col[6 - j]
			end
			if countTowersVisible(reverseCol) ~= clues.bottom[i] then
				return false
			end
		end
	end
	return true
end

-- Solve using backtracking
local function solveTowersBacktrack(grid, clues, row, col)
	if row > 5 then
		return checkTowersConstraints(grid, clues)
	end

	local nextRow, nextCol = row, col + 1
	if nextCol > 5 then
		nextRow, nextCol = row + 1, 1
	end

	for num = 1, 5 do
		if isTowersValid(grid, row, col, num) then
			grid[row][col] = num
			if checkTowersConstraints(grid, clues) then
				if solveTowersBacktrack(grid, clues, nextRow, nextCol) then
					return true
				end
			end
			grid[row][col] = 0
		end
	end
	return false
end

-- Place the solution in the game
local function placeTowersSolution(grid, gridTiles)
	print("Placing solution in game...")

	for row = 1, 5 do
		for col = 1, 5 do
			if not API.Read_LoopyLoop() then
				break
			end

			-- Check if interface is still open
			if not PuzzleModule.isTowersPuzzleOpen() then
				print("Towers puzzle interface closed during placement")
				return false
			end

			local value = grid[row][col]
			local tileId3 = gridTiles[row][col]

			if tileId3 and value > 0 then
				API.DoAction_Interface(
					0x2e,
					0xffffffff,
					value + 1,
					1934,
					7,
					tileId3,
					API.OFF_ACT_GeneralInterface_route
				)
				API.RandomSleep2(300, 300, 300)
			end
		end
	end

	-- Final check before clicking check button
	if not PuzzleModule.isTowersPuzzleOpen() then
		print("Towers puzzle interface closed before check button")
		return false
	end

	print("Solution placed! Clicking check button...")
	API.RandomSleep2(500, 750, 1000)
	API.DoAction_Interface(0x24, 0xffffffff, 1, 1934, 61, -1, API.OFF_ACT_GeneralInterface_route)
	API.RandomSleep2(1000, 1500, 2000)

	return true
end

-- Main Towers puzzle solver function
function PuzzleModule.solveTowersPuzzle()
	print("Starting Towers puzzle solving process...")

	if not PuzzleModule.isTowersPuzzleOpen() then
		print("Towers puzzle interface not open")
		return false
	end

	local clues = fetchTowersClues()
	local gridTiles = fetchTowersGridTiles()

	if #clues.top ~= 5 or #clues.right ~= 5 or #clues.bottom ~= 5 or #clues.left ~= 5 then
		print("ERROR: Invalid number of clues fetched!")
		return false
	end

	local grid = {}
	for i = 1, 5 do
		grid[i] = {}
		for j = 1, 5 do
			grid[i][j] = 0
		end
	end

	print("Solving Towers puzzle...")
	if solveTowersBacktrack(grid, clues, 1, 1) then
		print("Solution found!")
		local success = placeTowersSolution(grid, gridTiles)
		if success then
			print("Towers puzzle solved successfully!")
			return true
		else
			print("Failed to place solution correctly")
			return false
		end
	else
		print("No solution found!")
		return false
	end
end

return PuzzleModule
