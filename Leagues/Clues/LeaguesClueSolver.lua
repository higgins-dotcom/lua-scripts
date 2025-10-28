--[[
====================================================================================================
Easy, Medium, Hard & Elite Clue Scroll Solver
====================================================================================================
Version: 3.3
Author: Higgins
Description: Automatically solves easy, medium, hard, and elite clue scrolls using Globetrotter equipment

Requirements:
- Globetrotter jacket (for teleporting) - must be equipped and on action bar
- Globetrotter backpack (for clue swapping) - must be equipped and on action bar
- Easy, medium, hard, or elite clue scrolls or sealed clue scrolls

Configuration Options:
- HAS_FOOT_SHAPED_KEY_UNLOCK: Set to true if you have "Way of the foot-shaped key" unlock
  (allows skipping required items for medium clues and going straight to chests)
- ALLOW_WILDERNESS_TELEPORTS: Set to true to allow wilderness teleports
- ALLOW_REQUIRED_ITEM_CLUES: Set to true to handle clues requiring items from NPCs

How it works:
1. Opens sealed clue scrolls or scroll boxes
2. Identifies clue type (dig, scan, object interaction, NPC challenge, medium item requirement, puzzle box)
3. For medium clues: kills NPC to get required item OR skips to chest if foot-shaped key unlock is enabled
4. For hard/elite clues: solves puzzle boxes and knot puzzles automatically
5. For elite clues: handles scan clues using varbit coordinates (teleport and dig), knot puzzles, and reopens puzzle boxes/puzzle scroll boxes after completion
6. Teleports to location if needed
7. Completes the clue step
8. Auto-skips emote-based clues by swapping them
9. Handles other unsolvable clues by swapping them

====================================================================================================
]]
--

local API = require("API")
local PuzzleModule = require("PuzzleModule")

local SETTINGS = {
	PROXIMITY_THRESHOLD = 5,
	API_TOKEN = "dk_token_here", -- Add your API token here for puzzle solver authentication
	ALLOW_WILDERNESS_TELEPORTS = false, -- Set to true to allow wilderness teleports, false to swap wilderness clues
	ALLOW_REQUIRED_ITEM_CLUES = false, -- Set to true to handle clues requiring items from NPCs, false to swap them
	HAS_FOOT_SHAPED_KEY_UNLOCK = false, -- Set to true if you have "Way of the foot-shaped key" unlock (skips required items for medium clues)
}

-- Game constants (same for all players)
local GAME_CONSTANTS = {
	VB_DIALOGUE_STATE = 2874,
	VB_ELITE_DIG_COORDS = 1323,
}

-- Centralized state management object
local ClueState = {
	-- Metrics tracking
	metrics = {
		startTime = os.time(),
		startGP = 0,

		-- Clue counts
		easyCluesCompleted = 0,
		mediumCluesCompleted = 0,
		hardCluesCompleted = 0,
		eliteCluesCompleted = 0,
		totalCluesCompleted = 0,

		-- Clue types processed
		digClues = 0,
		objectClues = 0,
		npcClues = 0,
		mediumItemClues = 0,
		scanClues = 0,
		challengeScrolls = 0,

		-- Puzzle boxes
		puzzleBoxesSolved = 0,
		puzzleBoxesFailed = 0,

		-- Knot puzzles
		knotPuzzlesSolved = 0,
		knotPuzzlesFailed = 0,

		-- Skipped/swapped clues
		cluesSwapped = 0,
		blacklistedClues = 0,
		accessDeniedClues = 0,

		-- Items opened
		sealedCluesOpened = 0,
		scrollBoxesOpened = 0,

		-- Teleports
		teleportsUsed = 0,
	},

	-- State tracking to prevent duplicate metrics
	tracking = {
		lastProcessedClueId = nil,
		lastChallengeScrollId = nil,
		lastPuzzleBoxId = nil,
		processedClueTypes = {},
		hasSwappedThisClue = false,
		hasOpenedScrollThisLoop = false,
		hasTeleportedForMediumClue = false,
		hasTeleportedForEliteClue = false,
	},

	-- Global chat event flags (reset each loop)
	chat = {
		accessDenied = false,
		digFailure = false,
		puzzleIncomplete = false,
		clueCompleted = false,
		clueCompletionType = nil,
	},

	-- Puzzle state
	puzzles = {
		completed = {}, -- Track completed puzzle boxes to avoid re-solving them
		attempts = {}, -- Track puzzle solve attempts per puzzle box
	},

	-- Reset tracking state (called when clue completes)
	resetTracking = function(self)
		self.tracking.processedClueTypes = {}
		self.tracking.hasSwappedThisClue = false
		self.tracking.lastProcessedClueId = nil
		self.tracking.lastChallengeScrollId = nil
		self.tracking.lastPuzzleBoxId = nil
		self.tracking.hasTeleportedForMediumClue = false
		self.tracking.hasTeleportedForEliteClue = false
		self.puzzles.attempts = {}
		print("State tracking and puzzle attempts reset")
	end,

	-- Reset chat flags (called at start of loop)
	resetChatFlags = function(self)
		self.chat.accessDenied = false
		self.chat.digFailure = false
		self.chat.puzzleIncomplete = false
		self.chat.clueCompleted = false
		self.chat.clueCompletionType = nil
	end,
}

-- Backward compatibility aliases (to minimize changes)
local metrics = ClueState.metrics
local stateTracking = ClueState.tracking
local chatFlags = ClueState.chat
local completedPuzzleBoxes = ClueState.puzzles.completed
local puzzleAttempts = ClueState.puzzles.attempts

-- Initialize starting GP
local function initializeMetrics()
	local gpSetting = API.VB_FindPSettinOrder(995) -- GP setting ID
	if gpSetting then
		metrics.startGP = gpSetting.state
	end
end

-- Forward declarations (defined later in the file)
local updateClueCompletionMetrics
local handleBadClue

-- Action result pattern for standardized handler returns
local ActionResult = {
	-- Create a success result
	success = function(action, shouldContinue)
		return {
			success = true,
			shouldContinue = shouldContinue ~= false, -- default true
			action = action or "completed",
		}
	end,

	-- Create a failure result
	failure = function(action, shouldContinue)
		return {
			success = false,
			shouldContinue = shouldContinue ~= false, -- default true
			action = action or "failed",
		}
	end,

	-- Create a continue result (for actions that need more processing)
	continue = function(action)
		return {
			success = true,
			shouldContinue = true,
			action = action or "continue",
		}
	end,

	-- Create a swap result (clue needs to be swapped)
	swap = function(reason)
		return {
			success = false,
			shouldContinue = true,
			action = "swap",
			reason = reason or "unknown",
		}
	end,

	-- Check if result indicates success
	isSuccess = function(result)
		return result and result.success == true
	end,

	-- Check if should continue processing
	shouldContinue = function(result)
		return result and result.shouldContinue == true
	end,
}

-- Chat message patterns for detection
local CHAT_PATTERNS = {
	ACCESS_DENIED = "You currently do not have access",
	DIG_FAILURE = {
		"You dig at this spot, but you find nothing",
		"You dig at this spot but you find nothing",
		"find nothing",
		"nothing interesting happens",
	},
	PUZZLE_INCOMPLETE = "Please finish the puzzle for me",
	CLUE_COMPLETE = "Congratulations! You have now completed",
	DIG_ACTION = "You dig",
	SEARCH_ACTION = "You search",
	CLUE_TYPES = {
		ELITE = "elite",
		HARD = "hard",
		MEDIUM = "medium",
		EASY = "easy",
	},
}

-- Equipment Functions
local function checkForAccessDenied()
	return chatFlags.accessDenied
end

local function checkForDigFailure()
	return chatFlags.digFailure
end

