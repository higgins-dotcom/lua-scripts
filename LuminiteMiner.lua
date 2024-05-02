local API = require('API')

local ID = {
    LUMINITE = { 113056, 113057, 113058 },
    SPARKLES = { 7164, 7165 },
    FURNACE = 113265,
    LADDER_DOWN = 2113,
    LADDER_UP = 6226,
    GATE = 2112,
    ORE = 44820
}

local LOCATION = {
    BANK = 1,
    MINE = 2
}

local REGIONS = {
    UPTOP = { x = 47, y = 52 },
    DOWNLOW = { x = 47, y = 152 }
}

local AREA = {
    LUMINITE = { x1 = 3030, x2 = 3047, y1 = 9757, y2 = 9765 }
}

local afk, startTime = os.time(), os.time()
local destination, oldRock
local staminaZero, ores = 0, 0

local function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random(180, 280)

    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
    end
end

local function walk()
    local playerRegion = API.PlayerRegion()
    if destination == LOCATION.BANK then
        if API.PInArea21(AREA.LUMINITE.x1, AREA.LUMINITE.x2, AREA.LUMINITE.y1, AREA.LUMINITE.y2) then
            API.DoAction_Object1(0x31, API.OFF_ACT_GeneralObject_route0, { ID.GATE }, 50)
        elseif not (playerRegion.y == REGIONS.UPTOP.y) then
            API.DoAction_Object1(0x34, API.OFF_ACT_GeneralObject_route0, { ID.LADDER_UP }, 50);
            API.RandomSleep2(600, 600, 600)
        else
            if API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route1, { ID.FURNACE }, 50) then
                ores = ores + 120
                ores = ores + API.InvItemcount_1(ID.ORE)

                local elapsedMinutes = (os.time() - startTime) / 60
                local oresPH = math.floor((ores * 60) / elapsedMinutes);
                API.Write_ScripCuRunning0("Ores P/H " .. oresPH)
            end
        end
        API.RandomSleep2(800, 600, 300)
    elseif destination == LOCATION.MINE then
        if not (playerRegion.y == REGIONS.DOWNLOW.y) then
            API.DoAction_Object1(0x35, API.OFF_ACT_GeneralObject_route0, { ID.LADDER_DOWN }, 50)
            API.RandomSleep2(600, 600, 600)
        elseif not API.PInArea21(AREA.LUMINITE.x1, AREA.LUMINITE.x2, AREA.LUMINITE.y1, AREA.LUMINITE.y2) then
            API.DoAction_Object1(0x31, API.OFF_ACT_GeneralObject_route0, { ID.GATE }, 50)
        else 
            return true
        end
        API.RandomSleep2(800, 600, 300)
    end
    return false
end

local function findRock()

    local hlObjs = API.GetAllObjArray1(ID.SPARKLES, 15, {4})
    local allObj = API.GetAllObjArray1(ID.LUMINITE, 15, {0})

    if #hlObjs > 0 then
        for _, v in pairs(allObj) do
            for _, h in pairs(hlObjs) do
                if math.abs(v.Tile_XYZ.x - h.Tile_XYZ.x) < 1 and math.abs(v.Tile_XYZ.y - h.Tile_XYZ.y) < 1 then
                    return v
                end
            end
        end
    else
        if oldRock ~= nil then
            return oldRock
        end
    end
    return allObj[1]
end

local function clickRock(rock)

    if API.DoAction_Object_Direct(0x3A, API.OFF_ACT_GeneralObject_route0, rock) then
        oldRock = rock
        API.RandomSleep2(600, 600, 600) 
    end
end

local function mine()
    local isAnimating = API.CheckAnim(25)
    local rock = findRock()
    local rockCheck = (oldRock ~= nil) and (rock.Id == oldRock.Id)
    if isAnimating and rockCheck then
        local stamina = API.LocalPlayer_HoverProgress()
        if stamina <= 200 then
            if stamina == 0 then
                if staminaZero < 3 then
                    staminaZero = staminaZero + 1
                    return false
                end
                staminaZero = 0
            end
            clickRock(rock)
            API.RandomSleep2(1200, 600, 600)
        end
    else
        clickRock(rock)
        API.RandomSleep2(1600, 600, 600)
    end
end

local function isOreBoxFull()
    return ((API.VB_FindPSettinOrder(8316).state >> 0) & 0x3fff) == 120
end

local function fillOreBox()
    API.KeyboardPress2(0x58, 60, 120)
    API.RandomSleep2(400, 200, 200)
end

API.SetDrawTrackedSkills(true)

while API.Read_LoopyLoop() do
    API.DoRandomEvents()
    idleCheck()

    if (API.GetGameState2() ~= 3) then
        break
    end

    if API.ReadPlayerMovin2() then
        API.RandomSleep2(300, 200, 200)
        goto continue
    end

    if API.InvFull_() then
        if not isOreBoxFull() then
            fillOreBox()
        else
            destination = LOCATION.BANK
            walk()
        end
    else
        destination = LOCATION.MINE
        if walk() then
            mine()
        end
    end

    ::continue::
    API.RandomSleep2(200, 200, 200)
end
