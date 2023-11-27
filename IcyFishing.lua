--[[

@title Icy Fishing
@description Fishes at the Icy Fishing spot at Christmas Village
@author Higgins <discord@higginshax>
@date 27/11/2023
@version 1.0

--]]

-- ## USER SETTINGS ## --
local MAX_IDLE_TIME_MINUTES = 10
-- ##      END      ## --

local API = require("api")

local ID = {
    ICY_FISHING_SPOT = 30755,
    FROZEN_FISH = {56165,56166,56167},
    BARREL_OF_FISH = 128783
}

local skill = "FISHING"
local startXp = API.GetSkillXP(skill)
local startTime, afk = os.time(), os.time()
local startChristmasSpirits

local function readChristmasSpirits()
    local base = { { 1272,6,-1,-1,0 }, { 1272,2,-1,6,0 }, { 1272,8,-1,2,0 } }
    local spirits = API.ScanForInterfaceTest2Get(false, base)[1].textids
    local str = spirits:gsub("[^%d]+", "")
    return tonumber(str:match("(%d[%d,]*)"))
end

local function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random((MAX_IDLE_TIME_MINUTES * 60) * 0.6, (MAX_IDLE_TIME_MINUTES * 60) * 0.9)

    if timeDiff > randomTime then
        local rnd1 = math.random(25, 28)
        local rnd2 = math.random(25, 28)

        API.KeyboardPress31(0x28, math.random(20, 60), math.random(50, 200))
        API.KeyboardPress31(0x27, math.random(20, 60), math.random(50, 200))

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

function formatNumber(num)
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
    local christmasSpirits = readChristmasSpirits() - startChristmasSpirits
    local christmasSpiritsPH = round((christmasSpirits * 60) / elapsedMinutes)
    local time = formatElapsedTime(startTime)
    local currentLevel = API.XPLevelTable(API.GetSkillXP(skill))
    IGP.radius = calcProgressPercentage(skill, API.GetSkillXP(skill)) / 100
    IGP.string_value = time ..
        " | " ..
        string.lower(skill):gsub("^%l", string.upper) ..
        ": " .. currentLevel .. " | XP/H: " .. formatNumber(xpPH) .. " | XP: " .. formatNumber(diffXp) .. " | Christmas Spirits: " .. formatNumber(christmasSpirits) .. " | Christmas Spirits/H: " .. formatNumber(christmasSpiritsPH)
end

local function setupGUI()
    IGP = API.CreateIG_answer()
    IGP.box_start = FFPOINT.new(5, 5, 0)
    IGP.box_name = "PROGRESSBAR"
    IGP.colour = ImColor.new(6, 82, 221);
    IGP.string_value = "ICY FISHING"
end

local function drawGUI()
    DrawProgressBar(IGP)
end

local function hasFrozenFish()
    local fish = API.InvItemcount_2(ID.FROZEN_FISH)
    for _, v in ipairs(fish) do
        if v > 0 then
            return true
        end
    end
    return false
end

local function depositFish()
    API.DoAction_Object1(0x29,0,{ ID.BARREL_OF_FISH },50)
    API.RandomSleep2(800, 300, 300)
end

local function catch()
    API.DoAction_NPC(0x29,3120,{ ID.ICY_FISHING_SPOT },50)
    API.RandomSleep2(2200, 300, 300)
end

setupGUI()

startChristmasSpirits = readChristmasSpirits()

while (API.Read_LoopyLoop()) do
    idleCheck()
    drawGUI()
    readChristmasSpirits()
    API.DoRandomEvents()

    if API.ReadPlayerMovin2() or (API.ReadPlayerAnim() > 0) then
        goto continue
    end

    if not API.InventoryInterfaceCheckvarbit() then
        API.KeyboardPress2(0x42, 60, 100)
        API.RandomSleep2(600, 300, 300)
        goto continue
    end

    if API.InvFull_() then
        if hasFrozenFish() then
            depositFish()
        else
            print("InvFull - No frozen fish detected - stopping")
            API.Write_LoopyLoop(false)
            break
        end
    else
        catch()
    end

    ::continue::
    printProgressReport()
    API.RandomSleep2(100, 200, 200)
end