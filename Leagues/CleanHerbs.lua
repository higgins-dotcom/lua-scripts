--[[
====================================================================================================
Clean Herbs Script
====================================================================================================
Version: 2.0
Author: Higgins
Description: Automatically cleans grimy herbs from bank based on Herblore level

Starting Location: Near a bank
Requirements: Grimy herbs in bank, appropriate Herblore level

How it works:
1. Withdraws grimy herbs from bank (only those you can clean based on level)
2. Cleans all grimy herbs in inventory
3. Deposits clean herbs back to bank
4. Repeats until no more cleanable herbs remain

Level Requirements:
- Each herb type requires a specific Herblore level to clean
- Script automatically checks your level against herb requirements (item param 771)
====================================================================================================
]]

local API = require("API")

-- ================================================================================================
-- UTILITY FUNCTIONS
-- ================================================================================================

-- Cache for herb level requirements to avoid repeated Item:Get() calls
local herbLevelCache = {}

local function getCurrentHerbloreLevel()
	return API.GetSkillsTableSkill(30)
end

local function getHerbLevelRequirement(itemId)
	-- Check cache first
	if herbLevelCache[itemId] then
		return herbLevelCache[itemId]
	end

	-- Get the level requirement from item param 771
	local item = Item:Get(itemId)
	local levelReq = 99 -- Default to level 99 if no requirement found (safer)

	if item then
		levelReq = item:GetParam(771) or 99
	end

	-- Cache the result
	herbLevelCache[itemId] = levelReq
	return levelReq
end

local function canCleanHerb(itemId)
	local playerLevel = getCurrentHerbloreLevel()
	local requiredLevel = getHerbLevelRequirement(itemId)
	return playerLevel >= requiredLevel
end

-- ================================================================================================
-- INVENTORY & BANK FUNCTIONS
-- ================================================================================================

local function hasGrimyHerbs()
	local inv = API.ReadInvArrays33()
	for index, value in ipairs(inv) do
		if string.find(value.textitem, "Grimy") then
			return value.itemid1
		end
	end
	return false
end

local function withdrawGrimyHerbs()
	local inv = API.FetchBankArray()
	local playerLevel = getCurrentHerbloreLevel()

	for index, value in ipairs(inv) do
		if Inventory:IsFull() then
			break
		end

		if string.find(value.textitem, "Grimy") then
			-- Check if player can clean this herb type
			if canCleanHerb(value.itemid1) then
				if API.DoAction_Bank(value.itemid1, 7, API.OFF_ACT_GeneralInterface_route2) then
					API.RandomSleep2(300, 300, 300)
				end
			end
		end
	end
end

-- ================================================================================================
-- MAIN ACTIONS
-- ================================================================================================

local function cleanHerbs()
	local herb = hasGrimyHerbs()
	if herb and herb > 0 then
		-- Check for cleaning interface
		if API.VB_FindPSettinOrder(8847).state > 0 then
			API.KeyboardPress2(0x20, 60, 100) -- Space to clean
			API.RandomSleep2(300, 300, 300)
		else
			-- Start cleaning process
			API.DoAction_Inventory1(herb, 0, 1, API.OFF_ACT_GeneralInterface_route)
			API.RandomSleep2(300, 300, 300)
		end
	end
end

local function handleBanking()
	if API.BankOpen2() then
		if Inventory:IsFull() and not hasGrimyHerbs() then
			-- Deposit clean herbs
			API.KeyboardPress2(0x33, 60, 100) -- Deposit all
			API.RandomSleep2(300, 300, 300)
		elseif Inventory:IsFull() and hasGrimyHerbs() then
			-- Close bank to continue cleaning
			API.KeyboardPress2(0x1B, 60, 100) -- ESC
			API.RandomSleep2(300, 300, 300)
		else
			-- Withdraw more grimy herbs
			withdrawGrimyHerbs()
		end
	else
		-- Open bank
		Interact:Object("Bank chest", "Use", 30)
		API.RandomSleep2(600, 300, 300)
	end
end

-- ================================================================================================
-- SCRIPT EXECUTION
-- ================================================================================================

print("Starting Clean Herbs script...")
print("Current Herblore level: " .. getCurrentHerbloreLevel())

API.SetDrawTrackedSkills(true)
API.Write_fake_mouse_do(false)

while API.Read_LoopyLoop() do
	if not API.isProcessing() then
		local herb = hasGrimyHerbs()

		if herb and herb > 0 and not API.BankOpen2() then
			-- Clean herbs in inventory
			cleanHerbs()
		else
			-- Handle banking (withdraw/deposit)
			handleBanking()
		end
	end

	API.RandomSleep2(50, 100, 100)
end
