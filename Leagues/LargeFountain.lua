--[[
====================================================================================================
Ornamental Fountain Script
====================================================================================================
Version: 1.0
Author: Higgins
Description: Builds and removes Ornamental Fountains for construction XP using marble blocks

Starting Location: Near Sawmill operator in Prifddinas or at House Portal

Requirements:
- Marble blocks (8786) in inventory or access to Sawmill operator
- House with Centrepiece space
- Construction level to build Ornamental Fountain

How it works:
1. Buys marble blocks from Sawmill operator if needed
2. Enters house building mode
3. Builds Ornamental Fountain at Centrepiece space
4. Removes the fountain
5. Repeats until marble blocks run low (less than 3)

====================================================================================================
]]
--

local API = require("api")

local INTERFACE_IDS = {
	SHOP_OPEN = { { 1265, 7, -1, 0 }, { 1265, 216, -1, 0 }, { 1265, 216, 14, 0 } },
	BUILD_MENU = 2874,
}

local ITEM_IDS = {
	MARBLE_BLOCK = 8786,
}

local OBJECT_IDS = {
	ORNAMENTAL_FOUNTAIN = 13480,
}

local SETTINGS = {
	PROCESSING = 2229,
	PRIFF_POS = { x = 2168, y = 3335, range = 50 },
	PRIFF_REGION = 8500,
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

local function calculateMetrics(startTime)
	local timeElapsed = os.time() - startTime
	local marbleInInv = Inventory:GetItemAmount(ITEM_IDS.MARBLE_BLOCK)

	return {
		{ "Script", "Ornamental Fountain" },
		{ "Marble Blocks:", tostring(marbleInInv) },
		{
			"Runtime:",
			string.format("%02d:%02d:%02d", timeElapsed // 3600, (timeElapsed % 3600) // 60, timeElapsed % 60),
		},
	}
end

local function isNotBusy()
	return (not API.isProcessing() or API.VB_FindPSettinOrder(SETTINGS.PROCESSING).state == 0)
		and not API.ReadPlayerMovin2()
end

local function isInPriff()
	local pos = SETTINGS.PRIFF_POS
	local playerPos = API.PlayerCoordfloat()
	local inRange = API.PInArea(pos.x, pos.range, pos.y, pos.range, 0)
	local inRegion = API.PlayerRegion().z == SETTINGS.PRIFF_REGION
	return inRange or inRegion
end

local function isInHouse()
	-- Check for Portal (indicates we're in house)
	local portal = API.GetAllObjArray1({ 13405 }, 50, { 0 })
	return #portal > 0
end

local function isShopOpen()
	return API.ScanForInterfaceTest2Get(false, INTERFACE_IDS.SHOP_OPEN)[1].textids == "Construction Supplies"
end

local function isBuildMenuOpen()
	return API.VB_FindPSettinOrder(INTERFACE_IDS.BUILD_MENU).state == 75
end

local function buyMarbleBlocks()
	if isShopOpen() then
		-- Buy marble blocks (x2 command)
		API.DoAction_Interface(0xffffffff, 0xffffffff, 7, 1265, 20, 6, API.OFF_ACT_GeneralInterface_route2)
		API.RandomSleep2(200, 200, 200)
		API.DoAction_Interface(0xffffffff, 0xffffffff, 7, 1265, 20, 6, API.OFF_ACT_GeneralInterface_route2)
		API.RandomSleep2(300, 550, 650)
	else
		Interact:NPC("Sawmill operator", "Trade", 30)
		API.RandomSleep2(200, 200, 200)
	end
end

local function enterBuildingMode()
	if isInPriff() then
		Interact:Object("House Portal", "Enter building mode", 30)
		API.RandomSleep2(2000, 1000, 500)
	end
end

local function buildFountain()
	if isInHouse() and not isBuildMenuOpen() then
		-- Look for Centrepiece space and build
		Interact:Object("Centrepiece space", "Build", 30)
		API.RandomSleep2(100, 100, 100)
	elseif isBuildMenuOpen() then
		-- Press 6 to select Ornamental Fountain
		API.KeyboardPress2(0x36, 60, 120) -- Key '6'
		API.RandomSleep2(800, 400, 200)
	end
end

local function removeFountain()
	if isInHouse() then
		-- Remove the Ornamental Fountain
		API.DoAction_Object1(0x29, API.GeneralObject_route_useon, { 13480 }, 50)
		API.RandomSleep2(1000, 500, 300)
	end
end

local function exitHouse()
	if isInHouse() then
		Interact:Object("Portal", "Enter", 30)
		API.RandomSleep2(2000, 1000, 500)
	end
end

local startTime = os.time()
API.SetDrawTrackedSkills(true)
API.Write_fake_mouse_do(false)

while API.Read_LoopyLoop() do
	API.DrawTable(calculateMetrics(startTime))

	local marbleBlocks = Inventory:GetItemAmount(ITEM_IDS.MARBLE_BLOCK)

	-- Stop if we have less than 3 marble blocks
	if marbleBlocks < 3 then
		if isInPriff() then
			if Inventory:FreeSpaces() > 0 and isNotBusy() then
				buyMarbleBlocks()
			elseif marbleBlocks >= 3 then
				enterBuildingMode()
			end
		elseif isInHouse() then
			exitHouse()
		end
	else
		-- We have enough marble blocks
		if isInPriff() then
			enterBuildingMode()
		elseif isInHouse() then
			-- Check if fountain exists to remove, otherwise build
			local ornamentalFountain = API.GetAllObjArray1({ OBJECT_IDS.ORNAMENTAL_FOUNTAIN }, 50, { 0 })
			if #ornamentalFountain > 0 then
                API.RandomSleep2(200, 250, 250)
				removeFountain()
			else
				buildFountain()
			end
		end
	end

	API.RandomSleep2(100, 250, 250)
end
