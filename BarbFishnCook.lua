API = require("API")

SetMaxIdleTime(10)
API.SetDrawTrackedSkills(true)

-- User Configuration
local COOK_FISH = true -- Set to false if you only want to fish and drop raw fish

local STATE = {
	FISH = 1,
	COOK = 2,
	DROP = 3,
}

local ID = {
	FISHING_SPOT = 328,
	FISH = { 335, 331 },
	COOKED_FISH = { 333, 329, 343 },
}

local state = STATE.FISH
local lastSpot = nil

local function findNpc(npcID, distance)
	distance = distance or 25
	local allNpc = API.GetAllObjArrayInteract({ npcID }, distance, { 1 })
	return allNpc[1] or false
end

local function fish()
	local spot = findNpc(ID.FISHING_SPOT, 20)
	if spot then
		lastSpot = { spot.CalcX, spot.CalcY }
		API.DoAction_NPC__Direct(0x3c, API.OFF_ACT_InteractNPC_route, spot)
		API.RandomSleep2(600, 300, 300)
	end
end

local function spotCheck()
	if lastSpot ~= nil then
		local spot = findNpc(ID.FISHING_SPOT, 20)
		if spot then
			if spot.CalcX == lastSpot[1] and spot.CalcY == lastSpot[2] then
				return true
			end
		end
	end
	return false
end

local function invContains(items)
	local inv = API.ReadInvArrays33()
	for _, item in ipairs(inv) do
		for _, targetId in ipairs(items) do
			if item.itemid1 == targetId then
				return true
			end
		end
	end
	return false
end

local function hasRawFish()
	return invContains(ID.FISH)
end

local function hasCookedFish()
	return invContains(ID.COOKED_FISH)
end

local function dropItems(itemIds)
	local inv = API.ReadInvArrays33()
	for i, item in ipairs(inv) do
		for _, targetId in ipairs(itemIds) do
			if item.itemid1 == targetId then
				API.DoAction_Interface(0x24, item.itemid1, 8, 1473, 5, i - 1, API.OFF_ACT_GeneralInterface_route2)
				API.RandomSleep2(100, 50, 50)
				return true
			end
		end
	end
	return false
end

local function drop()
	if COOK_FISH then
		return dropItems(ID.COOKED_FISH)
	else
		return dropItems(ID.FISH)
	end
end

local function cook()
	local tool = false
	local food = false

	local chooseTool =
		API.ScanForInterfaceTest2Get(false, { { 1179, 0, -1, 0 }, { 1179, 99, -1, 0 }, { 1179, 99, 14, 0 } })
	if #chooseTool > 0 then
		if string.find(chooseTool[1].textids, "Choose a tool") then
			tool = true
		end
	end

	if API.VB_FindPSettinOrder(8847).state > 0 then
		food = true
	end

	if API.Compare2874Status(1277970) or API.VB_FindPSettinOrder(2874).state == 1277970 or tool then
		API.KeyboardPress2(0x31, 60, 120)
		API.RandomSleep2(200, 200, 200)
	elseif API.Compare2874Status(1310738) or API.VB_FindPSettinOrder(2874).state == 1310738 or food then
		API.KeyboardPress2(0x20, 60, 120)
		API.RandomSleep2(600, 200, 200)
	else
		if not API.DoAction_Object1(0x2e, GeneralObject_route_useon, { 70755 }, 50) then
			if Inventory:GetItemAmount(1511) > 0 then
				API.DoAction_Inventory1(1511, 0, 2, API.OFF_ACT_GeneralInterface_route) -- create fire
				API.RandomSleep2(600, 300, 300)
			end
		end
	end
end

print("Barb Fish & Cook Script Started")
print("Cook Fish Setting: " .. tostring(COOK_FISH))

while API.Read_LoopyLoop() do
	if Inventory:GetItemAmount(314) < 1 then
		print("No feathers found, stopping script")
		break
	end

	if API.isProcessing() then
		goto continue
	end

	if API.ReadPlayerMovin2() or API.CheckAnim(35) then
		if spotCheck() or Inventory:IsFull() then
			goto continue
		end
	end

	if state == STATE.FISH then
		if Inventory:IsFull() then
			if COOK_FISH and hasRawFish() then
				state = STATE.COOK
			else
				state = STATE.DROP
			end
		else
			if not (Inventory:GetItemAmount(1511) > 0 and not API.CheckAnim(10)) then
				if not API.DoAction_Object_valid2(0x3b, API.OFF_ACT_GeneralObject_route0, { 38783 }, 50, WPOINT.new(3104, 3433, 0), true) then
					API.DoAction_Object_valid2(0x3b, API.OFF_ACT_GeneralObject_route0, { 38760 }, 50, WPOINT.new(3104, 3433, 0), true)
				end
				API.RandomSleep2(600, 600, 600)
			else
				fish()
				API.CheckAnim(200)
			end
		end
	elseif state == STATE.COOK then
		if hasRawFish() then
			cook()
		else
			state = STATE.DROP
		end
	elseif state == STATE.DROP then
		if drop() then
			API.RandomSleep2(100, 50, 50)
		else
			state = STATE.FISH
		end
	end

	::continue::
	API.RandomSleep2(300, 200, 200)
end

print("Script ended")