-- Helper to check if text matches any pattern in a list
local function matchesAnyPattern(text, patterns)
	if type(patterns) == "string" then
		return string.find(text, patterns) ~= nil
	end
	for _, pattern in ipairs(patterns) do
		if string.find(text, pattern) then
			return true
		end
	end
	return false
end

-- NPC interaction helper function
local function interactWithNpc(npc)
	if npc.Name == "Hans" or npc.Name == "Captain Bleemadge" or npc.Name == "Ysondria" then
		print("Hardcoded Talk To ", npc.Name)
		DoAction_NPC__Direct(0x2c, API.OFF_ACT_InteractNPC_route, npc)
		API.RandomSleep2(1200, 600, 600)
	else
		print("Interacting with NPC:", npc.Name)
		Interact:NPC(npc.Name, npc.Action, 30)
	end
end

-- Centralized chat event handler - processes all chat events once per loop
-- resetFlags: if true, resets all flags before processing (default true for start of loop)
local function processChatEvents(resetFlags)
	if resetFlags == nil then
		resetFlags = true
	end

	-- Reset flags only if requested (typically at start of loop)
	if resetFlags then
		ClueState:resetChatFlags()
	end

	local chatTexts = API.GatherEvents_chat_check()
	if not chatTexts then
		return
	end

	for _, chatText in ipairs(chatTexts) do
		local text = chatText.text or chatText
		if type(text) ~= "string" then
			goto continue_chat
		end

		-- Check for access denied
		if matchesAnyPattern(text, CHAT_PATTERNS.ACCESS_DENIED) then
			print("Chat: Access denied detected")
			ClueState.chat.accessDenied = true
			ClueState.metrics.accessDeniedClues = ClueState.metrics.accessDeniedClues + 1
		end

		-- Check for dig failure
		if matchesAnyPattern(text, CHAT_PATTERNS.DIG_FAILURE) then
			print("Chat: Dig failure detected")
			ClueState.chat.digFailure = true
		end

		-- Check for puzzle incomplete dialogue
		if matchesAnyPattern(text, CHAT_PATTERNS.PUZZLE_INCOMPLETE) then
			print("Chat: Puzzle incomplete dialogue detected")
			ClueState.chat.puzzleIncomplete = true
			local puzzleBoxId = hasPuzzleBox()
			if puzzleBoxId then
				ClueState.puzzles.completed[puzzleBoxId] = nil
				print("Removed puzzle box", puzzleBoxId, "from completed list due to NPC dialogue")
			end
		end

		-- Check for clue completion
		if matchesAnyPattern(text, CHAT_PATTERNS.CLUE_COMPLETE) then
			print("Chat: Clue completion detected:", text)
			ClueState.chat.clueCompleted = true

			-- Determine clue type from the message (check most specific first)
			local textLower = text:lower()
			if string.find(textLower, CHAT_PATTERNS.CLUE_TYPES.ELITE) then
				ClueState.chat.clueCompletionType = CHAT_PATTERNS.CLUE_TYPES.ELITE
			elseif string.find(textLower, CHAT_PATTERNS.CLUE_TYPES.HARD) then
				ClueState.chat.clueCompletionType = CHAT_PATTERNS.CLUE_TYPES.HARD
			elseif string.find(textLower, CHAT_PATTERNS.CLUE_TYPES.MEDIUM) then
				ClueState.chat.clueCompletionType = CHAT_PATTERNS.CLUE_TYPES.MEDIUM
			elseif string.find(textLower, CHAT_PATTERNS.CLUE_TYPES.EASY) then
				ClueState.chat.clueCompletionType = CHAT_PATTERNS.CLUE_TYPES.EASY
			else
				ClueState.chat.clueCompletionType = "unknown"
			end

			updateClueCompletionMetrics(ClueState.chat.clueCompletionType)

			-- Reset state tracking when a clue is completed
			ClueState:resetTracking()
		end

		-- Log other useful messages
		if matchesAnyPattern(text, CHAT_PATTERNS.DIG_ACTION) then
			print("Chat: Dig action detected")
		elseif matchesAnyPattern(text, CHAT_PATTERNS.SEARCH_ACTION) then
			print("Chat: Search action detected")
		end

		::continue_chat::
	end
end

-- Format numbers with commas
local function formatNumber(num)
	if not num or num == 0 then
		return "0"
	end
	local formatted = tostring(num)
	local k
	while true do
		formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", "%1,%2")
		if k == 0 then
			break
		end
	end
	return formatted
end

