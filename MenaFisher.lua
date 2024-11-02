API = require('api')

MAX_IDLE_TIME_MINUTES = 5
NEED_BAIT = true

ID = {
    MEENA = 24552,
    FISHINGSPOT = { 24572, 24574 },
    BANKCHEST = { 107496, 107497, 107737 },
    BAIT = 313
}

AREAS = {
    LODESTONE = { x = 3216, y = 2716, z = 0 },
    VIPAREA = { x = 3183, y = 2750 , z = 0 },
    BAITSHOP = { x = 3213, y = 2664, z = 0 },
    PORT = { x = 3213, y = 2626, z = 0 },
}

local lastSpot = nil

local function findNpc(npcID, distance)
    distance = distance or 25
    local allNpc = API.GetAllObjArrayInteract(npcID, distance, {1})
    return allNpc[1] or false
end

local function spotCheck()
    if lastSpot ~= nil then
        local spot = findNpc(ID.FISHINGSPOT, 20)
        if spot then
            if spot.CalcX == lastSpot[1] and spot.CalcY == lastSpot[2] then
                return true
            end
        end
    end
    return false
end

local function deposit()
    API.DoAction_Object1(0x29, API.GeneralObject_route_useon, ID.BANKCHEST, 50)
    API.RandomSleep2(600, 300, 300)
end

local function fish()
    local spot = findNpc(ID.FISHINGSPOT, 20)
    if spot then
        if API.DoAction_NPC(0x3c, API.OFF_ACT_InteractNPC_route, ID.FISHINGSPOT, 50) then
            lastSpot = { spot.CalcX, spot.CalcY }
            API.RandomSleep2(600, 300, 300)
        end
    end
end

local function checkBait()
    if NEED_BAIT and API.InvStackSize(ID.BAIT) == 0 then
        print("No more bait")
        return false
    end
    return true
end

local function isAtMenaphos()
    local isInVIPArea = API.PInArea(AREAS.VIPAREA.x, 10, AREAS.VIPAREA.y, 10, 0)
    local isInPortArea = API.PInArea(AREAS.PORT.x, 10, AREAS.PORT.y, 10, 0)
    if isInVIPArea or isInPortArea then
        return true
    else
        print("Not in VIP area or port area")
        return false
    end
end

API.SetDrawTrackedSkills(true)
API.SetMaxIdleTime(MAX_IDLE_TIME_MINUTES)

while API.Read_LoopyLoop() do

    if not checkBait() or not isAtMenaphos() then
        API.Write_LoopyLoop(false)
        break
    end

    if API.ReadPlayerMovin2() or API.CheckAnim(3) then
        if spotCheck() or API.InvFull_() then
            goto continue
        end
        API.RandomSleep2(400, 300, 300)
    end

    if API.InvFull_() then
        deposit()
    else
        fish()
        API.CheckAnim(200)
    end

    ::continue::
    API.RandomSleep2(200, 200, 200)
end