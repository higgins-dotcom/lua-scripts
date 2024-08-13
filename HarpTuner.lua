--[[

@title Harp Tuner
@description Tunes harmonium harps at the Ithell Clan district of Prifddinas
@author Higgins <discord@higginshax>
@date 25/09/2023
@version 1.0

--]]

local MAX_IDLE_TIME_MINUTES = 5

local API = require("api")

local startTime, afk = os.time(), os.time()
local skill = "CONSTRUCTION"
local startXp = API.GetSkillXP(skill)

local ID = {
    HARMONIC_DUST = 32622,
    HARP = {94059, 94060},
}

local startDust = API.InvStackSize(ID.HARMONIC_DUST)

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
    local dust = API.InvStackSize(ID.HARMONIC_DUST) - startDust
    local dustPH = round((dust * 60) / ((os.time() - startTime) / 60));
    IGP.radius = calcProgressPercentage(skill, API.GetSkillXP(skill)) / 100
    IGP.string_value = time ..
        " | " ..
        string.lower(skill):gsub("^%l", string.upper) ..
        ": " ..
        currentLevel ..
        " | XP/H: " ..
        formatNumber(xpPH) ..
        " | XP: " ..
        formatNumber(diffXp) ..
        " | Harmonic Dust: " .. formatNumber(dust) .. " | Harmonic Dust/H: " .. formatNumber(dustPH)
end

local function setupGUI()
    IGP = API.CreateIG_answer()
    IGP.box_start = FFPOINT.new(5, 5, 0)
    IGP.box_name = "PROGRESSBAR"
    IGP.colour = ImColor.new(116, 2, 179);
    IGP.string_value = "HARP TUNER"
end

local function drawGUI()
    DrawProgressBar(IGP)
end

setupGUI()

while API.Read_LoopyLoop() do
    drawGUI()
    local anim = API.ReadPlayerAnim()
    if anim ~= 25021 and anim ~= 25026 then
        API.DoAction_Object1(0xae, API.OFF_ACT_GeneralObject_route0, ID.HARP, 50)
        API.RandomSleep2(1500, 800, 800)
    elseif VB_FindPSettinOrder(4892).state / 65536 >= 25344 then
        API.DoAction_Object1(0xae, API.OFF_ACT_GeneralObject_route0, ID.HARP, 50)
        API.RandomSleep2(2500, 800, 800)
    end
    idleCheck()
    printProgressReport()
    API.RandomSleep2(500, 500, 500)
end