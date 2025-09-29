--[[
====================================================================================================
Buy Supers Script
====================================================================================================
Version: 1.0
Author: Higgins
Description: Efficiently buys multiple super potions and food from Goebie supplier

Starting Location: Near the Goebie supplier
Requirements: Access to Goebie supplier, GP for purchases

Configuration: Edit ITEM_CONFIG below to set quantities (0 = skip item)
====================================================================================================
]]

local API = require("api")

-- ================================================================================================
-- CONFIGURATION
-- ================================================================================================

local ITEM_CONFIG = {
	[3024] = 0, -- Super Restore (4)
	[2436] = 0, -- Super Attack (4)
	[2440] = 0, -- Super Strength (4)
	[2442] = 0, -- Super Defence (4)
	[3040] = 0, -- Super Magic Potion (4)
	[2444] = 0, -- Super Ranging Potion (4)
	[55316] = 0, -- Super Necromancy (4)
	[12140] = 0, -- Summoning Potion (4)
	[35199] = 0, -- Cooked Eeligator
}

-- ================================================================================================
-- CONSTANTS & DATA
-- ================================================================================================

local ITEM_DATA = {
	[35199] = { name = "Cooked Eeligator", slot = 0 },
	[3024] = { name = "Super Restore (4)", slot = 1 },
	[12140] = { name = "Summoning Potion (4)", slot = 2 },
	[2436] = { name = "Super Attack (4)", slot = 3 },
	[2440] = { name = "Super Strength (4)", slot = 4 },
	[2442] = { name = "Super Defence (4)", slot = 5 },
	[3040] = { name = "Super Magic Potion (4)", slot = 6 },
	[2444] = { name = "Super Ranging Potion (4)", slot = 7 },
	[55316] = { name = "Super Necromancy (4)", slot = 8 },
}

local INTERFACE_IDS = {
	SHOP = 18,
	BANK = 24,
	ITEM_SELECTION = 300,
	PROCESSING = 2229,
}

-- ================================================================================================
-- STATE MANAGEMENT
-- ================================================================================================

local State = {
	totalPurchased = {},
	itemList = {},
	finalBankDone = false,
}

-- Initialize state
for itemId, targetAmount in pairs(ITEM_CONFIG) do
	if targetAmount > 0 then
		table.insert(State.itemList, itemId)
		State.totalPurchased[itemId] = 0
	end
end

-- ================================================================================================
-- UTILITY FUNCTIONS
-- ================================================================================================

local function getItemName(itemId)
	return ITEM_DATA[itemId] and ITEM_DATA[itemId].name or "Item " .. itemId
end

local function getItemSlot(itemId)
	return ITEM_DATA[itemId] and ITEM_DATA[itemId].slot
end

local function formatTime(seconds)
	return string.format("%02d:%02d:%02d", seconds // 3600, (seconds % 3600) // 60, seconds % 60)
end

local function getTotalItemCount(itemId)
	local banked = State.totalPurchased[itemId] or 0
	local inInventory = Inventory:GetItemAmount(itemId)
	return banked + inInventory
end

-- ================================================================================================
-- INTERFACE & STATE CHECKS
-- ================================================================================================

local function isNotBusy()
	return (not API.isProcessing() or API.VB_FindPSettinOrder(INTERFACE_IDS.PROCESSING).state == 0)
		and not API.ReadPlayerMovin2()
end

local function isShopOpen()
	return API.VB_FindPSettinOrder(2874).state == INTERFACE_IDS.SHOP
end

local function isBankOpen()
	return API.VB_FindPSettinOrder(2874).state == INTERFACE_IDS.BANK
end

local function isCorrectItemSelected(itemId)
	return API.VB_FindPSettinOrder(INTERFACE_IDS.ITEM_SELECTION).state == itemId
end

-- ================================================================================================
-- PROGRESS & METRICS
-- ================================================================================================

local function calculateMetrics(startTime)
	local timeElapsed = os.time() - startTime
	local metrics = {
		{ "Script", "Buy Supers" },
		{ "Runtime:", formatTime(timeElapsed) },
	}

	for itemId, targetAmount in pairs(ITEM_CONFIG) do
		if targetAmount > 0 then
			local total = getTotalItemCount(itemId)
			local itemName = getItemName(itemId)
			table.insert(metrics, { itemName .. ":", total .. "/" .. targetAmount })
		end
	end

	return metrics
end

local function isAllItemsComplete()
	for itemId, targetAmount in pairs(ITEM_CONFIG) do
		if targetAmount > 0 and getTotalItemCount(itemId) < targetAmount then
			return false
		end
	end
	return true
end

local function getCurrentItem()
	for _, itemId in ipairs(State.itemList) do
		local targetAmount = ITEM_CONFIG[itemId]
		if getTotalItemCount(itemId) < targetAmount then
			return itemId
		end
	end
	return nil
end

-- ================================================================================================
-- CORE ACTIONS
-- ================================================================================================

local function selectItem(itemId)
	if not isCorrectItemSelected(itemId) then
		local slot = getItemSlot(itemId)
		if slot then
			API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1265, 20, slot, API.OFF_ACT_GeneralInterface_route)
			API.RandomSleep2(200, 200, 200)
		end
	end
