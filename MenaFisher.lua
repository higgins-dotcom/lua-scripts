API = require('api')

MAX_IDLE_TIME_MINUTES = 5
NEED_BAIT = false

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

local skill = "FISHING"
local startXp = API.GetSkillXP(skill)
local startTime, afk = os.time(), os.time()
local lastSpot = nil

local function findNpc(npcID, distance)
    distance = distance or 25
    local allNpc = API.GetAllObjArrayInteract(npcID, distance, 1)
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
    IGP.colour = ImColor.new(6, 82, 221);
    IGP.string_value = "MENAPHOS FISHER"
end

local function drawGUI()
    DrawProgressBar(IGP)
end

local function deposit()
    API.DoAction_Object1(0x29, 240, ID.BANKCHEST, 50)
    API.RandomSleep2(600, 300, 300)
end

local function fish()
    local spot = findNpc(ID.FISHINGSPOT, 20)
    if spot then
        lastSpot = { spot.CalcX, spot.CalcY }
        API.DoAction_NPC(0x3c, API.OFF_ACT_InteractNPC_route, ID.FISHINGSPOT, 50);
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

setupGUI()

while API.Read_LoopyLoop() do
    idleCheck()
    drawGUI()

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
    printProgressReport()
    API.RandomSleep2(200, 200, 200)
end