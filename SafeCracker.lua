--[[
    Script: SafeCracker
    Description: Safe cracking

    Author: Higgins
    Version: 1.1
    Release Date: 18/01/2024

    Release Notes:
    - Version 1.0 : Initial release
    - Version 1.1 : Varrock Tele and Wildy Sword tele to Edgeville added
]]

-- Misthalin route (Bobs Axes, Roddecks House, Wizard's Tower, Edgeville, Draynor Manor, Varrock
-- You will need:
--    Loot bag
--    Stethoscope
--    Wicked Hood (In Inventory)
--    Lockpicks
--    Lodestones unlocked (Lumbridge, Draynor, Edgeville and Varrock)
--    If you have Ring of Fortune or Luck of the Dwarves then place it onto the Action Bar (else it will use Varrock lodestone)

-- [[ SETTINGS ]] --
local MAX_IDLE_TIME_MINUTES = 15
local rewardChoice = "Pilfer Points" -- Pilfer Points or Coins
-- [[ END SETTINGS ]] --

local API = require('API')

local ID = {
    SAFE = 111233,
    TRAPDOOR = 52309,
    CRACKING_ANIMATION = 31668,
    PULSE = 6882,
    WICKED_HOOD = 22332,
    WILDY_SWORD = { 37904, 37905, 37906, 37907, 41376, 41377 },
    LOCKPICK = 1523,
    STETHOSCOPE = 5560,
    GUILD_TELEPORT = 42619,
    DARREN = 11273,
    ROBIN = 11279,
    LOOT = { 42620, 42621, 42622, 42623, 42624, 42625, 42626, 42627 },
    BAG = { 42611, 42612, 42613, 42614 }
}

local AREA = {
    LUMBRIDGE_LODESTONE = { x = 3233, y = 3221, z = 0 },
    EDGEVILLE_LODESTONE = { x = 3067, y = 3505, z = 0 },
    DRAYNOR_LODESTONE = { x = 3106, y = 3299, z = 0 },
    VARROCK_LODESTONE = { x = 3214, y = 3376, z = 0 },
    BOBS_AXES = { x = 3230, y = 3203, z = 0 },
    RODDECKS_HOUSE = { x = 3231, y = 3231, z = 0 },
    WIZARDS_TOWER = { x = 3105, y = 3155, z = 0 },
    DRAYNOR_MANOR = { x = 3107, y = 3358, z = 0 },
    GE = { x = 3163, y = 3466, z = 0 },
    VARROCK_CASTLE = { x = 3211, y = 3476, z = 0 },
    GUILD = { x = 4761, y = 5775, z = 0 },
    TRAPDOOR = { x = 3222, y = 3268, z = 0 }
}

local LOCATIONS = {
    BOBS_AXES = 1,
    RODDECKS_HOUSE = 2,
    WIZARDS_TOWER = 3,
    EDGEVILLE = 4,
    DRAYNOR_MANOR = 5,
    VARROCK = 6,
    GUILD = 7
}

local LODESTONES = {
    EDGEVILLE = 16,
    LUMBRIDGE = 18,
    DRAYNOR = 15,
    VARROCK = 22
}

local location = LOCATIONS.BOBS_AXES
local oldLocation = nil
local lastTile = nil
local walking = true
local skill = "THIEVING"
local startXp = API.GetSkillXP(skill)
local startTime, afk = os.time(), os.time()

local function round(val, decimal)
    if decimal then
        return math.floor((val * 10 ^ decimal) + 0.5) / (10 ^ decimal)
    else
        return math.floor(val + 0.5)
    end
end

local function formatNumber(num)
    if num >= 1e6 then
        return string.format("%.1fM", num / 1e6)
    elseif num >= 1e3 then
        return string.format("%.1fK", num / 1e3)
    else
        return tostring(num)
    end
end

local function formatElapsedTime(startTime)
    local currentTime = os.time()
    local elapsedTime = currentTime - startTime
    local hours = math.floor(elapsedTime / 3600)
    local minutes = math.floor((elapsedTime % 3600) / 60)
    local seconds = elapsedTime % 60
    return string.format("[%02d:%02d:%02d]", hours, minutes, seconds)
end

local function calcProgressPercentage(skill, currentExp)
    local currentLevel = API.XPLevelTable(API.GetSkillXP(skill))
    if currentLevel == 120 then return 100 end
    local nextLevelExp = XPForLevel(currentLevel + 1)
    local currentLevelExp = XPForLevel(currentLevel)
    local progressPercentage = (currentExp - currentLevelExp) / (nextLevelExp - currentLevelExp) * 100
    return math.floor(progressPercentage)
end

local function printProgressReport(final)
    local currentXp = API.GetSkillXP(skill)
    local elapsedMinutes = (os.time() - startTime) / 60
    local diffXp = math.abs(currentXp - startXp);
    local xpPH = round((diffXp * 60) / elapsedMinutes);
    local time = formatElapsedTime(startTime)
    local currentLevel = API.XPLevelTable(API.GetSkillXP(skill))
    IGP.radius = calcProgressPercentage(skill, API.GetSkillXP(skill)) / 100
    IGP.string_value = time ..
        " | " ..
        string.lower(skill):gsub("^%l", string.upper) ..
        ": " .. currentLevel .. " | XP/H: " .. formatNumber(xpPH) .. " | XP: " .. formatNumber(diffXp)
end

local function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random((MAX_IDLE_TIME_MINUTES * 60) * 0.6, (MAX_IDLE_TIME_MINUTES * 60) * 0.9)

    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
    end
end

local function setupGUI()
    IGP = API.CreateIG_answer()
    IGP.box_start = FFPOINT.new(5, 5, 0)
    IGP.box_name = "PROGRESSBAR"
    IGP.colour = ImColor.new(75, 0, 130)
    IGP.string_value = "SAFECRACKING"
end

local function drawGUI()
    DrawProgressBar(IGP)
end

local function invContains(items)
    local loot = API.InvItemcount_2(items)
    for _, v in ipairs(loot) do
        if v > 0 then
            return true
        end
    end
    return false
end

local function hasLoot()
    return invContains(ID.LOOT)
end

local function hasLootBag()
    return invContains(ID.BAG)
end

local function isAtLocation(location, distance)
    local distance = distance or 20
    return API.PInArea(location.x, distance, location.y, distance, location.z)
end

local function isLodestoneInterfaceUp()
    return #API.ScanForInterfaceTest2Get(true,
        { { 1092, 1, -1, -1, 0 }, { 1092, 54, -1, 1, 0 } }) > 0
