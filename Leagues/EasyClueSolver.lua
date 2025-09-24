--[[
====================================================================================================
Easy Clue Scroll Solver
====================================================================================================
Version: 1.0
Author: Higgins
Description: Automatically solves easy clue scrolls using Globetrotter equipment

Requirements:
- Globetrotter jacket (for teleporting) - must be equipped and on action bar
- Globetrotter backpack (for clue swapping) - must be equipped and on action bar
- Easy clue scrolls or sealed easy clue scrolls

How it works:
1. Opens sealed clue scrolls or scroll boxes
2. Identifies clue type (dig, object interaction, NPC challenge)
3. Teleports to location if needed
4. Completes the clue step
5. Auto-skips emote-based clues by swapping them
6. Handles other unsolvable clues by swapping them

====================================================================================================
]]
--

local API = require("API")

local ITEM_IDS = {
	SEALED_EASY = 42006,
}

local CLUE_PARAMS = {
	DIG = 4681,
	OBJECT = 4682,
	NPC = 4683,
}

local INTERFACE_IDS = {
	OPTION_CHECK = { { 1188, 5, -1, -1, 0 }, { 1188, 3, -1, 5, 0 }, { 1188, 3, 14, 3, 0 } },
}

local SETTINGS = {
	PROXIMITY_THRESHOLD = 5,
	VB_CLUE_STATE = 2874,
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

-- Equipment Functions
local function checkForAccessDenied()
	local chatTexts = API.GatherEvents_chat_check()
	if chatTexts then
		for _, chatText in ipairs(chatTexts) do
			if string.find(chatText, "You currently do not have access") then
				print("Access denied detected - swapping clue")
				return true
			end
		end
	end
	return false
end

local function teleportWithJacket()
	print("Teleporting with Globetrotter jacket")
	API.DoAction_Ability("Globetrotter jacket", 1, API.OFF_ACT_GeneralInterface_route)
	API.RandomSleep2(800, 600, 600)

	-- Check if teleport was denied due to access restrictions
	if checkForAccessDenied() then
		handleBadClue()
		return false
	end
	return true
end

local function openGlobetrotterBackpack()
	print("Opening Globetrotter backpack")
	API.DoAction_Ability("Globetrotter backpack", 1, API.OFF_ACT_GeneralInterface_route)
	API.RandomSleep2(600, 600, 600)
end

local function hasOption()
	local option = API.ScanForInterfaceTest2Get(false, INTERFACE_IDS.OPTION_CHECK)
	if #option > 0 and #option[1].textids > 0 then
		return option[1].textids
	end
	return false
end

local function hasEasyClue()
	local inv = Inventory:GetItems()
	for _, item in ipairs(inv) do
		if item.name and string.find(item.name, "Clue scroll %(easy%)") then
			return item.itemid1
		end
	end
	return false
end

local function hasScrollBox()
	local inv = Inventory:GetItems()
	for _, item in ipairs(inv) do
		if item.name and string.find(item.name, "Scroll box %(easy%)") then
			return item.itemid1
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

local function handleObjectClue(item)
	print("Handling object clue")
	local coords = getCoordsFromParam(item:GetParam(CLUE_PARAMS.OBJECT))
	print("Object coordinates:", coords[1], coords[2])

	if isPlayerClose(coords) then
		print("Player is close to object coordinates")
		local obj = getObjectAtCoords(coords)
		if obj then
			print("Interacting with object:", obj.Id, obj.Action)
			Interact:Object(obj.Name, obj.Action, 2)
		else
			print("Object not found at coordinates")
		end
	else
		print("Player needs to move closer to object coordinates")
		local teleportSuccess = teleportWithJacket()
		if not teleportSuccess then
			return false -- Clue was swapped due to access denial
		end
	end
	return true
end

local function handleNpcClue(item)
	print("Handling NPC challenge clue")
	local npcId = item:GetParam(CLUE_PARAMS.NPC)
	print("Target NPC ID:", npcId)

	local npc = findNpc(npcId)
	if npc then
		print("Interacting with NPC:", npc.Name)
		Interact:NPC(npc.Name, npc.Action, 10)
	else
		print("NPC not found nearby, teleporting with jacket")
		local teleportSuccess = teleportWithJacket()
		if not teleportSuccess then
			return false -- Clue was swapped due to access denial
		end
	end
	return true
end

local function handleDigClue(item, clueId)
	print("Handling dig clue")
	local coords = getCoordsFromParam(item:GetParam(CLUE_PARAMS.DIG))
	print("Dig coordinates:", coords[1], coords[2])

	if isPlayerClose(coords) then
		print("Player is close to dig coordinates, digging")
		API.DoAction_Inventory1(clueId, 0, 2, API.OFF_ACT_GeneralInterface_route)
		API.RandomSleep2(600, 600, 600)
	else
		print("Player needs to move closer to dig coordinates")
		local teleportSuccess = teleportWithJacket()
		if not teleportSuccess then
			return false -- Clue was swapped due to access denial
		end
	end
	return true
end

local function handleBadClue()
	print("Handling bad/unsolvable clue")
	local vbClueState = API.VB_FindPSettinOrder(SETTINGS.VB_CLUE_STATE)

	if vbClueState then
		local state = vbClueState.state
		print("Clue state:", state)

		if state == 12 then
			local option = hasOption()
			if option and option == "Swap your clue for a new one?" then
				print("Swapping clue for new one")
				return API.Select_Option("Yes, swap it.")
			else
				print("Pressing space to continue dialog")
				API.KeyboardPress2(0x20, 60, 100)
				API.RandomSleep2(200, 200, 200)
			end
		else
			openGlobetrotterBackpack()
		end
	else
		print("Clue state not found, opening Globetrotter backpack")
		openGlobetrotterBackpack()
	end
	return false
end

local function openScrollItem(scrollBoxId)
	print("Opening scroll item")
	if scrollBoxId then
		print("Opening scroll box with ID:", scrollBoxId)
		API.DoAction_Inventory1(scrollBoxId, 0, 1, API.OFF_ACT_GeneralInterface_route)
	else
		print("Opening sealed easy clue")
		API.DoAction_Inventory1(ITEM_IDS.SEALED_EASY, 0, 1, API.OFF_ACT_GeneralInterface_route)
	end
	API.RandomSleep2(600, 600, 600)
end

local function processClue(clueId)
	local item = Item:Get(clueId)
	local hasObject = item:HasParam(CLUE_PARAMS.OBJECT)
	local hasNpc = item:HasParam(CLUE_PARAMS.NPC)
	local hasDig = item:HasParam(CLUE_PARAMS.DIG)

	if hasObject then
		handleObjectClue(item)
		return true
	elseif hasNpc then
		handleNpcClue(item)
		return true
	elseif hasDig then
		handleDigClue(item, clueId)
		return true
	else
		return handleBadClue()
	end
end

local function isPlayerReady()
	return not API.ReadPlayerMovin2() and not API.CheckAnim(8)
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

local function hasRequiredItems()
	local scrollBoxId = hasScrollBox()
	local hasClueItems = Inventory:Contains(ITEM_IDS.SEALED_EASY) or scrollBoxId or hasEasyClue()

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

if not hasRequiredItems() then
	print("ERROR: No clue items found to process")
	return
end

print("Starting Easy Clue Script")
print("All preflight checks passed!")
Interact:SetSleep(900, 1200, 1200)

API.SetMaxIdleTime(10)
API.GatherEvents_chat_check()

while API.Read_LoopyLoop() do
	if isPlayerReady() then
		local scrollBoxId = hasScrollBox()
		local hasClueItems = Inventory:Contains(ITEM_IDS.SEALED_EASY) or scrollBoxId

		if hasClueItems then
			local clueId = hasEasyClue()

			if clueId then
				print("Processing clue ID:", clueId)
				local shouldContinue = processClue(clueId)
				if shouldContinue then
					goto continue
				end
			else
				openScrollItem(scrollBoxId)
			end
		else
			print("No clues found, ending script")
			break
		end
	end

	::continue::
	API.RandomSleep2(300, 300, 300)
end
