--[[
====================================================================================================
Jug of Wine Script
====================================================================================================
Version: 1.0
Author: Higgins
Description: Makes jugs of wine by using grapes on jugs of water

Starting Location: Anywhere with bank access

Requirements:
- Grapes (1987) in inventory
- Jugs of water (1937) in inventory
- Bank preset configured

How it works:
1. Uses grapes on jugs of water to make wine
2. Banks finished products using last preset
3. Repeats the process

====================================================================================================
]]
--

local API = require("api")

local ITEM_IDS = {
	GRAPES = 1987,
	JUG_OF_WATER = 1937,
}

local SETTINGS = {
	PROCESSING = 2229,
	COOKING_WINDOW = 2874,
	COOKING_CHECK = 8847,
}

local function isNotBusy()
	return (not API.isProcessing() or API.VB_FindPSettinOrder(SETTINGS.PROCESSING).state == 0)
		and not API.ReadPlayerMovin2()
end

local function isCookingWindowOpen()
	return API.VB_FindPSettinOrder(SETTINGS.COOKING_WINDOW).state == 40
		or API.VB_FindPSettinOrder(SETTINGS.COOKING_WINDOW).state == 1310738
end

local function makeWine()
	local grapes = Inventory:GetItemAmount(ITEM_IDS.GRAPES)
	local jugsOfWater = Inventory:GetItemAmount(ITEM_IDS.JUG_OF_WATER)

	if isCookingWindowOpen() and API.VB_FindPSettinOrder(SETTINGS.COOKING_CHECK).state > 0 then
		API.KeyboardPress2(0x20, 60, 120) -- Space key
		API.RandomSleep2(300, 200, 100)
	elseif grapes > 0 and jugsOfWater > 0 and isNotBusy() and not isCookingWindowOpen() then
		Inventory:UseItemOnItem(ITEM_IDS.GRAPES, ITEM_IDS.JUG_OF_WATER)
		API.RandomSleep2(300, 300, 200)
	end
end

local function bankItems(retryCount)
	local grapes = Inventory:GetItemAmount(ITEM_IDS.GRAPES)
	local jugsOfWater = Inventory:GetItemAmount(ITEM_IDS.JUG_OF_WATER)
	retryCount = retryCount or 0

	if grapes == 0 or jugsOfWater == 0 then
		Interact:Object("Chest", "Load Last Preset from", 30)
		API.RandomSleep2(2000, 1000, 500)

		local newGrapes = Inventory:GetItemAmount(ITEM_IDS.GRAPES)
		local newJugsOfWater = Inventory:GetItemAmount(ITEM_IDS.JUG_OF_WATER)

		if newGrapes == 0 or newJugsOfWater == 0 then
			retryCount = retryCount + 1
			if retryCount >= 3 then
				print("ERROR: Bank appears to be out of grapes or jugs of water!")
				print("Preset load failed after 3 attempts - stopping script.")
				API.Write_LoopyLoop(false)
			else
				print("Preset load failed, retrying... (" .. retryCount .. "/3)")
				return retryCount
			end
		else
			return 0 -- Reset retry count on success
		end
	end
	return retryCount or 0
end

API.SetDrawTrackedSkills(true)
API.Write_fake_mouse_do(false)

local retryCount = 0

while API.Read_LoopyLoop() do
	local grapes = Inventory:GetItemAmount(ITEM_IDS.GRAPES)
	local jugsOfWater = Inventory:GetItemAmount(ITEM_IDS.JUG_OF_WATER)

	if grapes > 0 and jugsOfWater > 0 then
		retryCount = 0 -- Reset retry count when we have items
		makeWine()
	else
		retryCount = bankItems(retryCount)
	end

	API.RandomSleep2(300, 300, 300)
end