end

local function teleportToLodestone(id)
    if isLodestoneInterfaceUp() then
        API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1092, id, -1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(1600, 800, 800)
    else
        API.DoAction_Interface(0xffffffff, 0xffffffff, 1, 1465, 18, -1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(300, 600, 600)
    end
end

local function teleportToEdgeville()
    if invContains(ID.WILDY_SWORD) then
        if API.Compare2874Status(13) or API.Compare2874Status(22) then
            API.KeyboardPress2(0x31, 60, 100)
            API.RandomSleep2(200, 200, 200)
        else
            API.DoAction_Inventory2(ID.WILDY_SWORD, 0, 2, API.OFF_ACT_GeneralInterface_route)
        end
    else
        teleportToLodestone(LODESTONES.EDGEVILLE)
    end
end

local function teleportToVarrock()
    local lotd = API.GetABs_name1("Luck of the Dwarves")
    local rof = API.GetABs_name1("Ring of Fortune")
    local vt = API.GetABs_name1("Varrock Teleport")
    if lotd.enabled and lotd.action == "Miscellania" then
        API.DoAction_Ability_Direct(lotd, 2, API.OFF_ACT_GeneralInterface_route)
    elseif rof.enabled and rof.action == "Miscellania" then
        API.DoAction_Ability_Direct(rof, 2, API.OFF_ACT_GeneralInterface_route)
    elseif vt.enabled then
        API.DoAction_Ability_Direct(vt, 1, API.OFF_ACT_GeneralInterface_route)
    else
        teleportToLodestone(LODESTONES.VARROCK)
    end
end

local function walkToTile(tile)
    API.DoAction_Tile(tile)
    lastTile = tile
    API.RandomSleep2(600, 300, 300)
end

local function findDoor(doorId, tile, floor)
    local allObj = API.ReadAllObjectsArray(true, -1)
    for _, v in pairs(allObj) do
        if v.Id > 0 and v.Id == doorId and v.CalcX == tile[1] and v.CalcY == tile[2] and v.Floor == floor then
            return v
        end
    end
    return false
end

local function getSafe()
    local safes = API.GetAllObjArray1({ ID.SAFE }, 25, 0)
    if #safes > 0 then
        local floor = API.GetFloorLv_2()
        for _, v in ipairs(safes) do
            if v.Floor == floor and v.Action == "Crack open" then
                return v
            end
        end
    end
    return false
end

local function isCracking()
    return API.ReadPlayerAnim() == ID.CRACKING_ANIMATION
end

local function hasPulse()
    return #API.GetAllObjArray1({ ID.PULSE }, 10, 4) > 0
end

local function clickSafe(safe)
    API.DoAction_Object_Direct(0x29, 0, safe)
    API.RandomSleep2(600, 600, 600)
end

local function crackSafe()
    if walking then return false end
    local safe = getSafe()
    if safe then
        if isCracking() then
            if hasPulse() then
                API.RandomSleep2(300, 600, 600)
                clickSafe(safe)
            end
        else
            clickSafe(safe)
            API.RandomSleep2(1200, 600, 600)
        end
    else
        return false
    end
    return true
end

local function walk()
    walking = true
    local floor = API.GetFloorLv_2()
    if location == LOCATIONS.BOBS_AXES then
        if isAtLocation(AREA.LUMBRIDGE_LODESTONE, 5) then
            local tile = WPOINT.new(3236 + math.random(-2, 2), 3204 + math.random(-2, 2), 0)
            walkToTile(tile)
            API.RandomSleep2(1200, 600, 600)
        elseif isAtLocation(AREA.BOBS_AXES, 25) then
            if findDoor(45476, { 3234, 3203 }, 0) then
                if API.DoAction_Object2(0x31, API.OFF_ACT_GeneralObject_route0, { 45476 }, 50, WPOINT.new(3234, 3203, 0)) then
                    API.RandomSleep2(1200, 600, 600)
                end
            else
                if floor == 0 then
                    API.DoAction_Object2(0x34, 0, { 45483 }, 50, WPOINT.new(3230, 3205, 0))
                    API.RandomSleep2(800, 600, 600)
                elseif floor == 1 then
                    walking = false
                end
            end
        else
            teleportToLodestone(LODESTONES.LUMBRIDGE)
            API.RandomSleep2(1600, 600, 600)
        end
    elseif location == LOCATIONS.RODDECKS_HOUSE then
        if isAtLocation(AREA.BOBS_AXES, 15) then
            if floor == 1 then
                API.DoAction_Object2(0x35, 0, { 45484 }, 50, WPOINT.new(3230, 3205, 0))
                API.RandomSleep2(800, 600, 600)
            else
                if findDoor(45476, { 3234, 3203 }, 0) then
                    if API.DoAction_Object2(0x31, API.OFF_ACT_GeneralObject_route0, { 45476 }, 50, WPOINT.new(3234, 3203, 0)) then
                        API.RandomSleep2(600, 600, 600)
                    end
                end
                local tile = WPOINT.new(3231 + math.random(-2, 2), 3231 + math.random(-2, 2), 0)
                walkToTile(tile)
                API.RandomSleep2(1200, 600, 600)
            end
        elseif isAtLocation(AREA.RODDECKS_HOUSE, 20) then
            if not findDoor(45477, { 3230, 3236 }, 0) then
                if API.DoAction_Object2(0x31, API.OFF_ACT_GeneralObject_route0, { 45476 }, 50, WPOINT.new(3230, 3235, 0)) then
                    API.RandomSleep2(1200, 600, 600)
                end
            else
                if floor == 0 then
                    API.DoAction_Object2(0x34, API.OFF_ACT_GeneralObject_route0, { 45483 }, 50, WPOINT.new(3232, 3239, 0))
                    API.RandomSleep2(800, 600, 600)
                else
                    if not findDoor(45477, { 3230, 3239 }, 1) then
                        if API.DoAction_Object2(0x31, API.OFF_ACT_GeneralObject_route0, { 45476 }, 50, WPOINT.new(3230, 3238, 0)) then
                            API.RandomSleep2(1200, 600, 600)
                        end
                    else
                        walking = false
                    end
                end
            end
        else
            teleportToLodestone(LODESTONES.LUMBRIDGE)
        end
    elseif location == LOCATIONS.WIZARDS_TOWER then
        if isAtLocation(AREA.WIZARDS_TOWER, 20) then
            if floor == 3 then
                API.DoAction_Object1(0x29, API.OFF_ACT_GeneralObject_route0, { 79776 }, 50) -- descend
                API.RandomSleep2(2300, 600, 600)
            elseif floor == 2 then
                walking = false
            end
        else
            API.DoAction_Inventory1(ID.WICKED_HOOD, 0, 3, API.OFF_ACT_GeneralInterface_route)
            API.RandomSleep2(3200, 600, 600)
        end
    elseif location == LOCATIONS.EDGEVILLE then
        if isAtLocation(AREA.EDGEVILLE_LODESTONE, 20) then
            if floor == 0 then
                API.DoAction_Object2(0x34, API.OFF_ACT_GeneralObject_route0, { 26982 }, 50, WPOINT.new(3082, 3513, 0))
                API.RandomSleep2(1800, 600, 600)
            else
                API.RandomSleep2(300, 300, 300)
                walking = false
            end
        else
            teleportToEdgeville()
        end
    elseif location == LOCATIONS.DRAYNOR_MANOR then
        if isAtLocation(AREA.DRAYNOR_MANOR, 50) then
            if p.y < 3354 then
                local doorId = (math.random() < 0.5) and 47421 or 47424
                local doorX = (doorId == 47421) and 3108 or 3109
                if API.DoAction_Object2(0x31, API.OFF_ACT_GeneralObject_route0, { doorId }, 50, WPOINT.new(doorX, 3353, 0)) then
                    API.RandomSleep2(600, 600, 600)
                end
            else
                if not findDoor(47513, { 3104, 3360 }, 0) then
                    if API.DoAction_Object2(0x31, API.OFF_ACT_GeneralObject_route0, { 47512 }, 50, WPOINT.new(3105, 3360, 0)) then
                        API.RandomSleep2(600, 600, 600)
                    end
                else
                    walking = false
                end
            end
        elseif isAtLocation(AREA.DRAYNOR_LODESTONE, 10) then
            local tile = WPOINT.new(3108 + math.random(-2, 2), 3345 + math.random(-2, 2), 0)
            walkToTile(tile)
        else
            teleportToLodestone(LODESTONES.DRAYNOR)
        end
    elseif location == LOCATIONS.VARROCK then
        if API.PInArea21(3200, 3206, 3469, 3475) then
            walking = false
        elseif isAtLocation(AREA.GE, 10) or isAtLocation(AREA.VARROCK_LODESTONE, 10) then
            API.DoAction_WalkerW(WPOINT.new(3213, 3470, 0))
            API.RandomSleep2(300, 300, 300)
        elseif isAtLocation(AREA.VARROCK_CASTLE, 25) then
            if floor == 0 then
                if API.DoAction_Object2(0x34, API.OFF_ACT_GeneralObject_route0, { 24367 }, 50, WPOINT.new(3212, 3474, 0)) then
                    API.RandomSleep2(1200, 600, 600)
                end
            elseif floor == 1 then
                if not findDoor(15535, { 3218, 3472 }, 1) then
                    door = findDoor(15536, { 3219, 3472 }, 1)
                    API.DoAction_Object_Direct(0x31, 0, door)
                    API.RandomSleep2(800, 600, 600)
                else
                    API.DoAction_Object2(0x34, API.OFF_ACT_GeneralObject_route0, { 24361 }, 50, WPOINT.new(3224, 3472, 0))
                    API.RandomSleep2(1800, 600, 600)
                end
            elseif floor == 2 then
                if not findDoor(15535, { 3219, 3472 }, 2) then
                    API.DoAction_Object2(0x31, API.OFF_ACT_GeneralObject_route0, { 15536 }, 50, WPOINT.new(3218, 3472, 0))
                else
                    if API.PInArea21(3200, 3206, 3469, 3475) then
                        walking = false
                    else
                        API.DoAction_Object2(0xc3, 0, { 111230 }, 50, WPOINT.new(3203, 3476, 0))
                        API.RandomSleep2(800, 800, 800)
                    end
                end
            end
        else
            teleportToVarrock()
            API.RandomSleep2(400, 600, 600)
        end
    elseif location == LOCATIONS.GUILD then
        if isAtLocation(AREA.GUILD, 50) then
            if hasLoot() then
                if API.Select_Option(rewardChoice) then
                    API.RandomSleep2(400, 400, 400)
                else
                    API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route2, { ID.DARREN }, 50) -- Darren
                    API.RandomSleep2(400, 300, 300)
                end
            else
                API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route2, { ID.ROBIN }, 50)
                API.RandomSleep2(600, 300, 300)
                walking = false
            end
        elseif isAtLocation(AREA.LUMBRIDGE_LODESTONE, 10) then
            local tile = WPOINT.new(3217 + math.random(-2, 2), 3264 + math.random(-2, 2), 0)
            walkToTile(tile)
            API.RandomSleep2(600, 300, 300)
        elseif isAtLocation(AREA.TRAPDOOR, 10) then
            API.DoAction_Object2(0x39, 0, { ID.TRAPDOOR }, 50, WPOINT.new(3223, 3268, 0))
            API.RandomSleep2(3200, 1000, 1000)
        else
            if API.DoAction_Inventory1(ID.GUILD_TELEPORT, 0, 1, API.OFF_ACT_GeneralInterface_route) then
                API.RandomSleep2(800, 600, 600)
            else
                teleportToLodestone(LODESTONES.LUMBRIDGE)
            end
        end
    end
