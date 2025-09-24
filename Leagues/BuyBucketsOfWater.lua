--[[
====================================================================================================
Buy Buckets of Water Script
====================================================================================================
Version: 1.0
Author: Higgins
Description: Automatically buys buckets of water from Shanty at the Shantay Pass Shop with banking support

Starting Location: Shantay Pass

Requirements:
- Access to Shanty (NPC ID: 836) at the Shantay Pass Shop
- Access to bank (ID: 2693)
- Sufficient GP to purchase buckets
- Blank bank preset saved and loaded (for depositing all items)

How it works:
1. Talks to NPC to open shop
2. Buys buckets of water until inventory is full
3. Banks all items when inventory is full
4. Repeats the cycle continuously
5. Includes failsafes for shop opening and buying attempts

====================================================================================================
]]
--

local API = require("API")

-- Constants
local NPC_IDS = {
	SHANTY = 836, -- Shanty at Shantay Pass Shop
}

local OBJECT_IDS = {
	BANK = 2693,
}

local ITEM_IDS = {
	BUCKET_OF_WATER = 1929,
}

local INTERFACE_IDS = {
	BUY_BUTTON = { component = 1265, subcomponent = 20, option = 5 },
}

local VB_SETTINGS = {
	SHOP_INTERFACE = 2874,
	SHOP_OPEN_STATE = 18,
}

local SETTINGS = {
	MAX_SHOP_ATTEMPTS = 5,
	MAX_BUY_ATTEMPTS = 50,
	MAX_INVENTORY_BUCKETS = 28,
}

-- State Management
local ScriptState = {
	TALK_NPC = "TALK_NPC",
	CHECK_SHOP = "CHECK_SHOP",
	BUY_BUCKETS = "BUY_BUCKETS",
	BANK = "BANK",
}

local currentState = ScriptState.TALK_NPC
local shopAttempts = 0
local buyAttempts = 0

-- Utility Functions
local function isPlayerReady()
	return not API.ReadPlayerMovin2()
end

local function isShopOpen()
	local vb = API.VB_FindPSettinOrder(VB_SETTINGS.SHOP_INTERFACE)
	return vb and vb.state == VB_SETTINGS.SHOP_OPEN_STATE
end

local function isInventoryFull()
	return API.InvFull_() or API.InvItemcount_1(ITEM_IDS.BUCKET_OF_WATER) >= SETTINGS.MAX_INVENTORY_BUCKETS
end

-- Action Functions
local function talkToShanty()
	print("Talking to Shanty to open shop")
	API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route2, { NPC_IDS.SHANTY }, 50)
	API.RandomSleep2(400, 600, 600)
	currentState = ScriptState.CHECK_SHOP
	shopAttempts = 0
end

local function checkShopStatus()
	if isShopOpen() then
		print("Shop opened successfully")
		currentState = ScriptState.BUY_BUCKETS
		buyAttempts = 0
	else
		shopAttempts = shopAttempts + 1
		if shopAttempts > SETTINGS.MAX_SHOP_ATTEMPTS then
			print("Shop failed to open after " .. SETTINGS.MAX_SHOP_ATTEMPTS .. " attempts, restarting")
			currentState = ScriptState.TALK_NPC
			shopAttempts = 0
		else
			print("Waiting for shop to open... (attempt " .. shopAttempts .. ")")
		end
		API.RandomSleep2(500, 600, 700)
	end
end

local function buyBuckets()
	if isInventoryFull() then
		print("Inventory full, going to bank")
		currentState = ScriptState.BANK
	else
		print("Buying buckets of water")
		API.DoAction_Interface(
			0xffffffff,
			0xffffffff,
			7,
			INTERFACE_IDS.BUY_BUTTON.component,
			INTERFACE_IDS.BUY_BUTTON.subcomponent,
			INTERFACE_IDS.BUY_BUTTON.option,
			API.OFF_ACT_GeneralInterface_route2
		)
		API.RandomSleep2(200, 200, 200)
		buyAttempts = buyAttempts + 1

		-- Failsafe for buying attempts
		if buyAttempts > SETTINGS.MAX_BUY_ATTEMPTS then
			print("Too many buy attempts, restarting cycle")
			currentState = ScriptState.TALK_NPC
			buyAttempts = 0
		end
	end
end

local function bankItems()
	print("Banking items")
	API.DoAction_Object1(0x33, API.OFF_ACT_GeneralObject_route3, { OBJECT_IDS.BANK }, 50)
	API.RandomSleep2(800, 800, 800)
	currentState = ScriptState.TALK_NPC
end

-- State Handler
local function handleCurrentState()
	if currentState == ScriptState.TALK_NPC then
		talkToShanty()
	elseif currentState == ScriptState.CHECK_SHOP then
		checkShopStatus()
	elseif currentState == ScriptState.BUY_BUCKETS then
		buyBuckets()
	elseif currentState == ScriptState.BANK then
		bankItems()
	end
end

-- Main Script
print("Starting Buy Buckets of Water Script")

while API.Read_LoopyLoop() do
	if isPlayerReady() then
		handleCurrentState()
	end
	API.RandomSleep2(100, 100, 100)
end
