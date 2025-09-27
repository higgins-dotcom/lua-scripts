--[[
====================================================================================================
Plant Herb Seeds Script
====================================================================================================
Version: 1.0
Author: Higgins
Description: Automatically plants herb seeds at Catherby herb patch based on Farming level

Starting Location: Catherby herb patch (2792, 3464) with seeds in inventory
Requirements: Herb seeds in inventory, appropriate Farming level, rake (if needed)

How it works:
1. Checks herb patch state (Inspect/Rake/Pick)
2. Rakes patch if needed to clear weeds
3. Plants seeds based on Farming level requirements
4. Picks grown herbs when ready
5. Drops any weeds that appear in inventory

Level Requirements:
- Each seed type requires a specific Farming level to plant
- Script automatically checks your level against seed requirements (item param 771)
- Only plants seeds for herb patches (param 4085 contains "herb patch" or category 20)

Location: Catherby herb patch coordinates (2792, 3464)
====================================================================================================
]]

local API = require("API")

-- ================================================================================================
-- CONSTANTS
-- ================================================================================================

local PATCH_COORDS = { x = 2791, y = 3463, z = 4 }
local WEEDS_ID = 6005

-- ================================================================================================
-- UTILITY FUNCTIONS
-- ================================================================================================

-- Cache for seed level requirements and patch compatibility
local seedCache = {}

local function getCurrentFarmingLevel()
	return API.GetSkillsTableSkill(38)
end

local function getSeedRequirements(itemId)
	-- Check cache first
	if seedCache[itemId] then
		return seedCache[itemId]
	end

	local item = Item:Get(itemId)
	local requirements = {
		level = 99, -- Default to high level if unknown
		isHerbSeed = false,
	}

	if item then
		-- Get farming level requirement (param 771)
		requirements.level = item:GetParam(771) or 99

		-- Check if it's for herb patches (param 4085 first, then category 20)
		local patchInfo = item:GetParam(4085)
		if patchInfo and string.find(tostring(patchInfo), "herb patch") then
			requirements.isHerbSeed = true
		elseif item.category == 20 then
			-- Fallback: check if item category is 20 (seeds)
			requirements.isHerbSeed = true
		end
	end

	-- Cache the result
	seedCache[itemId] = requirements
	return requirements
end

local function canPlantSeed(itemId)
	local playerLevel = getCurrentFarmingLevel()
	local requirements = getSeedRequirements(itemId)

	return requirements.isHerbSeed and playerLevel >= requirements.level
end

-- ================================================================================================
-- PATCH & INVENTORY FUNCTIONS
-- ================================================================================================

local function getHerbPatchAtCoords()
	local objs = API.ReadAllObjectsArray({ 0 }, { -1 }, {})

	for _, obj in ipairs(objs) do
		if obj.CalcX == PATCH_COORDS.x and obj.CalcY == PATCH_COORDS.y then
			-- Look for objects with farming-related actions
			if
				obj.Action
				and (
					string.find(obj.Action, "Inspect")
					or string.find(obj.Action, "Rake")
					or string.find(obj.Action, "Pick")
				)
			then
				return obj
			end
		end
	end
	return nil
end

local function getPatchAction()
	local patch = getHerbPatchAtCoords()
	if patch and patch.Action then
		if string.find(patch.Action, "Inspect") then
			return "Inspect", patch.Id
		elseif string.find(patch.Action, "Rake") then
			return "Rake", patch.Id
		elseif string.find(patch.Action, "Pick") then
			return "Pick", patch.Id
		end
	end
	return nil, nil
end

local function getPlantableSeeds()
	local seeds = {}
	local inv = API.ReadInvArrays33()

	for _, item in ipairs(inv) do
		if item.itemid1 > 0 and canPlantSeed(item.itemid1) then
			table.insert(seeds, item.itemid1)
		end
	end

	return seeds
end

local function hasWeeds()
	return Inventory:GetItemAmount(WEEDS_ID) > 0
end

local function dropWeeds()
	if hasWeeds() then
		API.DoAction_Inventory1(WEEDS_ID, 0, 7, API.OFF_ACT_GeneralInterface_route) -- Drop action
		API.RandomSleep2(300, 200, 100)
	end
end

