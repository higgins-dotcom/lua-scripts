--[[
====================================================================================================
Plant Herb Seeds Script
====================================================================================================
Version: 1.0
Author: Higgins
Description: Automatically plants herb seeds at any herb patch based on Farming level

Starting Location: Next to any herb patch with seeds in inventory
Requirements: 
- Herb seeds in inventory
- Appropriate Farming level
- Farming relic (Leagues RS3)

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

Location: Any herb patch (coordinates detected automatically)
Note: Requires Farming relic for Leagues RS3. Start next to an empty herb patch.
====================================================================================================
]]

local API = require("API")

-- ================================================================================================
-- CONSTANTS
-- ================================================================================================

local WEEDS_ID = 6055
local PATCH_COORDS = nil -- Will be set dynamically when patch is found

-- Blacklisted seed IDs that should not be planted
local BLACKLISTED_SEEDS = {
	[37952] = true,
}

-- ================================================================================================
-- UTILITY FUNCTIONS
-- ================================================================================================

-- Cache for seed level requirements and patch compatibility
local seedCache = {}

-- Mapping of seeds to their produced herbs (grimy herbs)
local seedToHerbMap = {
	-- Common herb seeds to grimy herbs
	[5291] = 199, -- Guam seed -> Grimy guam
	[5292] = 201, -- Marrentill seed -> Grimy marrentill
	[5293] = 203, -- Tarromin seed -> Grimy tarromin
	[5294] = 205, -- Harralander seed -> Grimy harralander
	[5295] = 207, -- Ranarr seed -> Grimy ranarr
	[5296] = 3049, -- Toadflax seed -> Grimy toadflax
	[5297] = 209, -- Irit seed -> Grimy irit
	[5298] = 211, -- Avantoe seed -> Grimy avantoe
	[5299] = 213, -- Kwuarm seed -> Grimy kwuarm
	[5300] = 3051, -- Snapdragon seed -> Grimy snapdragon
	[5301] = 215, -- Cadantine seed -> Grimy cadantine
	[5302] = 2485, -- Lantadyme seed -> Grimy lantadyme
	[5303] = 217, -- Dwarf weed seed -> Grimy dwarf weed
	[5304] = 219, -- Torstol seed -> Grimy torstol
}

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

local function getProducedHerb(seedId)
	return seedToHerbMap[seedId]
end

local function canPlantSeed(itemId)
	-- Check if seed is blacklisted
	if BLACKLISTED_SEEDS[itemId] then
		return false
	end

	local playerLevel = getCurrentFarmingLevel()
	local requirements = getSeedRequirements(itemId)

	return requirements.isHerbSeed and playerLevel >= requirements.level
end

local function canAccommodateHerbs(seedId)
	-- If inventory isn't full, we can always plant
	if Inventory:FreeSpaces() > 0 then
		return true
	end

	-- If inventory is full, check if we have a stack of the herb this seed produces
	local producedHerb = getProducedHerb(seedId)
	if producedHerb then
		-- Check for regular herb
		local herbCount = Inventory:GetItemAmount(producedHerb)
		if herbCount > 0 then
			return true -- We have a stack, herbs can be added to it
		end

		-- Check for noted herb (typically +1 from original ID)
		local notedHerbCount = Inventory:GetItemAmount(producedHerb + 1)
		if notedHerbCount > 0 then
			return true -- We have a noted stack, herbs can be added to it
		end
	end

	-- No space and no existing stack (regular or noted)
	return false
end

-- ================================================================================================
-- PATCH & INVENTORY FUNCTIONS
-- ================================================================================================

local function findNearbyHerbPatch()
	local objs = API.ReadAllObjectsArray({ 0 }, { -1 }, {})
	local playerPos = API.PlayerCoordfloat()

	for _, obj in ipairs(objs) do
		-- Look for objects with farming-related actions within 10 tiles
		if
			obj.Action
			and (
				string.find(obj.Action, "Inspect")
				or string.find(obj.Action, "Rake")
				or string.find(obj.Action, "Pick")
			)
		then
			local distance = math.sqrt((obj.CalcX - playerPos.x) ^ 2 + (obj.CalcY - playerPos.y) ^ 2)
			if distance <= 10 then
				-- Record the patch coordinates for future use
				PATCH_COORDS = { x = obj.CalcX, y = obj.CalcY, z = obj.CalcZ or 0 }
				print("Found herb patch at (" .. obj.CalcX .. ", " .. obj.CalcY .. "): " .. (obj.Name or "Unknown"))
				return obj
			end
		end
	end
	return nil