end

local function invCheck()
    return API.InvItemcount_1(ID.LOCKPICK) > 0
        and API.InvItemcount_1(ID.STETHOSCOPE) > 0
        and API.InvItemcount_1(ID.WICKED_HOOD) > 0
        and hasLootBag()
end

setupGUI()

while API.Read_LoopyLoop() do
    if not invCheck() then
        print("Inventory check failed - ensure you have loot bag, lockpicks, sethoscope and wicked hood")
        API.Write_LoopyLoop(false)
        break
    end
    idleCheck()
    API.DoRandomEvents()
    drawGUI()
    p = API.PlayerCoordfloat()

    if walking then
        if API.CheckAnim(10) then
            goto continue
        end
    end

    if API.ReadPlayerMovin2() then
        if lastTile then
            local dist = math.sqrt((lastTile.x - p.x) ^ 2 + (lastTile.y - p.y) ^ 2)
            if dist > 8 then
                goto continue
            else
                lastTile = nil
            end
        else
            goto continue
        end
    end

    if walking then
        walk()
    else
        if not crackSafe() then
            if API.ChatFind("Your loot bag is full", 2).pos_found > 0 and location ~= LOCATIONS.GUILD then
                oldLocation = location
                location = LOCATIONS.GUILD
                walking = true
            else
                if location == LOCATIONS.GUILD then
                    location = oldLocation + 1
                else
                    location = location + 1
                end
                if location > 6 then location = 1 end
                walking = true
            end
            API.RandomSleep2(300, 300, 300)
        end
    end

    ::continue::
    printProgressReport()
    API.RandomSleep2(250, 200, 200)
end