--[[
    Script: UmFisher
    Description: Fishes at Ghostly Sole spot and banks at Um Bank

    Ghostly Sole
    Requirements
    66 Fishing to fish
    66 Cooking to cook
    Each ghostly sole heals up to 1,650 life points when eaten at level 66 Constitution

    Start at Um Bank

    Author: Higgins
    Version: 1.0
    Release Date: 20/01/2024

    Release Notes:
    - Version 1.0 (20/01/2024): Initial release
]]

API = require('api')

-- [[ SETTINGS ]]

MAX_IDLE_TIME_MINUTES = 10
NEED_BAIT = true -- set to false if you can fish without bait (prawn perk)

-- [[ END SETTINGS ]]

local ID = {
    FISHING_SPOT = { 30285 },
    SOLE = 55302,
    BANK_CHEST = { 126506 },
    BAIT = 313
}

local AREAS = {
    BANK = { x = 1107, y = 1741, z = 0 },
    FISHING_SPOT = { x = 1134, y = 1725, z = 0 },
}

local skill = "FISHING"
local startXp = API.GetSkillXP(skill)
local startTime, afk = os.time(), os.time()
local sole = 0
local lastTile = nil

local function findNpc(npcID, distance)
    distance = distance or 25
    local allNpc = API.GetAllObjArrayInteract(npcID, distance, {1})
    return allNpc[1] or false
end

-- Rounds a number to the nearest integer or to a specified number of decimal places.
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
    local solePH = round((sole * 60) / elapsedMinutes);
    IGP.radius = calcProgressPercentage(skill, API.GetSkillXP(skill)) / 100
    IGP.string_value = time ..
        " | " ..
        string.lower(skill):gsub("^%l", string.upper) ..
        ": " ..
        currentLevel ..
        " | XP/H: " ..
        formatNumber(xpPH) ..
        " | XP: " .. formatNumber(diffXp) .. " | Sole: " .. formatNumber(sole) .. " | Sole/H: " .. formatNumber(solePH)
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
    IGP.colour = ImColor.new(6, 82, 221);
    IGP.string_value = "UM FISHER"
end

local function drawGUI()
    DrawProgressBar(IGP)
end

local function deposit()
    local inventory = API.FetchBankInvArray()
    for _, inv in ipairs(inventory) do
        if inv.itemid1 == ID.SOLE then
            API.DoAction_Interface(-1, inv.itemid1, 1, inv.id1, inv.id2, inv.id3, API.OFF_ACT_GeneralInterface_route)
            API.RandomSleep2(300, 600, 600)
            break
        end
    end
end

local function bank()
    if API.BankOpen2() then
        sole = sole + API.InvItemcount_1(ID.SOLE)

        if API.VB_FindPSett(8958, -1, -1).state ~= 7 then
            API.DoAction_Interface(0x2e, 0xffffffff, 1, 517, 103, -1, API.OFF_ACT_GeneralInterface_route)
            API.RandomSleep2(800, 500, 300)
        end

        if not API.DoAction_Bank_Inv(ID.SOLE, 1, API.OFF_ACT_GeneralInterface_route2) then
            deposit()
        end
        API.RandomSleep2(300, 400, 400)
    else
        API.DoAction_Object1(0x5, 80, ID.BANK_CHEST, 50)
        API.RandomSleep2(300, 400, 400)
    end
end

local function fish()
    local spot = findNpc(ID.FISHING_SPOT, 20)
    if spot then
        API.DoAction_NPC(0x3c, API.OFF_ACT_InteractNPC_route, ID.FISHING_SPOT, 50);
        API.RandomSleep2(600, 300, 300)
    end
end

local function checkBait()
    if NEED_BAIT and API.InvStackSize(ID.BAIT) == 0 then
        print("No more bait")
        return false
    end
    return true
end

local function isAtUm()
    local isInBank = API.PInArea(AREAS.BANK.x, 30, AREAS.BANK.y, 30, 0)
    local isInFishingSpot = API.PInArea(AREAS.FISHING_SPOT.x, 30, AREAS.FISHING_SPOT.y, 30, 0)
    if isInBank or isInFishingSpot then
        return true
    else
        return false
    end
end

local function isAtBank()
    return API.PInArea(AREAS.BANK.x, 10, AREAS.BANK.y, 10, AREAS.BANK.z)
end

local function isAtFishing()
    return API.PInArea(AREAS.FISHING_SPOT.x, 10, AREAS.FISHING_SPOT.y, 10, AREAS.FISHING_SPOT.z)
end

local function walkToTile(tile)
    API.DoAction_Tile(tile)
    lastTile = tile
    API.RandomSleep2(600, 300, 300)
end

local function walk()
    if isAtBank() and not API.InvFull_() then
        walkToTile(WPOINT.new(AREAS.FISHING_SPOT.x + math.random(-2, 2), AREAS.FISHING_SPOT.y + math.random(-2, 2),
            0))
    elseif isAtFishing() then
        walkToTile(WPOINT.new(AREAS.BANK.x + math.random(-2, 2), AREAS.BANK.y + math.random(-2, 2), 0))
    end
    API.RandomSleep2(300, 500, 500)
end

setupGUI()

while API.Read_LoopyLoop() do
    idleCheck()
    drawGUI()

    API.DoRandomEvents()

    if not checkBait() or not isAtUm() then
        API.Write_LoopyLoop(false)
        break
    end

    p = API.PlayerCoordfloat()

    if API.ReadPlayerMovin2() or API.CheckAnim(3) then
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

    if API.InvFull_() then
        if isAtBank() then
            bank()
        else
            walk()
        end
    else
        if isAtFishing() then
            fish()
            API.CheckAnim(100)
        else
            walk()
        end
    end

    ::continue::
    printProgressReport()
    API.RandomSleep2(200, 200, 200)
end