-- ================================================================================================
-- MAIN ACTIONS
-- ================================================================================================

local function rakePatch()
	local patch = getHerbPatchAtCoords()
	if patch and patch.Name then
		print("Raking " .. patch.Name .. "...")
		Interact:Object(patch.Name, "Rake", 30)
		API.RandomSleep2(600, 300, 200)
		return true
	else
		print("Warning: Could not determine patch name for raking")
		return false
	end
end

local function plantSeed(seedId, patchId)
	local seed = Item:Get(seedId)
	local seedName = seed.name or "Unknown seed"
	print("Planting " .. seedName .. "...")

	-- Select seed first
	API.DoAction_Inventory1(seedId, 0, 0, API.OFF_ACT_Bladed_interface_route)
	API.RandomSleep2(400, 400, 400)

	-- Use seed on patch
	API.DoAction_Object1(0x24, API.OFF_ACT_GeneralObject_route00, { patchId }, 50)
	API.RandomSleep2(600, 300, 200)

	print("Seed planting initiated for " .. seedName)
	return true
end

local function pickHerbs()
	local patch = getHerbPatchAtCoords()
	if patch and patch.Name then
		print("Picking herbs from " .. patch.Name .. "...")
		Interact:Object(patch.Name, "Pick", 30)
		API.RandomSleep2(600, 300, 200)
		return true
	else
		print("Warning: Could not determine patch name for picking")
		return false
	end
end

-- ================================================================================================
-- MAIN LOGIC
-- ================================================================================================

local function handlePatch()
	local action, patchId = getPatchAction()

	if not action or not patchId then
		print("ERROR: No herb patch found at coordinates (" .. PATCH_COORDS.x .. ", " .. PATCH_COORDS.y .. ")")
		return false
	end

	if action == "Rake" then
		return rakePatch() -- Continue processing
	elseif action == "Inspect" then
		local seeds = getPlantableSeeds()

		if #seeds == 0 then
			print("No plantable herb seeds found in inventory!")
			return false
		end

		-- Plant the first available seed
		return plantSeed(seeds[1], patchId)
	elseif action == "Pick" then
		return pickHerbs()
	end

	return false
end

-- ================================================================================================
-- PREFLIGHT CHECKS
-- ================================================================================================

local function isNearCatherbyPatch()
	local playerPos = API.PlayerCoordfloat()
	local targetX, targetY = PATCH_COORDS.x, PATCH_COORDS.y
	local range = 20

	local distance = math.sqrt((playerPos.x - targetX) ^ 2 + (playerPos.y - targetY) ^ 2)
	return distance <= range
end

-- ================================================================================================
-- SCRIPT EXECUTION
-- ================================================================================================

print("Starting Plant Herb Seeds script...")
print("Current Farming level: " .. getCurrentFarmingLevel())
print("Target: Catherby herb patch (" .. PATCH_COORDS.x .. ", " .. PATCH_COORDS.y .. ")")

-- Location check
if not isNearCatherbyPatch() then
	local playerPos = API.PlayerCoordfloat()
	print("ERROR: Player not near Catherby herb patch!")
	print("Required: Within 20 tiles of (" .. PATCH_COORDS.x .. ", " .. PATCH_COORDS.y .. ")")
	print("Current position: (" .. math.floor(playerPos.x) .. ", " .. math.floor(playerPos.y) .. ")")
	print("Please move to the Catherby herb patch before running this script.")
	return
end

-- Check if we have any plantable seeds
local initialSeeds = getPlantableSeeds()
if #initialSeeds == 0 then
	print("ERROR: No plantable herb seeds found in inventory!")
	print("Make sure you have herb seeds that match your Farming level.")
	return
end

print("Found " .. #initialSeeds .. " plantable seed type(s)")
print("Location check passed - starting farming operations...")

API.Write_fake_mouse_do(false)
API.SetDrawTrackedSkills(true)

while API.Read_LoopyLoop() do
	if not API.CheckAnim(5) then
		dropWeeds()
		local success = handlePatch()

		if not success then
			print("Planting complete or no more work to do. Stopping script.")
			API.Write_LoopyLoop(false)
			break
		end
	end

	::continue::
	API.RandomSleep2(300, 200, 100)
end
