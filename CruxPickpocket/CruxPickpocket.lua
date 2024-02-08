--[[
    Script: Crux Eqal Knight Pickpocket
    Description: Crux Eqal Knight Pickpocket

    Author: Higgins
    Version: 1.0
    Release Date: 06/02/2024

    Release Notes:
    - Version 1.0 : Initial release
]]

local API = require("api")

local ID = {
    EXCALIBUR = 14632,
    EXCALIBUR_AUGMENTED = 36619,
    ELVEN_SHARD = 43358,
    CRUX_EQAL_KNIGHT = {29639, 29640},
    SAND_SEED = 54004
}

local AREA = {
    KNIGHT = { 3320, 3297 },
    WAR = { 3294, 10127 }
}

local afk, startTime = os.time(), os.time()
local skill = "THIEVING"
local startXp = API.GetSkillXP(skill)
local MAX_IDLE_TIME_MINUTES = 10

local function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random((MAX_IDLE_TIME_MINUTES * 60) * 0.6, (MAX_IDLE_TIME_MINUTES * 60) * 0.9)

    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
    end
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

-- Format script elapsed time to [hh:mm:ss]
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

local function isAtWar()
    return API.PInArea(AREA.WAR[1], 50, AREA.WAR[2], 50, 0)
end

local function isAtKnight()
    return API.PInArea(AREA.KNIGHT[1], 50, AREA.KNIGHT[2], 50, 0)
end

local function hasFam()
    return API.Buffbar_GetIDstatus(26095).id > 0
end

local function prayAtAltar()
    API.DoAction_Object1(0x3d, 0, { 114748 }, 50)
    API.RandomSleep2(1200, 500, 500)
end

local function teleportToWar()
    API.DoAction_Ability("War's Retreat Teleport", 1, API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(400, 500, 500)
end

local function teleportToKnight()
    local ss = API.GetABs_name1("Mystical sand seed")
    if ss.enabled then
        API.DoAction_Ability_Direct(ss, 1, API.OFF_ACT_GeneralInterface_route)
    end
    -- API.DoAction_Inventory1(ID.SAND_SEED, 0, 1, API.OFF_ACT_GeneralInterface_route)
    API.RandomSleep2(800, 500, 500)
end

local function setupGUI()
    IGP = API.CreateIG_answer()
    IGP.box_start = FFPOINT.new(5, 5, 0)
    IGP.box_name = "PROGRESSBAR"
    IGP.colour = ImColor.new(6, 82, 221);
    IGP.string_value = "CRUX EQAL KNIGHTS"
end

local function drawGUI()
    DrawProgressBar(IGP)
end

local function healthCheck()
    local prayer = API.GetPrayPrecent()
    local excalCD = API.DeBuffbar_GetIDstatus(ID.EXCALIBUR, false)
    local excalFound = API.InvItemcount_1(ID.EXCALIBUR_AUGMENTED)
    local elvenCD = API.DeBuffbar_GetIDstatus(ID.ELVEN_SHARD, false)

    local crystalMask = API.Buffbar_GetIDstatus(25938)
    local lightForm = API.Buffbar_GetIDstatus(26048)
    local fiveFingers = API.Buffbar_GetIDstatus(26098)

    local elvenFound = API.InvItemcount_1(ID.ELVEN_SHARD)
    
    if not excalCD.found and excalFound > 0 then
        API.DoAction_Inventory1(ID.EXCALIBUR_AUGMENTED, 0, 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(800, 500, 500)
    end

    if not elvenCD.found and elvenFound > 0 then
        API.DoAction_Inventory1(ID.ELVEN_SHARD, 43358, 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(800, 500, 500)
    end

    if not crystalMask.found then
        API.DoAction_Ability("Crystal Mask", 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(800, 500, 500)
    end

    if prayer > 50 and not lightForm.found then
        API.DoAction_Ability("Light Form", 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(800, 500, 500)
    end

    if not fiveFingers.found then
        API.DoAction_Interface(0xffffffff, 0xffffffff, 5, 1464, 15, 14, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(800, 500, 500)
    end
end

setupGUI()

while API.Read_LoopyLoop() do
    idleCheck()
    drawGUI()
    API.DoRandomEvents()

    if API.ReadPlayerMovin2() then
        API.RandomSleep2(200, 200, 200)
        goto continue
    end

    if API.ReadPlayerAnim() == 424 then
        API.RandomSleep2(5100, 500, 500)
    end

    if isAtKnight() and not hasFam() then
        if API.GetSummoningPoints_() < 100 then
            if isAtWar() then
                prayAtAltar()
            else
                teleportToWar()
            end
        else
            if API.InvItemFound1(52825) then
                API.DoAction_Ability("Holy scarab pouch", 1, API.OFF_ACT_GeneralInterface_route)
                API.RandomSleep2(800, 600, 600)
            end
        end
        goto continue
    end

    if isAtWar() then
        if API.GetSummoningPoints_() > 100 then
            teleportToKnight()
            API.RandomSleep2(500, 500, 500)
        else
            prayAtAltar()
            API.RandomSleep2(500, 500, 500)
        end
        goto continue
    end

    healthCheck()

    if API.CheckAnim(80) or API.ReadPlayerMovin2() then
        API.RandomSleep2(50, 100, 100)
        goto continue
    end

    if API.DoAction_NPC(0x29, API.OFF_ACT_InteractNPC_route2, ID.CRUX_EQAL_KNIGHT, 50) then
        API.RandomSleep2(600, 100, 100)
    end

    ::continue::
    printProgressReport()
    API.RandomSleep2(50, 100, 100)
end