end

local function buyItem(itemId)
	if isShopOpen() then
		selectItem(itemId)
		if isCorrectItemSelected(itemId) then
			API.DoAction_Interface(0x24, 0xffffffff, 1, 1265, 144, -1, API.OFF_ACT_GeneralInterface_route)
			API.RandomSleep2(150, 150, 100)
		end
	else
		Interact:NPC("Goebie supplier", "Shop", 30)
		API.RandomSleep2(200, 300, 300)
	end
end

local function countAndBankItems(forceBank)
	local shouldBank = Inventory:FreeSpaces() == 0 or forceBank

	if shouldBank then
		if isBankOpen() then
			-- Count items before banking
			for itemId, _ in pairs(ITEM_CONFIG) do
				local itemsInInv = Inventory:GetItemAmount(itemId)
				if itemsInInv > 0 then
					State.totalPurchased[itemId] = (State.totalPurchased[itemId] or 0) + itemsInInv
				end
			end

			API.KeyboardPress2(0x33, 60, 120) -- Deposit all
			API.RandomSleep2(300, 300, 300)
		else
			Interact:NPC("Goebie supplier", "Bank", 30)
			API.RandomSleep2(300, 200, 150)
		end
	end
end

-- ================================================================================================
-- MAIN LOGIC
-- ================================================================================================

local function handleShopping()
	local currentItem = getCurrentItem()
	if currentItem and Inventory:FreeSpaces() > 0 and isNotBusy() then
		buyItem(currentItem)
	else
		countAndBankItems(false)
	end
end

local function handleCompletion()
	if not State.finalBankDone then
		print("All items purchased! Banking final items...")
		countAndBankItems(true)
		State.finalBankDone = true
	else
		print("All configured items have been purchased and banked! Stopping script.")
		API.Write_LoopyLoop(false)
	end
end

-- ================================================================================================
-- PREFLIGHT CHECKS
-- ================================================================================================

local function isInCorrectArea()
	local playerPos = API.PlayerCoordfloat()
	local targetX, targetY = 4187, 926
	local range = 20

	local inRange = math.abs(playerPos.x - targetX) <= range and math.abs(playerPos.y - targetY) <= range
	return inRange
end

-- ================================================================================================
-- SCRIPT EXECUTION
-- ================================================================================================

-- Validate configuration
if #State.itemList == 0 then
	print("ERROR: No items configured for purchase! Please set target amounts in ITEM_CONFIG.")
	return
end

-- Location check
if not isInCorrectArea() then
	local playerPos = API.PlayerCoordfloat()
	print("ERROR: Player not in correct area!")
	print("Required: Near coordinates (4187, 926)")
	print("Current position: (" .. math.floor(playerPos.x) .. ", " .. math.floor(playerPos.y) .. ")")
	print("Please move to the Goebie supplier area before running this script.")
	return
end

-- Early completion check
if isAllItemsComplete() then
	print("All configured items have already been purchased!")
	return
end

local startTime = os.time()

print("Starting Buy Supers script...")
print("Items to purchase: " .. #State.itemList)
API.Write_fake_mouse_do(false)

while API.Read_LoopyLoop() do
	API.DrawTable(calculateMetrics(startTime))

	if isAllItemsComplete() then
		handleCompletion()
	else
		handleShopping()
	end

	API.RandomSleep2(100, 150, 150)
end