end

local function getHerbPatchAtCoords()
	-- If we don't have coordinates yet, find the patch
	if not PATCH_COORDS then
		return findNearbyHerbPatch()
	end

	-- Use recorded coordinates to find the specific patch
	local objs = API.ReadAllObjectsArray({ 0 }, { -1 }, {})

	for _, obj in ipairs(objs) do
		-- Check if object is at our recorded coordinates
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
		if item.itemid1 > 0 and canPlantSeed(item.itemid1) and canAccommodateHerbs(item.itemid1) then
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
		API.DoAction_Inventory1(WEEDS_ID, 0, 8, API.OFF_ACT_GeneralInterface_route2) -- Drop action
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
			-- Check if it's a level issue or inventory issue
			local inv = API.ReadInvArrays33()
			local hasValidSeeds = false
			local inventoryBlocked = false

			for _, item in ipairs(inv) do
				if item.itemid1 > 0 and canPlantSeed(item.itemid1) then
					hasValidSeeds = true
					if not canAccommodateHerbs(item.itemid1) then
						inventoryBlocked = true
						break
					end
				end
			end

			if inventoryBlocked then
				print("Cannot plant: Inventory full and no space for harvested herbs!")
				print("Free up inventory space or ensure you have herb stacks for the seeds you want to plant.")
			else
				print("No plantable herb seeds found in inventory!")
			end
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
-- SCRIPT EXECUTION
-- ================================================================================================

print("Starting Plant Herb Seeds script...")
print("Current Farming level: " .. getCurrentFarmingLevel())

-- Try to find a nearby herb patch
local initialPatch = findNearbyHerbPatch()
if not initialPatch then
	print("ERROR: No herb patch found nearby!")
	print("Please stand next to an empty herb patch before running this script.")
	print("The script will automatically detect and use the closest herb patch.")
	return
end

-- Check if we have any plantable seeds
local initialSeeds = getPlantableSeeds()
if #initialSeeds == 0 then
	-- Check if it's a level issue or inventory issue
	local inv = API.ReadInvArrays33()
	local hasSeeds = false
	local inventoryIssue = false

	for _, item in ipairs(inv) do
		if item.itemid1 > 0 and canPlantSeed(item.itemid1) then
			hasSeeds = true
			if not canAccommodateHerbs(item.itemid1) then
				inventoryIssue = true
				local producedHerb = getProducedHerb(item.itemid1)
				local herbName = producedHerb
						and (Item:Get(producedHerb) and Item:Get(producedHerb).name or "Unknown herb")
					or "Unknown herb"
				print("WARNING: Inventory full and no stack of " .. herbName .. " found for seed " .. item.itemid1)
			end
		end
	end

	if inventoryIssue then
		print("ERROR: Inventory is full and no space for harvested herbs!")
		print("Make sure you have existing stacks of the herbs your seeds will produce,")
		print("or free up some inventory space before planting.")
	elseif not hasSeeds then
		print("ERROR: No plantable herb seeds found in inventory!")
		print("Make sure you have herb seeds that match your Farming level.")
	end
	return
end

print("Found " .. #initialSeeds .. " plantable seed type(s)")
print("Location check passed - starting farming operations...")

API.Write_fake_mouse_do(false)
API.SetDrawTrackedSkills(true)

while API.Read_LoopyLoop() do
	if not API.ReadPlayerMovin2() and not API.CheckAnim(5) then
		if not API.DoRandomEvents(600, 600) then
			dropWeeds()
			local success = handlePatch()

			if not success then
				print("Planting complete or no more work to do. Stopping script.")
				API.Write_LoopyLoop(false)
				break
			end
		end
	end

	::continue::
	API.RandomSleep2(300, 200, 100)
end
