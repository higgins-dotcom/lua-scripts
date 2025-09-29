--[[
====================================================================================================
Buy Magic Stones Script
====================================================================================================
Version: 1.1
Author: Higgins
Description: Buys magic stones and disassembles them for GP - must have Perkfection relic (Leagues RS3)

Starting Location: Next to the Sawmill Operator in the Ithell district in Prifddinas

Requirements:
- Perkfection relic (Leagues RS3)
- Access to Sawmill operator
- Disassemble ability unlocked
- At least 975K GP or magic stones in inventory

How it works:
1. Buys magic stones from the Sawmill operator
2. Disassembles them for GP
3. Tracks GP gained and GP/hour metrics
4. Automatically handles high-value item confirmations

Tip: To avoid buy warning screens, increase the "Buy warning value" in game settings:
     Interfaces > Warning Screens > Buy warning value
     Set this to 30M to avoid warning screens during operation

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
	HIGH_VALUE = { { 847, 0, -1, 0 } },
}

local ITEM_IDS = {
	CRYSTAL = 8788,
}

local SETTINGS = {
	GP = 6480,
	PROCESSING = 2229,
	MIN_GP = 975000, -- Minimum GP required to start
	SAWMILL_POS = { x = 2171, y = 3339, range = 15 },
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

local function calculateMetrics(startGP, startTime)
	local currentGP = API.VB_FindPSettinOrder(SETTINGS.GP).state
	local gpGained = currentGP - startGP
	local timeElapsed = os.time() - startTime
	local gpPH = timeElapsed > 0 and math.floor((gpGained * 3600) / timeElapsed) or 0

	return {
		{ "Script", "Buy Stones" },
		{ "GP Gained:", formatNumber(gpGained) .. " (" .. formatNumber(gpPH) .. "/h)" },
	}
end

local function isShopOpen()
	return API.ScanForInterfaceTest2Get(false, INTERFACE_IDS.SHOP_OPEN)[1].textids == "Construction Supplies"
end

local function isBuying()
	local inter = API.ScanForInterfaceTest2Get(true, INTERFACE_IDS.BUYING_CHECK)
	return #inter > 0 and string.find(inter[1].textids, "You are buying") ~= nil
end

local function isHighValueDialogOpen()
	return #API.ScanForInterfaceTest2Get(true, INTERFACE_IDS.HIGH_VALUE) > 0
end

local function isNotBusy()
	return (not API.isProcessing() or API.VB_FindPSettinOrder(SETTINGS.PROCESSING).state == 0)
		and not API.ReadPlayerMovin2()
end

local function buyCrystal()
	if isShopOpen() then
		if isBuying() then
			API.DoAction_Interface(0x24, 0xffffffff, 1, 1265, 170, -1, API.OFF_ACT_GeneralInterface_route)
		else
			API.DoAction_Interface(0xffffffff, 0xffffffff, 7, 1265, 20, 8, API.OFF_ACT_GeneralInterface_route2)
		end
		API.RandomSleep2(300, 550, 650)
	else
		Interact:NPC("Sawmill operator", "Trade", 30)
		API.RandomSleep2(200, 200, 200)
	end
end

local function disassemble()
	if Inventory:GetItemAmount(ITEM_IDS.CRYSTAL) > 0 and isNotBusy() then
		API.DoAction_Ability("Disassemble", 1, API.OFF_ACT_Bladed_interface_route, false)
		API.RandomSleep2(600, 300, 200)

		API.DoAction_DontResetSelection()

		API.DoAction_Inventory1(ITEM_IDS.CRYSTAL, 0, 0, API.OFF_ACT_GeneralInterface_route1)
		API.RandomSleep2(800, 300, 200)

		if isHighValueDialogOpen() then
			API.KeyboardPress2(0x59, 60, 120)
			API.RandomSleep2(800, 900, 1200)
		end
	end
end

local function hasRequiredResources()
	local currentGP = API.VB_FindPSettinOrder(SETTINGS.GP).state
	local stonesInInv = Inventory:GetItemAmount(ITEM_IDS.CRYSTAL)

	return currentGP >= SETTINGS.MIN_GP or stonesInInv > 0
end

local function isInCorrectLocation()
	local pos = SETTINGS.SAWMILL_POS
	return API.PInArea(pos.x, pos.range, pos.y, pos.range, 0)
end

if not hasRequiredResources() then
	print("ERROR: Need at least " .. formatNumber(SETTINGS.MIN_GP) .. " GP or magic stones in inventory to start!")
	return
end

if not isInCorrectLocation() then
	local playerPos = API.PlayerCoordfloat()
	local pos = SETTINGS.SAWMILL_POS
	print("ERROR: Must be near the Sawmill operator in Prifddinas Ithell district")
	print("Required: Within " .. pos.range .. " tiles of (" .. pos.x .. ", " .. pos.y .. ")")
	print("Current position: (" .. math.floor(playerPos.x) .. ", " .. math.floor(playerPos.y) .. ")")
	return
end

API.Write_LoopyLoop(true)

local startGP = API.VB_FindPSettinOrder(SETTINGS.GP).state
local startTime = os.time()
API.Write_fake_mouse_do(false)

while API.Read_LoopyLoop() do
	API.DrawTable(calculateMetrics(startGP, startTime))

	if Inventory:FreeSpaces() >= 15 and isNotBusy() then
		buyCrystal()
	else
		disassemble()
	end

	API.RandomSleep2(300, 300, 300)
end
