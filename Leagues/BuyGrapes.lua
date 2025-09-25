--[[
====================================================================================================
Buy Grapes Script
====================================================================================================
Version: 1.0
Author: Higgins
Description: Buys grapes from Culinaromancer's Chest and banks them

Starting Location: Near the Culinaromancer's Chest

Requirements:
- Access to Culinaromancer's Chest
- Bank preset configured

How it works:
1. Opens the Culinaromancer's Chest with "Buy-food" action
2. Buys grapes until inventory is full
3. Banks items using last preset
4. Repeats the process

====================================================================================================
]]
--

local API = require("api")

local INTERFACE_IDS = {
	SHOP_OPEN = { { 1265, 7, -1, 0 }, { 1265, 216, -1, 0 }, { 1265, 216, 14, 0 } },
	BUYING_CHECK = {
		{ 1265, 7, -1, 0 },
		{ 1265, 9, -1, 0 },
		{ 1265, 150, -1, 0 },
		{ 1265, 152, -1, 0 },
		{ 1265, 154, -1, 0 },
	},
}

local ITEM_IDS = {
	GRAPES = 1987,
}

local SETTINGS = {
	PROCESSING = 2229,
}

local function formatNumber(num)
	local sign = num < 0 and "-" or ""
	local absNum = math.abs(num)

	if absNum >= 1000000000 then
		return sign .. string.format("%.2fB", absNum / 1000000000)
	elseif absNum >= 1000000 then
		return sign .. string.format("%.1fM", absNum / 1000000)
	elseif absNum >= 1000 then
		return sign .. string.format("%.1fK", absNum / 1000)
	else
		return tostring(num)
	end
end

local function calculateMetrics(startTime, totalGrapesBought)
	local timeElapsed = os.time() - startTime
	local grapesInInv = Inventory:GetItemAmount(ITEM_IDS.GRAPES)
	local grapesPH = timeElapsed > 0 and math.floor((totalGrapesBought * 3600) / timeElapsed) or 0

	return {
		{ "Script", "Buy Grapes" },
		{ "Grapes Bought:", formatNumber(totalGrapesBought) .. " (" .. formatNumber(grapesPH) .. "/h)" },
		{ "Grapes in Inv:", tostring(grapesInInv) },
		{
			"Runtime:",
			string.format("%02d:%02d:%02d", timeElapsed // 3600, (timeElapsed % 3600) // 60, timeElapsed % 60),
		},
	}
end

local function isShopOpen()
	return API.ScanForInterfaceTest2Get(false, INTERFACE_IDS.SHOP_OPEN)[1].textids == "Culinaromancer's Chest"
end


local function isNotBusy()
	return (not API.isProcessing() or API.VB_FindPSettinOrder(SETTINGS.PROCESSING).state == 0)
		and not API.ReadPlayerMovin2()
end

local function checkGrapesID()
	local vb300 = API.VB_FindPSettinOrder(300).state
	return vb300 == ITEM_IDS.GRAPES
end

local function selectGrapes()
	if not checkGrapesID() then
		API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1265, 20, 4, API.OFF_ACT_GeneralInterface_route)
		API.RandomSleep2(300, 550, 650)
	end
end

local function buyGrapes()
	if isShopOpen() then
		selectGrapes()

		if checkGrapesID() then
			API.DoAction_Interface(0x24, 0xffffffff, 1, 1265, 144, -1, API.OFF_ACT_GeneralInterface_route)
			API.RandomSleep2(50, 50, 50)
		end
	else
		Interact:Object("Chest", "Buy-food", 30)
		API.RandomSleep2(200, 200, 200)
	end
end

local function bankItems(totalGrapesBought)
	if Inventory:FreeSpaces() == 0 then
		local grapesBeforeBanking = Inventory:GetItemAmount(ITEM_IDS.GRAPES)
		totalGrapesBought = totalGrapesBought + grapesBeforeBanking

		Interact:Object("Chest", "Load Last Preset from", 30)
		API.RandomSleep2(100, 100, 100)
	end
	return totalGrapesBought
end

local startTime = os.time()
local totalGrapesBought = 0
local lastInventoryCount = 0

while API.Read_LoopyLoop() do
	API.DrawTable(calculateMetrics(startTime, totalGrapesBought))

	if Inventory:FreeSpaces() > 0 and isNotBusy() then
		buyGrapes()
	else
		totalGrapesBought = bankItems(totalGrapesBought)
	end

	API.RandomSleep2(100, 100, 100)
end