local function teleportWithJacket()
	print("Teleporting with Globetrotter jacket")
	ClueState.metrics.teleportsUsed = ClueState.metrics.teleportsUsed + 1
	print("Teleport metrics updated")
	API.DoAction_Ability("Globetrotter jacket", 1, API.OFF_ACT_GeneralInterface_route)
	API.RandomSleep2(600, 600, 600)

	-- Process chat events to check for access denied message after teleport (don't reset flags)
	processChatEvents(false)

	-- Check if teleport was denied due to access restrictions
	if checkForAccessDenied() then
		return handleBadClue()
	end
	return ActionResult.success("teleport")
end

-- Calculate and display metrics
local function calculateMetrics()
	local currentGP = 0
	local gpSetting = API.VB_FindPSettinOrder(995) -- GP setting ID
	if gpSetting then
		currentGP = gpSetting.state
	end

	local gpGained = currentGP - metrics.startGP
	local timeElapsed = os.time() - metrics.startTime
	local gpPH = timeElapsed > 0 and math.floor((gpGained * 3600) / timeElapsed) or 0
	local cluesPerHour = timeElapsed > 0 and math.floor((metrics.totalCluesCompleted * 3600) / timeElapsed) or 0

	local metricsTable = {
		{ "=== CLUE SOLVER METRICS ===", "" },
		{ "__HEADER__Statistics" },
		{
			"Runtime:",
			string.format("%d:%02d:%02d", timeElapsed // 3600, (timeElapsed % 3600) // 60, timeElapsed % 60),
		},
		{ "GP Gained:", formatNumber(gpGained) .. " (" .. formatNumber(gpPH) .. "/h)" },
		{ "__HEADER__Clues" },
		{ "=== CLUES COMPLETED ===", "" },
		{ "Total Clues:", formatNumber(metrics.totalCluesCompleted) .. " (" .. cluesPerHour .. "/h)" },
		{ "Easy Clues:", formatNumber(metrics.easyCluesCompleted) },
		{ "Medium Clues:", formatNumber(metrics.mediumCluesCompleted) },
		{ "Hard Clues:", formatNumber(metrics.hardCluesCompleted) },
		{ "Elite Clues:", formatNumber(metrics.eliteCluesCompleted) },
		{ "__HEADER__Types" },
		{ "=== CLUE TYPES ===", "" },
		{ "Dig Clues:", formatNumber(metrics.digClues) },
		{ "Object Clues:", formatNumber(metrics.objectClues) },
		{ "NPC Clues:", formatNumber(metrics.npcClues) },
		{ "Medium Item Clues:", formatNumber(metrics.mediumItemClues) },
		{ "Scan Clues:", formatNumber(metrics.scanClues) },
		{ "Challenge Scrolls:", formatNumber(metrics.challengeScrolls) },
		{ "__HEADER__Puzzles" },
		{ "=== PUZZLE BOXES ===", "" },
		{ "Solved:", formatNumber(metrics.puzzleBoxesSolved) },
		{ "Failed:", formatNumber(metrics.puzzleBoxesFailed) },
		{ "__HEADER__Knots" },
		{ "=== KNOT PUZZLES ===", "" },
		{ "Solved:", formatNumber(metrics.knotPuzzlesSolved) },
		{ "Failed:", formatNumber(metrics.knotPuzzlesFailed) },
		{ "__HEADER__Extra" },
		{ "=== ITEMS OPENED ===", "" },
		{ "Sealed Clues:", formatNumber(metrics.sealedCluesOpened) },
		{ "Scroll Boxes:", formatNumber(metrics.scrollBoxesOpened) },
		{ "=== SKIPPED/SWAPPED ===", "" },
		{ "Total Swapped:", formatNumber(metrics.cluesSwapped) },
		{ "Blacklisted:", formatNumber(metrics.blacklistedClues) },
		{ "Access Denied:", formatNumber(metrics.accessDeniedClues) },
		{ "=== OTHER ===", "" },
		{ "Teleports Used:", formatNumber(metrics.teleportsUsed) },
	}

	return metricsTable
end

-- Generic metrics tracking function - DRY refactoring
local function trackMetric(metricType, key, increment)
	increment = increment or 1
	if not stateTracking.processedClueTypes[key] then
		metrics[metricType] = metrics[metricType] + increment
		stateTracking.processedClueTypes[key] = true
		print(metricType .. " metrics updated")
		return true
	end
	return false
end

-- Update clue completion metrics
updateClueCompletionMetrics = function(clueType)
	metrics.totalCluesCompleted = metrics.totalCluesCompleted + 1

	if clueType == "easy" then
		metrics.easyCluesCompleted = metrics.easyCluesCompleted + 1
	elseif clueType == "medium" then
		metrics.mediumCluesCompleted = metrics.mediumCluesCompleted + 1
	elseif clueType == "hard" then
		metrics.hardCluesCompleted = metrics.hardCluesCompleted + 1
	elseif clueType == "elite" then
		metrics.eliteCluesCompleted = metrics.eliteCluesCompleted + 1
	end
	-- Note: "unknown" type just increments total without specific type

	print("Clue completed! Total:", metrics.totalCluesCompleted, "Type:", clueType)
end

local function hasPuzzleBox()
	local inv = Inventory:GetItems()
	for _, item in ipairs(inv) do
		if
			item.name
			and (
				string.find(item.name, "Puzzle box %(hard%)")
				or string.find(item.name, "Puzzle box %(elite%)")
				or string.find(item.name, "Puzzle scroll box %(elite%)")
			)
		then
			print("Found puzzle box with ID:", item.id, "Name:", item.name)
			return item.id, item.name
		end
	end
	return false
end

-- Clean up completed puzzle boxes that are no longer in inventory
local function cleanupCompletedPuzzleBoxes()
	local currentPuzzleBoxId = hasPuzzleBox()
	local toRemove = {}

	-- Check each completed puzzle box
	for puzzleBoxId, _ in pairs(completedPuzzleBoxes) do
		-- If this completed puzzle box is not the current one in inventory, remove it
		if puzzleBoxId ~= currentPuzzleBoxId then
			table.insert(toRemove, puzzleBoxId)
		end
	end

	-- Remove completed puzzle boxes that are no longer in inventory
	for _, puzzleBoxId in ipairs(toRemove) do
		completedPuzzleBoxes[puzzleBoxId] = nil
		print("Cleaned up completed puzzle box ID:", puzzleBoxId, "(no longer in inventory)")
	end

	-- Also clean up attempt counters for puzzle boxes no longer in inventory
	if puzzleAttempts then
		local toRemoveAttempts = {}
		for puzzleBoxId, _ in pairs(puzzleAttempts) do
			if puzzleBoxId ~= currentPuzzleBoxId then
				table.insert(toRemoveAttempts, puzzleBoxId)
			end
		end

		for _, puzzleBoxId in ipairs(toRemoveAttempts) do
			puzzleAttempts[puzzleBoxId] = nil
			print("Cleaned up attempt counter for puzzle box ID:", puzzleBoxId, "(no longer in inventory)")
		end
	end
end

-- Challenge scroll item ID to answer mappings
local CHALLENGE_SCROLL_ANSWERS = {
	[7273] = 33, -- Cap'n Izzy No-Beard's parrot - "How many banana trees are there in the plantation?"
	[7271] = 13, -- Bolkoy - "How many flowers are there in the clearing below this platform?" = 13
	[33285] = 10, -- Nails Newton
	[7283] = 3, -- Edmon
	[33291] = 7, -- Rommik
	[2852] = 48, -- Oracle
	[7275] = 4, -- Brundt
	[7277] = 11, -- Gabooty
	[2842] = 6859, -- Hazelmere
	[33287] = 8, -- Ysondria
	[2844] = 7, -- Cook
	[33293] = 7, -- Moldark 7 or 3
	[7285] = 24, -- King Roald
	[7279] = 20, -- Recruiter
	[33289] = 17, -- Valerio
	[2850] = 5, -- Karim
	-- Add more challenge scroll IDs and their answers as needed:
	-- Gnome Coach - "How many gnomes on the gnome ball field have red patches on their uniforms?" = 6
	-- [itemId] = answer,
}

-- Blacklisted clue item IDs that should be automatically swapped
local BLACKLISTED_CLUES = {
	[7268] = true, -- Add clue item IDs that should be swapped
	[3579] = true,
	[3564] = true,
	[2853] = true, -- Gnome Ref
	-- Add more blacklisted clue IDs as needed:
	-- [itemId] = true,
}

local ITEM_IDS = {
	SEALED_EASY = 42006,
	SEALED_MEDIUM = 42007,
	SEALED_HARD = 42008,
	SEALED_ELITE = 42009,
}

local CLUE_PARAMS = {
	DIG = 4681,
	OBJECT = 4682,
	NPC = 4683,
	REQUIRED_ITEM = 4685,
	SCAN = 235,
}

local INTERFACE_IDS = {
	OPTION_CHECK = { { 1188, 5, -1, -1, 0 }, { 1188, 3, -1, 5, 0 }, { 1188, 3, 14, 3, 0 } },
}

local REQUIRED_ABILITIES = {
	{ name = "Globetrotter jacket", action = "Activate" },
	{ name = "Globetrotter backpack", action = "Swap clue" },
}

local function getCoordsFromParam(param)
	local x = (param >> 14) & (1 << 14) - 1
	local y = param & (1 << 14) - 1
	return { x, y }
end

local function isPlayerClose(targetCoords, threshold)
	threshold = threshold or SETTINGS.PROXIMITY_THRESHOLD
	local playerCoords = API.PlayerCoordfloat()
	local distance = math.sqrt((targetCoords[1] - playerCoords.x) ^ 2 + (targetCoords[2] - playerCoords.y) ^ 2)
	return distance <= threshold
end

-- Unified coordinate-based clue handler - DRY refactoring
local function handleLocationBasedClue(coords, action, clueId, clueType)
	local clueKey = clueType .. "_" .. coords[1] .. "_" .. coords[2]
	trackMetric(clueType .. "Clues", clueKey)

	if isPlayerClose(coords) then
		print("Player is close to " .. clueType .. " coordinates")
		return action(clueId, coords)
	else
		print("Player needs to move closer to " .. clueType .. " coordinates")
		return teleportWithJacket()
	end
end

local function isClueBlacklisted(clueId)
	if BLACKLISTED_CLUES[clueId] then
		print("Clue ID", clueId, "is blacklisted and will be swapped")
		-- Track metrics using unified system
		local clueKey = "blacklisted_" .. clueId
		trackMetric("blacklistedClues", clueKey)
		return true
	end
	return false
end

-- Standardized clue processing wrapper - DRY refactoring
local function processClueWithHandler(clueId, clueType, handler)
	if clueId and isClueBlacklisted(clueId) then
		return handleBadClue()
	end

	local item = Item:Get(clueId)
	if not item then
		return false
	end

	return handler(item, clueId)
end

local function openGlobetrotterBackpack()
	print("Opening Globetrotter backpack")
	API.DoAction_Ability("Globetrotter backpack", 1, API.OFF_ACT_GeneralInterface_route)
	API.RandomSleep2(500, 500, 500)
end

local function hasOption()
	local option = API.ScanForInterfaceTest2Get(false, INTERFACE_IDS.OPTION_CHECK)
	if #option > 0 and #option[1].textids > 0 then
		return option[1].textids
	end
	return false
end

local function hasChallengeScroll()
	local inv = Inventory:GetItems()
	for _, item in ipairs(inv) do
		if item.name and string.find(item.name, "Challenge scroll") then
			print("Found challenge scroll with ID:", item.id)
			return item.id
		end
	end
	return false
end

-- Generic clue detection function - DRY refactoring
local function findClueByType(clueType)
	local inv = Inventory:GetItems()
	local pattern = "Clue scroll %(" .. clueType .. "%)"
	for _, item in ipairs(inv) do
		if item.name and string.find(item.name, pattern) then
			return item.id
		end
	end
	return false
end

-- Convenience functions using the generic finder
local function hasEasyClue()
	return findClueByType("easy")
end

local function hasMediumClue()
	return findClueByType("medium")
end

local function hasHardClue()
	return findClueByType("hard")
end

local function hasEliteClue()
	return findClueByType("elite")
end

local function findNpc(npcId)
	local npcs = API.ReadAllObjectsArray({ 1 }, { -1 }, {})
	for _, npc in pairs(npcs) do
		if npc.Id == npcId then
			print("Found NPC:", npc.Id, "Name:", npc.Name)
			return npc
		end
	end
	print("NPC with ID", npcId, "not found")
	return nil
end

-- Challenge scroll answer input helper
local function inputChallengeAnswer(answer)
	print("Challenge dialogue detected, providing answer:", answer)
	API.TypeOnkeyboard(answer)
	API.RandomSleep2(1000, 500, 2000)
	API.KeyboardPress31(0x0D, 60, 100)
	API.RandomSleep2(1000, 500, 500)
	return true
end

-- Find and interact with NPC from current clue
local function findAndInteractWithClueNpc()
	print("Need to talk to NPC from current clue to initiate challenge dialogue")

	-- Find the current clue and get the NPC from it
	local currentClueId = hasHardClue() or hasMediumClue() or hasEasyClue()

	if currentClueId then
		local item = Item:Get(currentClueId)
		if item and item:HasParam(CLUE_PARAMS.NPC) then
			local npcId = item:GetParam(CLUE_PARAMS.NPC)
			print("Found NPC ID from clue:", npcId)

			local npc = findNpc(npcId)
			if npc then
				interactWithNpc(npc)
				return true
			else
				print("NPC not found nearby, may need to teleport")
				return false
			end
		else
			print("Current clue does not have NPC parameter")
			return false
		end
	else
		print("No current clue found to get NPC from")
		return false
	end
end

local function handleChallengeScroll()
	print("Handling challenge scroll")

	local challengeScrollId = hasChallengeScroll()
	if not challengeScrollId then
		print("No challenge scroll found")
		return false
	end

	-- Track metrics using unified system (but keep the special lastChallengeScrollId check)
	if stateTracking.lastChallengeScrollId ~= challengeScrollId then
		metrics.challengeScrolls = metrics.challengeScrolls + 1
		stateTracking.lastChallengeScrollId = challengeScrollId
		print("New challenge scroll detected, metrics updated")
	end

	-- Check if we have the answer for this challenge scroll
	local answer = CHALLENGE_SCROLL_ANSWERS[challengeScrollId]
	if not answer then
		print("No answer found for challenge scroll ID:", challengeScrollId)
		return false
	end

	print("Challenge scroll ID:", challengeScrollId, "Answer:", answer)

	-- Check if dialogue is open (VB_DIALOGUE_STATE = 10 means dialogue is active)
	local dialogueState = API.VB_FindPSettinOrder(GAME_CONSTANTS.VB_DIALOGUE_STATE)
	if dialogueState and dialogueState.state == 10 then
		return inputChallengeAnswer(answer)
	else
		print("No challenge dialogue detected, dialogue state:", dialogueState and dialogueState.state or "nil")
		return findAndInteractWithClueNpc()
	end
end

handleBadClue = function()
	print("Handling bad/unsolvable clue")

	-- Track metrics using unified system (but keep the special hasSwappedThisClue check)
	if not ClueState.tracking.hasSwappedThisClue then
		ClueState.metrics.cluesSwapped = ClueState.metrics.cluesSwapped + 1
		ClueState.tracking.hasSwappedThisClue = true
		print("Clue swap metrics updated")
	end

	local dialogueState = API.VB_FindPSettinOrder(GAME_CONSTANTS.VB_DIALOGUE_STATE)

	if dialogueState then
		local state = dialogueState.state
		print("Dialogue state:", state)

		if state == 12 then
			local option = hasOption()
			if option and option == "Swap your clue for a new one?" then
				print("Swapping clue for new one")
				API.Select_Option("Yes, swap it.")
				return ActionResult.swap("user_initiated")
			else
				print("Pressing space to continue dialog")
				API.KeyboardPress2(0x20, 60, 100)
				API.RandomSleep2(200, 200, 200)
				return ActionResult.continue("dialogue")
			end
		else
			openGlobetrotterBackpack()
			return ActionResult.continue("opening_backpack")
		end
	else
		print("Clue state not found, opening Globetrotter backpack")
		openGlobetrotterBackpack()
		return ActionResult.continue("opening_backpack")
	end
end

local function hasScrollBox()
	local inv = Inventory:GetItems()
	for _, item in ipairs(inv) do
		-- Check for item ID 19040 first
		if item.id == 19040 then
			print("Found special scroll item with ID:", item.id)
			return item.id
		end
		-- Check for regular scroll boxes by name
		if
			item.name
			and (
				string.find(item.name, "Scroll box %(easy%)")
				or string.find(item.name, "Scroll box %(medium%)")
				or string.find(item.name, "Scroll box %(hard%)")
				or string.find(item.name, "Scroll box %(elite%)")
			)
		then
			return item.id
		end
	end
	return false
end

local function getObjectAtCoords(coords)
	local objs = API.ReadAllObjectsArray({ 0, 12 }, { -1 }, {})
	for _, obj in pairs(objs) do
		if obj.CalcX == coords[1] and obj.CalcY == coords[2] and string.len(obj.Action) > 0 then
			print("Found object:", obj.Id, obj.Action)
			return obj
		end
	end
	return nil
end

local function hasRequiredItem(itemId)
	local inv = Inventory:GetItems()
	for _, item in ipairs(inv) do
		if item.id == itemId then
			return true
		end
	end
	return false
end

local function findSearchableObjects()
	local objs = API.ReadAllObjectsArray({ 0, 12 }, { -1 }, {})
	local searchableObjs = {}

	for _, obj in pairs(objs) do
		local action = obj.Action or ""
		if string.find(action:lower(), "search") or string.find(action:lower(), "open") then
			table.insert(searchableObjs, obj)
			print("Found searchable object:", obj.Id, obj.Name, "Action:", action)
		end
	end

	return searchableObjs
end

-- Object interaction function for unified handler
local function performObjectAction(clueId, coords)
	print("Player is close to object coordinates")
	local obj = getObjectAtCoords(coords)
	if obj then
		print("Interacting with object:", obj.Id, obj.Action)
		Interact:Object(obj.Name, obj.Action, 2)
		return true
	else
		print("Object not found at coordinates")
		return true
	end
end

local function handleObjectClue(item)
	print("Handling object clue")
	local coords = getCoordsFromParam(item:GetParam(CLUE_PARAMS.OBJECT))
	print("Object coordinates:", coords[1], coords[2])

	return handleLocationBasedClue(coords, performObjectAction, nil, "object")
end

local function handleNpcClue(item)
	print("Handling NPC clue")

	-- First check if we actually have a challenge scroll in inventory
	local challengeScrollId = hasChallengeScroll()
	if challengeScrollId then
		print("Challenge scroll found in inventory - handling as challenge scroll")
		return handleChallengeScroll()
	end

	-- This is a regular NPC interaction, not a challenge
	print("No challenge scroll found - handling as regular NPC interaction")
	local npcId = item:GetParam(CLUE_PARAMS.NPC)
	print("Target NPC ID:", npcId)

	-- Track metrics using unified system
	local clueKey = "npc_" .. npcId
	trackMetric("npcClues", clueKey)

	local npc = findNpc(npcId)
	if npc then
		interactWithNpc(npc)
	else
		print("NPC not found nearby, teleporting with jacket")
		local teleportSuccess = teleportWithJacket()
		if not teleportSuccess then
			return false -- Clue was swapped due to access denial
		end
	end
	return true
end

-- Dig action function for unified handler
local function performDigAction(clueId, coords)
	print("Player is close to dig coordinates, digging")
	API.DoAction_Inventory1(clueId, 0, 2, API.OFF_ACT_GeneralInterface_route)
	API.RandomSleep2(600, 600, 600)

	-- Check if dig failed (found nothing)
	if checkForDigFailure() then
		print("Dig failed - teleporting to correct location")
		return teleportWithJacket()
	end
	return ActionResult.success("dig")
end

local function handleDigClue(item, clueId)
	print("Handling dig clue")
	local coords = getCoordsFromParam(item:GetParam(CLUE_PARAMS.DIG))
	print("Dig coordinates:", coords[1], coords[2])

	local result = handleLocationBasedClue(coords, performDigAction, clueId, "dig")
	-- handleLocationBasedClue returns boolean, convert to ActionResult
	return result and ActionResult.success("dig_clue") or ActionResult.continue("dig_clue")
end

-- Elite scan dig action function
local function performEliteScanAction(clueId, coords, actionType)
	print("Already teleported for elite clue, digging")
	API.DoAction_Inventory1(clueId, 0, actionType or 2, API.OFF_ACT_GeneralInterface_route)
	API.RandomSleep2(600, 600, 600)

	-- Wait a bit more for chat message to appear, then check if dig failed
	API.RandomSleep2(500, 200, 200)
	if checkForDigFailure() then
		print("Elite scan dig failed - teleporting again")
		return teleportWithJacket()
	end
	return true
end

-- Elite teleport and access check helper
local function handleEliteTeleport()
	print("Player needs to teleport for elite scan clue")
	local result = teleportWithJacket()
	if not ActionResult.isSuccess(result) then
		return result
	end
	ClueState.tracking.hasTeleportedForEliteClue = true
	print("Marked elite clue as teleported")

	-- Wait for potential access denied message and process chat events (don't reset flags)
	API.RandomSleep2(1000, 500, 500)
	processChatEvents(false)

	if checkForAccessDenied() then
		print("Access denied detected after elite teleport - swapping clue")
		return handleBadClue()
	end
	return ActionResult.success("elite_teleport")
end

local function handleScanClue(item, clueId)
	print("Handling scan clue (Elite)")

	-- Check VB_ELITE_DIG_COORDS for Elite dig coordinates
	local eliteDig = API.VB_FindPSett(GAME_CONSTANTS.VB_ELITE_DIG_COORDS)
	local coords, actionType

	if not eliteDig or eliteDig.state <= 0 then
		print("No Elite dig coordinates found in VB_ELITE_DIG_COORDS, using scan param as fallback")
		coords = getCoordsFromParam(item:GetParam(CLUE_PARAMS.SCAN))
		actionType = 3
		print("Fallback scan coordinates:", coords[1], coords[2])
	else
		-- Use VB_ELITE_DIG_COORDS packed coordinates for Elite dig
		coords = getCoordsFromParam(eliteDig.state)
		actionType = 2
		print("Elite dig coordinates from VB_ELITE_DIG_COORDS:", coords[1], coords[2])
	end

	-- Track metrics using unified system
	local clueKey = "scan_" .. coords[1] .. "_" .. coords[2]
	trackMetric("scanClues", clueKey)

	if stateTracking.hasTeleportedForEliteClue then
		return performEliteScanAction(clueId, coords, actionType)
	else
		return handleEliteTeleport()
	end
end

-- Medium clue search helper function
local function searchForMediumClueObjects()
	local searchableObjs = findSearchableObjects()

	if #searchableObjs > 0 then
		-- Try each searchable object until we find the right one
		for _, obj in ipairs(searchableObjs) do
			print("Trying to interact with:", obj.Name, "Action:", obj.Action)
			Interact:Object(obj.Name, obj.Action, 10)
			API.RandomSleep2(600, 800, 800) -- Wait to see if clue progresses

			-- Check if clue state changed (could add more sophisticated checking here)
			local dialogueState = API.VB_FindPSettinOrder(GAME_CONSTANTS.VB_DIALOGUE_STATE)
			if dialogueState and dialogueState.state ~= 12 then
				print("Clue seems to have progressed")
				return true
			end
		end
		print("No searchable objects worked after teleport")
	else
		print("No searchable objects found after teleport - may need to wait or try again")
	end
	return false
end

-- Medium clue NPC attack helper function
local function attackNpcForItem(npcId)
	local npc = findNpc(npcId)
	if npc then
		print("Attacking NPC:", npc.Name, "to get required item")
		API.DoAction_NPC(0x2, API.OFF_ACT_AttackNPC_route, { npc.Id }, 50)
		API.RandomSleep2(1000, 800, 800)
		return true
	else
		print("NPC not found, teleporting to NPC location")
		return teleportWithJacket()
	end
end

local function handleMediumClue(item)
	print("Handling medium clue")
	local requiredItemId = item:GetParam(CLUE_PARAMS.REQUIRED_ITEM)
	local npcId = item:GetParam(CLUE_PARAMS.NPC)

	print("Required item ID:", requiredItemId)
	print("Target NPC ID:", npcId)

	-- Track metrics using unified system
	local clueKey = "medium_" .. requiredItemId .. "_" .. npcId
	trackMetric("mediumItemClues", clueKey)

	-- Check if we have the foot-shaped key unlock or already have the required item
	if SETTINGS.HAS_FOOT_SHAPED_KEY_UNLOCK or hasRequiredItem(requiredItemId) then
		if SETTINGS.HAS_FOOT_SHAPED_KEY_UNLOCK then
			print("Way of the foot-shaped key unlock enabled - skipping required item, going straight to chest")
		else
			print("Already have required item, searching for objects to interact with")
		end

		-- First, teleport to the search area to ensure we're in the right location (only once per clue)
		if not stateTracking.hasTeleportedForMediumClue then
			print("Teleporting to search area first")
			local teleportSuccess = teleportWithJacket()
			if not teleportSuccess then
				return false -- Clue was swapped due to access denial
			end
			stateTracking.hasTeleportedForMediumClue = true

			-- Wait a moment after teleport before searching for objects
			API.RandomSleep2(1000, 500, 500)
		else
			print("Already teleported for this medium clue, proceeding to search")
		end

		return searchForMediumClueObjects()
	else
		print("Need to get required item from NPC first")
		return attackNpcForItem(npcId)
	end
end

local function handlePuzzleBox()
	print("Handling puzzle box")

	local puzzleBoxId, puzzleBoxName = hasPuzzleBox()
	local isElitePuzzleBox = puzzleBoxName
		and (string.find(puzzleBoxName, "elite") or string.find(puzzleBoxName, "Puzzle scroll box"))

	-- Check for "Please finish the puzzle for me!" dialogue - handled by centralized chat processor

	-- Check if we've already completed this puzzle box (but only if we haven't just detected it's incomplete)
	if puzzleBoxId and completedPuzzleBoxes[puzzleBoxId] then
		print("Puzzle box", puzzleBoxId, "already completed - continuing with original clue")
		return false -- Continue with original clue processing
	end

	-- Initialize attempt counter for this puzzle box if not exists
	if puzzleBoxId and not puzzleAttempts[puzzleBoxId] then
		puzzleAttempts[puzzleBoxId] = 0
		print("Initialized attempt counter for puzzle box", puzzleBoxId)
	end

	-- Check if puzzle interface is already open
	if PuzzleModule.isPuzzleOpen() then
		print("Puzzle interface is open, extracting state...")
		local puzzleState = PuzzleModule.extractPuzzleState()

		if puzzleState then
			-- Increment attempt counter
			if puzzleBoxId then
				puzzleAttempts[puzzleBoxId] = puzzleAttempts[puzzleBoxId] + 1
				print("Puzzle solve attempt", puzzleAttempts[puzzleBoxId], "of 3 for puzzle box", puzzleBoxId)
			end

			print("Puzzle state extracted, solving...")
			local success = PuzzleModule.solvePuzzle(puzzleState, SETTINGS.API_TOKEN)
			if success then
				print("Puzzle solved successfully!")
				-- Track metrics using unified system
				if puzzleBoxId then
					local clueKey = "puzzle_solved_" .. puzzleBoxId
					trackMetric("puzzleBoxesSolved", clueKey)
				end
				-- Mark this puzzle box as completed and reset attempts
				if puzzleBoxId then
					completedPuzzleBoxes[puzzleBoxId] = true
					puzzleAttempts[puzzleBoxId] = nil -- Clear attempt counter
					print("Marked puzzle box", puzzleBoxId, "as completed")

					-- For Elite puzzle boxes, we need to reopen the box after completion
					if isElitePuzzleBox then
						print("Elite puzzle box completed - need to reopen the box")
						API.RandomSleep2(1000, 500, 500) -- Wait for interface to close
						API.DoAction_Inventory1(puzzleBoxId, 0, 1, API.OFF_ACT_GeneralInterface_route)
						API.RandomSleep2(600, 600, 600)
						print("Elite puzzle box reopened after completion")
					end
				end
				-- Wait a moment for any interface changes
				API.RandomSleep2(1000, 500, 500)
				print("Puzzle box completed - now continuing with original clue step")
				return false -- Stop processing puzzle box, continue with original clue
			else
				print("Failed to solve puzzle")
				-- Check if we've reached the maximum attempts (3)
				if puzzleBoxId and puzzleAttempts[puzzleBoxId] >= 3 then
					print("Maximum attempts (3) reached for puzzle box", puzzleBoxId, "- swapping clue")
					-- Track metrics using unified system
					local clueKey = "puzzle_failed_" .. puzzleBoxId
					trackMetric("puzzleBoxesFailed", clueKey)
					-- Clear attempt counter and swap clue
					puzzleAttempts[puzzleBoxId] = nil
					return handleBadClue()
				else
					print("Attempt", puzzleAttempts[puzzleBoxId], "failed, will retry (max 3 attempts)")
					-- Close puzzle interface to retry
					if PuzzleModule.isPuzzleOpen() then
						print("Closing puzzle interface to retry...")
						API.KeyboardPress2(0x1B, 50, 60) -- ESC key
						API.RandomSleep2(500, 200, 200)
					end
					return true -- Continue processing to retry
				end
			end
		else
			print("Could not extract puzzle state")
			-- Increment attempt counter even for extraction failures
			if puzzleBoxId then
				puzzleAttempts[puzzleBoxId] = puzzleAttempts[puzzleBoxId] + 1
				print("Puzzle state extraction failed - attempt", puzzleAttempts[puzzleBoxId], "of 3")

				if puzzleAttempts[puzzleBoxId] >= 3 then
					print("Maximum attempts (3) reached for puzzle extraction - swapping clue")
					puzzleAttempts[puzzleBoxId] = nil
					return handleBadClue()
				else
					print("Will retry puzzle extraction (max 3 attempts)")
					-- Close puzzle interface to retry
					if PuzzleModule.isPuzzleOpen() then
						print("Closing puzzle interface to retry...")
						API.KeyboardPress2(0x1B, 50, 60) -- ESC key
						API.RandomSleep2(500, 200, 200)
					end
					return true -- Continue processing to retry
				end
			else
				return handleBadClue()
			end
		end
	end

	-- If interface not open, check if we have a puzzle box to open
	if puzzleBoxId then
		local boxType = isElitePuzzleBox and "elite" or "hard"
		print("Opening puzzle box (" .. boxType .. ") with ID:", puzzleBoxId)
		API.DoAction_Inventory1(puzzleBoxId, 0, 1, API.OFF_ACT_GeneralInterface_route)
		API.RandomSleep2(1200, 600, 600)
		return true -- Continue processing on next loop iteration
	end

	-- No puzzle box and no interface - this shouldn't happen
	print("No puzzle box found and interface not open")
	return handleBadClue()
end

-- Knot puzzle handling using PuzzleModule
local function handleKnotPuzzle()
	print("Handling knot puzzle using PuzzleModule")

	local success = PuzzleModule.solveKnotPuzzleBox()

	if success then
		print("Knot puzzle completed successfully")
		ClueState.metrics.knotPuzzlesSolved = ClueState.metrics.knotPuzzlesSolved + 1
		print("Knot puzzle solved metrics updated")
		return ActionResult.success("knot_puzzle")
	else
		print("Failed to solve knot puzzle")
		ClueState.metrics.knotPuzzlesFailed = ClueState.metrics.knotPuzzlesFailed + 1
		print("Knot puzzle failed metrics updated")
		return ActionResult.failure("knot_puzzle")
	end
end

-- Sealed clue opening priority list - DRY refactoring
local SEALED_CLUE_PRIORITY = {
	{ id = ITEM_IDS.SEALED_ELITE, name = "sealed elite clue", metric = "sealedCluesOpened" },
	{ id = ITEM_IDS.SEALED_HARD, name = "sealed hard clue", metric = "sealedCluesOpened" },
	{ id = ITEM_IDS.SEALED_MEDIUM, name = "sealed medium clue", metric = "sealedCluesOpened" },
	{ id = ITEM_IDS.SEALED_EASY, name = "sealed easy clue", metric = "sealedCluesOpened" },
}

local function openScrollItem(scrollBoxId)
	print("Opening scroll item")

	-- Only increment if we haven't opened a scroll this loop iteration
	if not ClueState.tracking.hasOpenedScrollThisLoop then
		if scrollBoxId then
			print("Opening scroll box with ID:", scrollBoxId)
			ClueState.metrics.scrollBoxesOpened = ClueState.metrics.scrollBoxesOpened + 1
			print("Scroll box opened metrics updated")
			API.DoAction_Inventory1(scrollBoxId, 0, 1, API.OFF_ACT_GeneralInterface_route)
		else
			-- Try to open sealed clues in priority order
			for _, clueInfo in ipairs(SEALED_CLUE_PRIORITY) do
				if Inventory:Contains(clueInfo.id) then
					print("Opening " .. clueInfo.name)
					ClueState.metrics[clueInfo.metric] = ClueState.metrics[clueInfo.metric] + 1
					print("Sealed clue opened metrics updated")
					API.DoAction_Inventory1(clueInfo.id, 0, 1, API.OFF_ACT_GeneralInterface_route)
					break
				end
			end
		end
		ClueState.tracking.hasOpenedScrollThisLoop = true
	end
	API.RandomSleep2(600, 600, 600)
	return ActionResult.success("open_scroll")
end

local function processClue(clueId)
	-- First check if we have a knot puzzle interface open
	local isKnotOpen = PuzzleModule.isKnotPuzzleOpen()
	if isKnotOpen then
		print("Knot puzzle detected, handling...")
		local success = handleKnotPuzzle()
		if success then
			print("Knot puzzle completed, continuing with clue processing")
		else
			print("Knot puzzle failed, swapping clue")
			return handleBadClue()
		end
		return true
	end

	-- Check if we have a puzzle box to handle or puzzle interface is open
	-- But only if the puzzle box hasn't been completed yet
	local puzzleBoxId = hasPuzzleBox()
	if (puzzleBoxId and not completedPuzzleBoxes[puzzleBoxId]) or PuzzleModule.isPuzzleOpen() then
		print("Puzzle box detected, handling...")
		return handlePuzzleBox()
	elseif puzzleBoxId and completedPuzzleBoxes[puzzleBoxId] then
		print("Puzzle box", puzzleBoxId, "already completed in processClue - continuing with clue processing")
	end

	-- Check if this clue is blacklisted and should be swapped
	if clueId and isClueBlacklisted(clueId) then
		print("Clue ID", clueId, "is blacklisted - swapping for new clue")
		return handleBadClue()
	end

	local item = Item:Get(clueId)
	local hasObject = item:HasParam(CLUE_PARAMS.OBJECT)
	local hasNpc = item:HasParam(CLUE_PARAMS.NPC)
	local hasDig = item:HasParam(CLUE_PARAMS.DIG)
	local hasRequiredItem = item:HasParam(CLUE_PARAMS.REQUIRED_ITEM)
	local hasScan = item:HasParam(CLUE_PARAMS.SCAN)

	print(
		"DEBUG: Clue params - Object:",
		hasObject,
		"NPC:",
		hasNpc,
		"Dig:",
		hasDig,
		"RequiredItem:",
		hasRequiredItem,
		"Scan:",
		hasScan
	)

	-- Check clue type and handle accordingly using standardized wrapper
	if hasScan then
		print("Elite scan clue detected - processing")
		return processClueWithHandler(clueId, "scan", handleScanClue)
	elseif hasRequiredItem then
		-- Check if required item clues are allowed
		if SETTINGS.ALLOW_REQUIRED_ITEM_CLUES then
			print("Medium clue with required item detected - processing (required item clues allowed)")
			return processClueWithHandler(clueId, "medium", handleMediumClue)
		else
			print("Medium clue with required item detected but not allowed - swapping clue")
			return handleBadClue()
		end
	elseif hasObject then
		return processClueWithHandler(clueId, "object", handleObjectClue)
	elseif hasNpc then
		return processClueWithHandler(clueId, "npc", handleNpcClue)
	elseif hasDig then
		return processClueWithHandler(clueId, "dig", handleDigClue)
	else
		return handleBadClue()
	end
end

-- Position tracking for stuck detection
local lastPlayerPos = nil
local lastPosCheckTime = 0
local STUCK_CHECK_INTERVAL = 2000 -- Check every 2 seconds
local STUCK_DISTANCE_THRESHOLD = 1 -- If player hasn't moved more than 1 tile

local function isPlayerReady()
	local isMoving = API.ReadPlayerMovin2()
	local isAnimating = API.CheckAnim(8)

	-- If not moving and not animating, player is ready
	if not isMoving and not isAnimating then
		return true
	end

	-- If player shows as moving, check if they're actually stuck
	if isMoving then
		local currentTime = os.time() * 1000 -- Convert to milliseconds
		local currentPos = API.PlayerCoordfloat()

		-- Initialize or update position tracking
		if not lastPlayerPos or (currentTime - lastPosCheckTime) >= STUCK_CHECK_INTERVAL then
			if lastPlayerPos then
				-- Calculate distance moved since last check
				local distance = math.sqrt((currentPos.x - lastPlayerPos.x) ^ 2 + (currentPos.y - lastPlayerPos.y) ^ 2)

				-- If player hasn't moved much but shows as moving, they're stuck
				if distance < STUCK_DISTANCE_THRESHOLD then
					print("Player appears stuck (moving flag active but position unchanged)")
					return true -- Treat as ready since they're not actually moving
				end
			end

			-- Update tracking
			lastPlayerPos = { x = currentPos.x, y = currentPos.y }
			lastPosCheckTime = currentTime
		end

		-- Still moving, not ready
		return false
	end

	-- If animating but not moving, not ready
	return false
end

local function hasRequiredAbilities()
	local missingAbilities = {}
	local wrongActions = {}
	local allGood = true

	for _, abilityInfo in ipairs(REQUIRED_ABILITIES) do
		local ability = API.GetABs_name1(abilityInfo.name)

		if not ability or not ability.enabled then
			table.insert(missingAbilities, abilityInfo.name)
			allGood = false
		elseif not string.find(ability.action or "", abilityInfo.action) then
			table.insert(wrongActions, {
				name = abilityInfo.name,
				expected = abilityInfo.action,
				current = ability.action or "none",
			})
			allGood = false
		else
			print("✓ Found ability:", abilityInfo.name, "with action:", abilityInfo.action)
		end
	end

	-- Report all issues at once
	if #missingAbilities > 0 then
		print("ERROR: Missing or disabled abilities:")
		for _, name in ipairs(missingAbilities) do
			print("  - " .. name .. " (must be equipped and on action bar)")
		end
	end

	if #wrongActions > 0 then
		print("ERROR: Abilities with wrong actions:")
		for _, info in ipairs(wrongActions) do
			print("  - " .. info.name .. ": expected '" .. info.expected .. "', found '" .. info.current .. "'")
		end
	end

	return allGood
end

local function hasValidApiToken()
	if not SETTINGS.API_TOKEN or SETTINGS.API_TOKEN == "" then
		print("ERROR: API_TOKEN is not configured in SETTINGS")
		print("Please add your API token to SETTINGS.API_TOKEN for puzzle solver authentication")
		return false
	end

	print("✓ API token configured")
	return true
end

local function hasRequiredItems()
	-- Debug: Print all inventory items
	print("DEBUG: All inventory items:")
	local inv = Inventory:GetItems()
	for i, item in ipairs(inv) do
		if item.name and (string.find(item.name:lower(), "clue") or string.find(item.name:lower(), "scroll")) then
			print("  Item " .. i .. ": ID=" .. (item.id or "nil") .. ", Name='" .. (item.name or "nil") .. "'")
		end
	end

	local scrollBoxId = hasScrollBox()
	local puzzleBoxId = hasPuzzleBox()
	local sealedEasy = Inventory:Contains(ITEM_IDS.SEALED_EASY)
	local sealedMedium = Inventory:Contains(ITEM_IDS.SEALED_MEDIUM)
	local sealedHard = Inventory:Contains(ITEM_IDS.SEALED_HARD)
	local sealedElite = Inventory:Contains(ITEM_IDS.SEALED_ELITE)
	local easyClue = hasEasyClue()
	local mediumClue = hasMediumClue()
	local hardClue = hasHardClue()
	local eliteClue = hasEliteClue()

	print("DEBUG: Checking for clue items...")
	print("  Sealed Easy (42006):", sealedEasy)
	print("  Sealed Medium (42007):", sealedMedium)
	print("  Sealed Hard (42008):", sealedHard)
	print("  Sealed Elite (42009):", sealedElite)
	print("  Scroll Box:", scrollBoxId and scrollBoxId or "none")
	if scrollBoxId == 19040 then
		print("    -> Special scroll item (19040) detected")
	end
	print("  Puzzle Box:", puzzleBoxId and puzzleBoxId or "none")
	print("  Easy Clue:", easyClue and easyClue or "none")
	print("  Medium Clue:", mediumClue and mediumClue or "none")
	print("  Hard Clue:", hardClue and hardClue or "none")
	print("  Elite Clue:", eliteClue and eliteClue or "none")

	local hasClueItems = sealedEasy
		or sealedMedium
		or sealedHard
		or sealedElite
		or scrollBoxId
		or puzzleBoxId
		or easyClue
		or mediumClue
		or hardClue
		or eliteClue

	if not hasClueItems then
		print("ERROR: No clue scrolls, sealed clues, or scroll boxes found in inventory")
		return false
	end
	return true
end

if not hasRequiredAbilities() then
	print("ERROR: Missing required Globetrotter equipment abilities")
	return
end

if not hasValidApiToken() then
	print("ERROR: API token validation failed")
	return
end

if not hasRequiredItems() then
	print("ERROR: No clue items found to process")
	return
end

print("Starting Easy, Medium & Hard Clue Script")
print("All preflight checks passed!")

-- Initialize metrics
initializeMetrics()

Interact:SetSleep(900, 1200, 1200)

API.SetMaxIdleTime(10)
API.GatherEvents_chat_check()

while API.Read_LoopyLoop() do
	-- Display metrics table
	API.DrawTable(calculateMetrics())

	-- Reset per-loop tracking
	ClueState.tracking.hasOpenedScrollThisLoop = false

	-- Process all chat events once per loop (centralized handler)
	processChatEvents()

	-- Declare all state variables first to avoid goto scope issues
	local challengeDialogueState = API.VB_FindPSettinOrder(GAME_CONSTANTS.VB_DIALOGUE_STATE)
	local dialogueState = API.VB_FindPSettinOrder(GAME_CONSTANTS.VB_DIALOGUE_STATE)
	local isKnotOpen = PuzzleModule.isKnotPuzzleOpen()
	local isPuzzleOpen = PuzzleModule.isPuzzleOpen()

	-- Check for knot puzzle interface first (highest priority)
	if isKnotOpen then
		print("Knot puzzle interface detected in main loop")
		local result = handleKnotPuzzle()
		if ActionResult.isSuccess(result) then
			print("Knot puzzle completed in main loop")
		else
			print("Knot puzzle failed in main loop, swapping clue")
			handleBadClue()
		end
		goto continue
	end

	-- Check for puzzle box interface second (high priority for item 19040)
	if isPuzzleOpen then
		print("Puzzle box interface detected in main loop")
		local success = handlePuzzleBox()
		if success then
			print("Puzzle box handled in main loop")
		else
			print("Puzzle box handling failed in main loop")
		end
		goto continue
	end

	-- Check for challenge scroll dialogue first (VB_DIALOGUE_STATE = 10)

	if challengeDialogueState and challengeDialogueState.state == 10 then
		print("Challenge dialogue detected (VB_DIALOGUE_STATE = 10)")
		if hasChallengeScroll() then
			local success = handleChallengeScroll()
			if success then
				print("Challenge answer provided")
				goto continue
			end
		end
	end

	-- Check for teleport confirmation dialogue
	if dialogueState and dialogueState.state == 12 then
		local option = hasOption()
		if option and string.find(option, "Teleport now?") then
			-- Check if wilderness teleports are allowed
			if SETTINGS.ALLOW_WILDERNESS_TELEPORTS then
				print("Teleport confirmation detected - selecting Yes (wilderness teleports allowed)")
				API.KeyboardPress2(0x31, 60, 100) -- Press '1' key for Yes
				API.RandomSleep2(500, 200, 200)
				goto continue
			else
				print("Wilderness teleport detected but not allowed - swapping clue")
				-- Press '2' or ESC to decline teleport, then swap clue
				API.KeyboardPress2(0x32, 60, 100) -- Press '2' key for No
				API.RandomSleep2(500, 200, 200)
				-- This should trigger clue swapping in the next iteration
				handleBadClue()
				goto continue
			end
		elseif option and string.find(option, "Teleport to the key?") then
			print("Key teleport confirmation detected - selecting Yes")
			API.KeyboardPress2(0x31, 60, 100) -- Press '1' key for Yes
			API.RandomSleep2(500, 200, 200)
			goto continue
		end
	end

	-- Catch-all dialogue handler (but skip if clue swap dialogue is present)
	if dialogueState and dialogueState.state == 12 then
		-- Check if this is the clue swap dialogue - if so, let handleBadClue handle it
		local option = hasOption()
		if option and string.find(option, "Swap your clue for a new one?") then
			print("Clue swap dialogue detected, calling handleBadClue")
			handleBadClue()
			goto continue
		else
			print("Dialogue detected (state 12), pressing space to continue")
			API.KeyboardPress2(0x20, 100, 100)
			API.RandomSleep2(200, 200, 200)
			goto continue
		end
	end

	if isPlayerReady() then
		-- Clean up completed puzzle boxes that are no longer in inventory
		cleanupCompletedPuzzleBoxes()

		local scrollBoxId = hasScrollBox()
		local puzzleBoxId = hasPuzzleBox()
		local challengeScrollId = hasChallengeScroll()
		local hasClueItems = Inventory:Contains(ITEM_IDS.SEALED_EASY)
			or Inventory:Contains(ITEM_IDS.SEALED_MEDIUM)
			or Inventory:Contains(ITEM_IDS.SEALED_HARD)
			or Inventory:Contains(ITEM_IDS.SEALED_ELITE)
			or scrollBoxId
			or puzzleBoxId
			or challengeScrollId
			or hasEasyClue()
			or hasMediumClue()
			or hasHardClue()
			or hasEliteClue()

		if hasClueItems then
			-- Detect if we're processing a new clue and reset state tracking
			local easyClueId = hasEasyClue()
			local mediumClueId = hasMediumClue()
			local hardClueId = hasHardClue()
			local eliteClueId = hasEliteClue()
			local currentClueId = eliteClueId or hardClueId or mediumClueId or easyClueId

			if currentClueId and currentClueId ~= stateTracking.lastProcessedClueId then
				print("New clue detected, resetting state tracking")
				stateTracking.processedClueTypes = {}
				stateTracking.hasSwappedThisClue = false
				stateTracking.hasTeleportedForMediumClue = false
				stateTracking.hasTeleportedForEliteClue = false
				stateTracking.lastProcessedClueId = currentClueId
			end

			-- Check for challenge scroll first (highest priority)
			if challengeScrollId then
				print("Processing challenge scroll ID:", challengeScrollId)
				local success = handleChallengeScroll()
				if success then
					print("Challenge scroll handled successfully")
					goto continue
				else
					print("Challenge scroll handling failed or not ready")
					goto continue
				end
			-- Check for puzzle box second (high priority) - but only if not already completed
			elseif puzzleBoxId and not completedPuzzleBoxes[puzzleBoxId] then
				print("Processing puzzle box ID:", puzzleBoxId)
				local shouldContinue = processClue(nil) -- Pass nil since we're handling puzzle box
				if shouldContinue then
					goto continue
				end
			elseif puzzleBoxId and completedPuzzleBoxes[puzzleBoxId] then
				print("Puzzle box", puzzleBoxId, "already completed - processing original clue instead")
				-- Process the original clue since puzzle box is completed
				local easyClueId = hasEasyClue()
				local mediumClueId = hasMediumClue()
				local hardClueId = hasHardClue()
				local eliteClueId = hasEliteClue()
				local clueId = eliteClueId or hardClueId or mediumClueId or easyClueId -- Prioritize elite, then hard, then medium, then easy

				if clueId then
					local clueType = eliteClueId and "elite"
						or (hardClueId and "hard" or (mediumClueId and "medium" or "easy"))
					print("Processing", clueType, "clue ID:", clueId, "(puzzle box was completed)")
					local shouldContinue = processClue(clueId)
					if shouldContinue then
						goto continue
					end
				else
					print("No clue scroll found to process after puzzle box completion")
				end
			else
				local easyClueId = hasEasyClue()
				local mediumClueId = hasMediumClue()
				local hardClueId = hasHardClue()
				local eliteClueId = hasEliteClue()
				local clueId = eliteClueId or hardClueId or mediumClueId or easyClueId -- Prioritize elite, then hard, then medium, then easy

				if clueId then
					local clueType = eliteClueId and "elite"
						or (hardClueId and "hard" or (mediumClueId and "medium" or "easy"))
					print("Processing", clueType, "clue ID:", clueId)
					local shouldContinue = processClue(clueId)
					if shouldContinue then
						goto continue
					end
				else
					openScrollItem(scrollBoxId)
				end
			end
		else
			print("No clues found, ending script")
			break
		end
	end

	::continue::
	API.RandomSleep2(200, 300, 300)
end
