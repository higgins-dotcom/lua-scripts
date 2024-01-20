--[[
    Script: SafeCracker
    Description: Safe cracking

    Author: Higgins
    Version: 2.1
    Release Date: 18/01/2024

    Release Notes:
    - Version 2.1 : Wizard Tower added to end of Kandarin route & Other fixes
    - Version 2.0 : Kandarin route added
    - Version 1.1 : Varrock Tele and Wildy Sword tele to Edgeville added
    - Version 1.0 : Initial release
]]

-- [[ !! NO SETTINGS HERE - USE THE GUI !! ]] --

-- Kandarin route (Camelot Castle, Ardougne Market, Yanille)
-- You will need
--    Loot bag
--    Camelot & Ardougne Teleport on action bar

-- Misthalin route (Bobs Axes, Roddecks House, Wizard's Tower, Edgeville, Draynor Manor, Varrock
-- You will need:
--    Loot bag
--    Stethoscope
--    Wicked Hood (In Inventory)
--    Lockpicks
--    Lodestones unlocked (Lumbridge, Draynor, Edgeville and Varrock)
--    If you have Ring of Fortune or Luck of the Dwarves then place it onto the Action Bar (else it will use Varrock lodestone)

local API            = require('API')

local ID             = {
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

local AREA           = {
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
    VARROCK_SQUARE = { x = 3212, y = 3428, z = 0 },
    GUILD = { x = 4761, y = 5775, z = 0 },
    TRAPDOOR = { x = 3222, y = 3268, z = 0 },
    CAMELOT = { x = 2757, y = 3477, z = 0 },
    ARDOUGNE = { x = 2663, y = 3302, z = 0 },
    YANILLE = { x = 2529, y = 3094, z = 0 },
    YANILLE_PUB = { x = 2553, y = 3080, z = 0 }
}

local SAFES          = {
    ROUTES = {
        KANDARIN = {
            CAMELOT = { 7887, { 12, 18 } }
        }
    }
}

local ROUTES         = {
    ASGARNIA = {
        BOBS_AXES = 1,
        RODDECKS_HOUSE = 2,
        WIZARDS_TOWER = 3,
        EDGEVILLE = 4,
        DRAYNOR_MANOR = 5,
        VARROCK = 6,
        GUILD = 7
    },
    KANDARIN = {
        CAMELOT = 1,
        ARDOUGNE_WEST = 2,
        ARDOUGNE_NORTH = 3,
        YANILLE = 4,
        YANILLE_PUB = 5,
        WIZARDS_TOWER = 6,
        GUILD = 7
    },
}

local LODESTONES     = {
    EDGEVILLE = 16,
    LUMBRIDGE = 18,
    DRAYNOR = 15,
    VARROCK = 22,
    YANILLE = 26
}

local route          = nil
LOCATIONS            = nil
local location       = 1
local oldLocation    = nil
local lastTile       = nil
local scriptPaused   = true
local walking        = true
local skill          = "THIEVING"
local startXp        = API.GetSkillXP(skill)
local startTime, afk = os.time(), os.time()
local rewardChoice
local needLockpick
local needStethoscope
local errors         = {}
local version        = "2.0"

local function tableLength(tbl)
    local count = 0
    for _ in pairs(tbl) do
        count = count + 1
    end
    return count
end

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

    btnStop = API.CreateIG_answer()
    btnStop.box_start = FFPOINT.new(200, 125, 0)
    btnStop.box_name = " STOP "
    btnStop.box_size = FFPOINT.new(90, 50, 0)
    btnStop.colour = ImColor.new(255, 255, 255)
    btnStop.string_value = "STOP"

    btnStart = API.CreateIG_answer()
    btnStart.box_start = FFPOINT.new(90, 125, 0)
    btnStart.box_name = " START "
    btnStart.box_size = FFPOINT.new(90, 50, 0)
    btnStart.colour = ImColor.new(0, 0, 255)
    btnStart.string_value = "START"
    btnStart.radius = 1.0

    IG_Text = API.CreateIG_answer()
    IG_Text.box_name = "TEXT"
    IG_Text.box_start = FFPOINT.new(50, 15, 0)
    IG_Text.colour = ImColor.new(255, 255, 255);
    IG_Text.string_value = "Welcome to SafeCracker (v" .. version .. ") by Higgins"

    IG_Back = API.CreateIG_answer()
    IG_Back.box_name = "back";
    IG_Back.box_start = FFPOINT.new(0, 0, 0)
    IG_Back.box_size = FFPOINT.new(370, 175, 0)
    IG_Back.colour = ImColor.new(15, 13, 18, 255)
    IG_Back.string_value = ""

    tickJagexAcc = API.CreateIG_answer();
    tickJagexAcc.box_name = "Jagex Account"
    tickJagexAcc.box_start = FFPOINT.new(50, 60, 0);
    tickJagexAcc.colour = ImColor.new(0, 255, 0);
    tickJagexAcc.tooltip_text = "Sets idle timeout to 15 minutes for Jagex accounts"

    tickLockpick = API.CreateIG_answer();
    tickLockpick.box_name = "Master Lockpick"
    tickLockpick.box_start = FFPOINT.new(50, 80, 0);
    tickLockpick.colour = ImColor.new(0, 255, 0);
    tickLockpick.tooltip_text = "Unbreakable lockpick already added to your toolbet"

    tickStethoscope = API.CreateIG_answer();
    tickStethoscope.box_name = "Master Stethoscope"
    tickStethoscope.box_start = FFPOINT.new(50, 100, 0);
    tickStethoscope.colour = ImColor.new(0, 255, 0);
    tickStethoscope.tooltip_text = "Master Stethoscope already added to your toolbet"

    comboRoute = API.CreateIG_answer()
    comboRoute.box_name = "###ROUTE"
    comboRoute.box_start = FFPOINT.new(50, 30, 0)
    comboRoute.box_size = FFPOINT.new(190, 0, 0)
    comboRoute.stringsArr = { "Misthalin", "Kandarin" }
    comboRoute.tooltip_text =
    "Misthalin (62+) - Lumbridge, Wizard Tower, Edgeville, Varrock, Draynor Manor\nKandarin (83+) - Camelot, Ardougne, Yanille, Wizard Tower"

    comboReward = API.CreateIG_answer()
    comboReward.box_name = "###REWARD"
    comboReward.box_start = FFPOINT.new(180, 30, 0)
    comboReward.box_size = FFPOINT.new(190, 0, 0)
    comboReward.stringsArr = { "Pilfer Points", "Coins" }
    comboReward.tooltip_text = "Choice of reward when handing in items"

    API.DrawSquareFilled(IG_Back)
    API.DrawTextAt(IG_Text)
    API.DrawBox(btnStart)
    API.DrawBox(btnStop)
    API.DrawCheckbox(tickStethoscope)
    API.DrawCheckbox(tickJagexAcc)
    API.DrawCheckbox(tickLockpick)
    API.DrawComboBox(comboRoute)
    API.DrawComboBox(comboReward)
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

local function isCamelotCracked()
    local SAFE_DATA = SAFES.ROUTES.KANDARIN.CAMELOT
    local state = API.VB_FindPSett(SAFE_DATA[1]).state
    local isCracked = (state & (1 << SAFE_DATA[2][1])) == (1 << SAFE_DATA[2][1]) and
        (state & (1 << SAFE_DATA[2][2])) == (1 << SAFE_DATA[2][2])
    if isCracked then return true end
    return false
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
        API.RandomSleep2(300, 300, 300)
    end
end

local function teleportToDestination(destination)
    local teleportAbility = API.GetABs_name1(destination .. " Teleport")
    if teleportAbility.enabled then
        API.DoAction_Ability_Direct(teleportAbility, 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(1200, 300, 300)
    end
end

local function teleportToEdgeville()
    local ws = API.GetABs_name1("Wilderness sword")
    if ws.enabled and ws.action == "Edgeville" then
        API.DoAction_Ability_Direct(ws, 1, API.OFF_ACT_GeneralInterface_route)
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
    local distance = 25
    if route == "KANDARIN" and
        (location == LOCATIONS.ARDOUGNE_WEST
            or LOCATIONS.ARDOUGNE_NORTH
            or LOCATIONS.YANILLE) then
        distance = 18
    end
    local safes = API.GetAllObjArray1({ ID.SAFE }, distance, 0)
    if #safes > 0 then
        local floor = API.GetFloorLv_2()
        for _, v in ipairs(safes) do
            if v.Bool1 and v.Floor == floor and v.Action == "Crack open" then
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
    API.RandomSleep2(600, 400, 400)
end

local function crackSafe()
    if walking then return false end
    local safe = getSafe()
    if safe then
        if isCracking() then
            if hasPulse() then
                API.RandomSleep2(250, 200, 300)
                clickSafe(safe)
            end
        else
            clickSafe(safe)
            API.RandomSleep2(600, 600, 600)
        end
    else
        return false
    end
    return true
end

local function walk()
    walking = true
    local floor = API.GetFloorLv_2()

    -- or (API.InvFull_() and hasLoot())

    if (API.InvFull_() and hasLoot()) or (API.ChatFind("Your loot bag is full", 2).pos_found > 0 and location ~= LOCATIONS.GUILD) then
        oldLocation = location
        location = tableLength(LOCATIONS)
    end

    if location == LOCATIONS.GUILD then
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
                if oldLocation ~= nil then
                    location = oldLocation - 1
                    oldLocation = nil
                end
                walking = false
            end
        elseif isAtLocation(AREA.TRAPDOOR, 15) then
            API.DoAction_Object2(0x39, 0, { ID.TRAPDOOR }, 50, WPOINT.new(3223, 3268, 0))
            API.RandomSleep2(3200, 1000, 1000)
        elseif isAtLocation(AREA.LUMBRIDGE_LODESTONE, 10) then
            local tile = WPOINT.new(3217 + math.random(-2, 2), 3264 + math.random(-2, 2), 0)
            walkToTile(tile)
            API.RandomSleep2(600, 300, 300)
        else
            if API.DoAction_Inventory1(ID.GUILD_TELEPORT, 0, 1, API.OFF_ACT_GeneralInterface_route) then
                API.RandomSleep2(800, 600, 600)
            else
                teleportToLodestone(LODESTONES.LUMBRIDGE)
            end
        end
    end

    if route == "ASGARNIA" then
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
                        API.DoAction_Object2(0x34, API.OFF_ACT_GeneralObject_route0, { 45483 }, 50,
                            WPOINT.new(3232, 3239, 0))
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
            if isAtLocation(AREA.EDGEVILLE_LODESTONE, 50) then
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
            elseif isAtLocation(AREA.GE, 10) or isAtLocation(AREA.VARROCK_LODESTONE, 10) or isAtLocation(AREA.VARROCK_SQUARE, 15) then
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
                        API.DoAction_Object2(0x34, API.OFF_ACT_GeneralObject_route0, { 24361 }, 50,
                            WPOINT.new(3224, 3472, 0))
                        API.RandomSleep2(1800, 600, 600)
                    end
                elseif floor == 2 then
                    if not findDoor(15535, { 3219, 3472 }, 2) then
                        API.DoAction_Object2(0x31, API.OFF_ACT_GeneralObject_route0, { 15536 }, 50,
                            WPOINT.new(3218, 3472, 0))
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
        end
    elseif route == "KANDARIN" then
        if location == LOCATIONS.CAMELOT then
            if not isCamelotCracked() then
                if isAtLocation(AREA.CAMELOT, 50) then
                    if API.PInArea(2750, 3, 3500, 3, 0) then
                        walking = false
                    elseif p.y < 3483 then
                        local doorId = (math.random() < 0.5) and 26081 or 26082
                        local doorX = (doorId == 47421) and 2757 or 2758
                        if API.DoAction_Object2(0x31, API.OFF_ACT_GeneralObject_route0, { doorId }, 50, WPOINT.new(doorX, 3482, 0)) then
                            API.RandomSleep2(600, 600, 600)
                        end
                    else
                        if not findDoor(25641, { 2758, 3504 }, 0) then
                            local doorId = (math.random() < 0.5) and 25638 or 25640
                            local doorX = (doorId == 47421) and 2757 or 2758
                            if API.DoAction_Object2(0x31, API.OFF_ACT_GeneralObject_route0, { doorId }, 50, WPOINT.new(doorX, 3503, 0)) then
                                API.RandomSleep2(600, 600, 600)
                            end
                        elseif not findDoor(25643, { 2750, 3504 }, 0) then
                            if API.DoAction_Object2(0x31, API.OFF_ACT_GeneralObject_route0, { 25642 }, 50, WPOINT.new(2750, 3503, 0)) then
                                API.RandomSleep2(600, 600, 600)
                            end
                        else
                            if not API.PInArea(2750, 15, 3500, 15, 0) then
                                local tile = WPOINT.new(2750 + math.random(-2, 2), 3502 + math.random(-2, 2), 0)
                                walkToTile(tile)
                            else
                                walking = false
                            end
                        end
                    end
                else
                    teleportToDestination("Camelot")
                end
            else
                print("Camelot safes are already cracked.. waiting for them to be available.")
                API.RandomSleep2(1000, 1000, 1000)
            end
        elseif location == LOCATIONS.ARDOUGNE_WEST then
            if isAtLocation(AREA.ARDOUGNE, 50) then
                if floor == 0 then
                    if not findDoor(34808, { 2651, 3302 }, floor) then
                        if API.DoAction_Object2(0x31, API.OFF_ACT_GeneralObject_route0, { 34807 }, 15, WPOINT.new(2652, 3302, 0)) then
                            API.RandomSleep2(300, 600, 600)
                        end
                    else
                        if API.DoAction_Object2(0x34, 0, { 34498 }, 50, WPOINT.new(2649, 3297, 0)) then
                            API.RandomSleep2(3800, 600, 600)
                        end
                    end
                elseif floor == 1 then
                    if not findDoor(34813, { 2649, 3300 }, floor) then
                        if API.DoAction_Object2(0x31, API.OFF_ACT_GeneralObject_route0, { 34811 }, 8, WPOINT.new(2648, 3300, 0)) then
                            API.RandomSleep2(300, 600, 600)
                        end
                    else
                        walking = false
                    end
                end
            else
                teleportToDestination("Ardougne")
            end
        elseif location == LOCATIONS.ARDOUGNE_NORTH then
            if API.PInArea(2650, 2, 3301, 2, 0) and floor == 1 then
                teleportToDestination("Ardougne")
            elseif isAtLocation(AREA.ARDOUGNE, 50) then
                if floor == 0 then
                    if not findDoor(34808, { 2659, 3320 }, floor) then
                        if API.DoAction_Object2(0x31, API.OFF_ACT_GeneralObject_route0, { 34807 }, 50, WPOINT.new(2659, 3319, 0)) then
                            API.RandomSleep2(600, 600, 600)
                        end
                    else
                        if API.DoAction_Object2(0x34, 0, { 34498 }, 50, WPOINT.new(2663, 3321, 0)) then
                            API.RandomSleep2(3600, 600, 600)
                        end
                    end
                elseif floor == 1 then
                    if not findDoor(34813, { 2660, 3320 }, floor) then
                        if API.DoAction_Object2(0x31, API.OFF_ACT_GeneralObject_route0, { 34811 }, 15, WPOINT.new(2661, 3320, 0)) then
                            API.RandomSleep2(600, 600, 600)
                        end
                    else
                        walking = false
                    end
                end
            else
                teleportToDestination("Ardougne")
            end
        elseif location == LOCATIONS.YANILLE then
            if isAtLocation(AREA.YANILLE, 15) then
                if not findDoor(17090, { 2537, 3090 }, floor) then
                    if API.DoAction_Object2(0x31, API.OFF_ACT_GeneralObject_route0, { 17089 }, 50, WPOINT.new(2537, 3089, 0)) then
                        API.RandomSleep2(600, 600, 600)
                    end
                else
                    walking = false
                end
            else
                teleportToLodestone(LODESTONES.YANILLE)
            end
        elseif location == LOCATIONS.YANILLE_PUB then
            if isAtLocation(AREA.YANILLE, 50) then
                if floor == 0 then
                    if API.PInArea(2534, 5, 3084, 5) then
                        if not findDoor(17090, { 2537, 3090 }, floor) then
                            if API.DoAction_Object2(0x31, API.OFF_ACT_GeneralObject_route0, { 17089 }, 50, WPOINT.new(2537, 3089, 0)) then
                                API.RandomSleep2(600, 600, 600)
                            end
                        else
                            local tile = WPOINT.new(2549 + math.random(-2, 2), 3085 + math.random(-2, 2), 0)
                            walkToTile(tile)
                        end
                    else
                        if not findDoor(1534, { 2551, 3083 }, floor) then
                            if API.DoAction_Object2(0x31, API.OFF_ACT_GeneralObject_route0, { 1533 }, 50, WPOINT.new(2551, 3082, 0)) then
                                API.RandomSleep2(600, 600, 600)
                            end
                        else
                            API.DoAction_Object2(0x34, 0, { 117943 }, 50, WPOINT.new(2556, 3081, 0))
                            API.RandomSleep2(2800, 400, 400)
                        end
                    end
                else
                    walking = false
                end
            else
                teleportToLodestone(LODESTONES.YANILLE)
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
        end
        -- elseif location == LOCATIONS.VARROCK then
        --     if not isCamelotCracked() then
        --         walking = false
        --     else
        --         if API.PInArea21(3200, 3206, 3469, 3475) then
        --             walking = false
        --         elseif isAtLocation(AREA.GE, 10) or isAtLocation(AREA.VARROCK_LODESTONE, 10) or isAtLocation(AREA.VARROCK_SQUARE, 15) then
        --             API.DoAction_WalkerW(WPOINT.new(3213, 3470, 0))
        --             API.RandomSleep2(300, 300, 300)
        --         elseif isAtLocation(AREA.VARROCK_CASTLE, 25) then
        --             if floor == 0 then
        --                 if API.DoAction_Object2(0x34, API.OFF_ACT_GeneralObject_route0, { 24367 }, 50, WPOINT.new(3212, 3474, 0)) then
        --                     API.RandomSleep2(1200, 600, 600)
        --                 end
        --             elseif floor == 1 then
        --                 if not findDoor(15535, { 3218, 3472 }, 1) then
        --                     door = findDoor(15536, { 3219, 3472 }, 1)
        --                     API.DoAction_Object_Direct(0x31, 0, door)
        --                     API.RandomSleep2(800, 600, 600)
        --                 else
        --                     API.DoAction_Object2(0x34, API.OFF_ACT_GeneralObject_route0, { 24361 }, 50,
        --                         WPOINT.new(3224, 3472, 0))
        --                     API.RandomSleep2(1800, 600, 600)
        --                 end
        --             elseif floor == 2 then
        --                 if not findDoor(15535, { 3219, 3472 }, 2) then
        --                     API.DoAction_Object2(0x31, API.OFF_ACT_GeneralObject_route0, { 15536 }, 50,
        --                         WPOINT.new(3218, 3472, 0))
        --                 else
        --                     if API.PInArea21(3200, 3206, 3469, 3475) then
        --                         walking = false
        --                     else
        --                         API.DoAction_Object2(0xc3, 0, { 111230 }, 50, WPOINT.new(3203, 3476, 0))
        --                         API.RandomSleep2(800, 800, 800)
        --                     end
        --                 end
        --             end
        --         else
        --             teleportToVarrock()
        --             API.RandomSleep2(400, 600, 600)
        --         end
        --     end
        -- end
    end
end

local function check(condition, errorMessage)
    local result = condition
    if type(condition) == "function" then
        result = condition()
    end
    if not result then
        table.insert(errors, errorMessage)
    end
end

local function invCheck()
    local lockpickCheck = not needLockpick or (needLockpick and API.InvItemcount_1(ID.LOCKPICK) > 0)
    local stethoscopeCheck = not needStethoscope or (needStethoscope and API.InvItemcount_1(ID.STETHOSCOPE) > 0)
    local wickedHoodCheck = API.InvItemcount_1(ID.WICKED_HOOD) > 0

    check(wickedHoodCheck, "You need a Wicked Hood in your inventory!")
    check(lockpickCheck, "You need lockpicks in your inventory!")
    check(stethoscopeCheck, "You need a Stethoscope in your inventory!")
    check(hasLootBag(), "You need a loot bag in your inventory!")

    local ct = API.GetABs_name1("Camelot Teleport")
    local ctCheck = ct.enabled
    local at = API.GetABs_name1("Ardougne Teleport")
    local atCheck = at.enabled

    check(ctCheck, "You need to have Camelot Teleport on your action bar")
    check(atCheck, "You need to have Ardougne Teleport on your action bar")

    return lockpickCheck and stethoscopeCheck and wickedHoodCheck and hasLootBag()
end

setupGUI()

while API.Read_LoopyLoop() do
    if scriptPaused then
        if btnStop.return_click then
            API.Write_LoopyLoop(false)
        end

        if btnStart.return_click then
            IG_Back.remove = true
            btnStart.remove = true
            IG_Text.remove = true
            btnStop.remove = true
            tickJagexAcc.remove = true
            tickStethoscope.remove = true
            tickLockpick.remove = true
            comboRoute.remove = true
            comboReward.remove = true

            rewardChoice = (comboReward.int_value == 1) and "Coins" or "Pilfer Points"
            needLockpick = not tickLockpick.box_ticked
            needStethoscope = not tickStethoscope.box_ticked
            route = (comboRoute.int_value == 1) and "KANDARIN" or "ASGARNIA"
            MAX_IDLE_TIME_MINUTES = (tickJagexAcc.box_ticked == 1) and 5 or 15
            LOCATIONS = ROUTES[route]
            scriptPaused = false
        end
        goto continue
    end

    if not invCheck() then
        print("!!! Startup Check Failed !!!")
        if #errors > 0 then
            print("Errors:")
            for _, errorMsg in ipairs(errors) do
                print("- " .. errorMsg)
            end
        end
        API.Write_LoopyLoop(false)
        break
    end

    idleCheck()
    API.DoRandomEvents()
    drawGUI()
    p = API.PlayerCoordfloat()

    if walking then
        if API.CheckAnim(5) then
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
            if API.Compare2874Status(12) then
                API.KeyboardPress2(0x20, 60, 100)
                API.RandomSleep2(100, 200, 200)
            end

            if location == LOCATIONS.GUILD then
                -- location = oldLocation + 1
            else
                location = location + 1
            end
            if location > (tableLength(LOCATIONS) - 1) then
                location = 1
            end
            walking = true

            -- if API.ChatFind("Your loot bag is full", 2).pos_found > 0 and location ~= LOCATIONS.GUILD then
            --     oldLocation = location
            --     location = LOCATIONS.GUILD
            --     walking = true
            -- else
            --     if location == LOCATIONS.GUILD then
            --         location = oldLocation + 1
            --     else
            --         location = location + 1
            --     end
            --     if location > (tableLength(LOCATIONS) - 1) then location = 1 end
            --     walking = true
            -- end
            API.RandomSleep2(300, 300, 300)
        end
    end

    ::continue::
    printProgressReport()
    API.RandomSleep2(100, 100, 100)
end