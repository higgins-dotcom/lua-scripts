API = require('API')

SetMaxIdleTime(10)
API.SetDrawTrackedSkills(true)

local STATE = {
    FISH = 1,
    COOK = 2,
    DROP = 3
}

local ID = {
    FISHING_SPOT = 328,
    FISH = { 335, 331 },
    COOKED_FISH = { 333, 329, 343 }
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

local function drop()
    local inv = API.ReadInvArrays33()
    for _, v in ipairs(inv) do
        for __, vv in ipairs(ID.COOKED_FISH) do
            if v.itemid1 == vv then
                API.DoAction_Interface(0x24, v.itemid1, 8, 1473, 5, _ - 1, API.OFF_ACT_GeneralInterface_route2)
                return true
            end
        end
    end
    return false
end

local function invContains(items)
    return Inventory:ContainsAny(items)
end

local function hasRawFish()
    return invContains(ID.FISH)
end

local function hasCookedFish()
    return invContains(ID.COOKED_FISH)
end

local function cook()

    local tool = false
    local food = false

    local chooseTool = API.ScanForInterfaceTest2Get(false, {{ 1179,0,-1,0 }, { 1179,99,-1,0 }, { 1179,99,14,0 }})
    if #chooseTool > 0 then
        if string.find(chooseTool[1].textids, "Choose a tool") then
            tool = true
        end
    end

    if API.VB_FindPSettinOrder(8847) > 0 then
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

state = STATE.DROP

while API.Read_LoopyLoop() do
    break
    if Inventory:GetItemAmount(314) < 1 then
        break
    end

    if state == STATE.DROP then
        goto dropp
    end

    if API.isProcessing() then
        goto continue
    end

    if API.ReadPlayerMovin2() or API.CheckAnim(35) then
        if spotCheck() or Inventory:IsFull() then
            goto continue
        end
    end

    if state == STATE.COOK then
        if hasRawFish() then
            cook()
            goto continue
        elseif hasCookedFish() then
            state = STATE.DROP
        end
    end

    ::dropp::
    if state == STATE.DROP then
        if not drop() then state = STATE.FISH end
        API.RandomSleep2(100, 100, 100)
    elseif state == STATE.FISH then
        if Inventory:IsFull() then
            state = STATE.COOK
        else
            if not (Inventory:GetItemAmount(1511) > 0 and not API.CheckAnim(10)) then
                if not API.DoAction_Object_valid2(0x3b, 0, { 38783 }, 50, WPOINT.new(3104, 3433, 0), true) then
                    API.DoAction_Object_valid2(0x3b, 0, { 38760 }, 50, WPOINT.new(3104, 3433, 0), true)
                end
                API.RandomSleep2(600, 600, 600)
                goto continue
            else
                fish()
                API.CheckAnim(200)
            end
        end
    end

    ::continue::
    API.RandomSleep2(300, 300, 300)
end