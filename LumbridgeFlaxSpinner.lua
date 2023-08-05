--[[

@title Lumbridge Castle Flax Spinner
@description Spins flax into bowstrings
@author Higgins <discord@higginshax>
@date 22/07/2023
@version 1.0

Flax Bank Preset 1
Start at top of Lumbridge Castle bank

Crafting XP Per Hour ~ 20,000
Bowstrings Per Hour ~ 1,200

On screen paint progress report and final progress report output to console window

--]]

local API = require("api")
local startTime = os.time()
local startXp = API.GetSkillXP("CRAFTING")
local strings, fail = 0, 0

ID = {
    FLAX = 1779,
    BOWSTRING = 1777,
    SPINNING_WHEEL = 36970,
    STAIRS_DOWN = 36775,
    STAIRS_UP = 36774,
    BANK_BOOTH = 36786
}

-- Rounds a number to the nearest integer or to a specified number of decimal places.
local function round(val, decimal)
    if decimal then
        return math.floor((val * 10 ^ decimal) + 0.5) / (10 ^ decimal)
    else
        return math.floor(val + 0.5)
    end
end

-- Format a number with commas as thousands separator
local function formatNumberWithCommas(amount)
    local formatted = tostring(amount)
    while true do
        formatted, k = string.gsub(formatted, "^(-?%d+)(%d%d%d)", '%1,%2')
        if (k == 0) then
            break
        end
    end
    return formatted
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

local function printProgressReport(final)
    local currentXp = API.GetSkillXP("CRAFTING")
    local elapsedMinutes = (os.time() - startTime) / 60
    local diffXp = math.abs(currentXp - startXp);
    local xpPH = round((diffXp * 60) / elapsedMinutes);
    local stringPH = round((strings * 60) / elapsedMinutes);
    local time = formatElapsedTime(startTime)
    IG.string_value = "Crafting XP : " .. formatNumberWithCommas(diffXp) .. " (" .. formatNumberWithCommas(xpPH) .. ")"
    IG2.string_value = "  Bowstring : " .. formatNumberWithCommas(strings) .. " (" .. formatNumberWithCommas(stringPH) .. ")"
    IG4.string_value = time
    if final then
        print(os.date("%H:%M:%S") .. " Script Finished\nRuntime : " .. time .. "\nCrafting XP : " .. formatNumberWithCommas(diffXp) .. " \nBowstrings : " .. formatNumberWithCommas(strings))
    end
end

local function scanForInterface(interfaceComps)
    return #(API.ScanForInterfaceTest2Get(true, interfaceComps)) > 0
end

local function isCrafterOpen()
    return scanForInterface {
        InterfaceComp5.new(1371, 7, -1, -1, 0),
        InterfaceComp5.new(1371, 0, -1, 7, 0),
        InterfaceComp5.new(1371, 15, -1, 0, 0),
        InterfaceComp5.new(1371, 21, -1, 15, 0)
    }
end

local function spin()
    if isCrafterOpen() then
        API.KeyboardPress2(0x20, 60, 100)
        API.RandomSleep2(300, 600, 800)
    else
        API.DoAction_Object1(0x3e, 80, { ID.SPINNING_WHEEL }, 50)
        API.RandomSleep2(300, 400, 500)
    end
end

local function stairsUp()
    API.DoAction_Object1(0x34, 80, { ID.STAIRS_UP }, 50)
    API.RandomSleep2(600, 400, 500)
end

local function stairsDown()
    API.DoAction_Object1(0x35, 0, { ID.STAIRS_DOWN }, 50)
    API.RandomSleep2(800, 400, 500)
end

local function bank()
    if API.BankOpen2() then
        strings = strings + API.InvItemcount_1(ID.BOWSTRING)
        API.KeyboardPress2(0x31, 60, 100)
        API.RandomSleep2(300, 400, 400)
    else
        API.DoAction_Object1(0x5, 80, { ID.BANK_BOOTH }, 50)
        API.RandomSleep2(300, 600, 800)
    end
end

local function setupGUI()
    IG = API.CreateIG_answer()
    IG.box_start = FFPOINT.new(15, 40, 0)
    IG.box_name = "CRAFT"
    IG.colour = ImColor.new(255, 255, 255);
    IG.string_value = "Crafting XP : 0 (0)"

    IG2 = API.CreateIG_answer()
    IG2.box_start = FFPOINT.new(15, 55, 0)
    IG2.box_name = "STRING"
    IG2.colour = ImColor.new(255, 255, 255);
    IG2.string_value = "  Bowstring : 0 (0)"

    IG3 = API.CreateIG_answer()
    IG3.box_start = FFPOINT.new(40, 5, 0)
    IG3.box_name = "TITLE"
    IG3.colour = ImColor.new(0, 255, 0);
    IG3.string_value = "- Flax Spinner v1.0 -"

    IG4 = API.CreateIG_answer()
    IG4.box_start = FFPOINT.new(70, 21, 0)
    IG4.box_name = "TIME"
    IG4.colour = ImColor.new(255, 255, 255);
    IG4.string_value = "[00:00:00]"

    IG_Back = API.CreateIG_answer();
    IG_Back.box_name = "back";
    IG_Back.box_start = FFPOINT.new(0, 0, 0)
    IG_Back.box_size = FFPOINT.new(220, 80, 0)
    IG_Back.colour = ImColor.new(15, 13, 18, 255)
    IG_Back.string_value = ""
end

function drawGUI()
    API.DrawSquareFilled(IG_Back)
    API.DrawTextAt(IG)
    API.DrawTextAt(IG2)
    API.DrawTextAt(IG3)
    API.DrawTextAt(IG4)
end

setupGUI()

while API.Read_LoopyLoop() do

    drawGUI()

    if API.CheckAnim(10) or API.isProcessing() or API.ReadPlayerMovin2() then
        API.RandomSleep2(50, 100, 100)
        goto continue
    end

    if API.InvItemcount_1(ID.BOWSTRING) > 0 or API.InvItemcount_1(ID.FLAX) < 1 then
        if API.GetFloorLv_2() == 2 then
            bank()
            if API.InvItemcount_1(ID.FLAX) < 1 then
                fail = fail + 1
            end
            if fail > 2 then
                API.Write_LoopyLoop(0)
                printProgressReport(true)
                break
            end
        else
            stairsUp()
        end
    elseif API.InvItemcount_1(ID.FLAX) > 0 then
        fail = 0
        if API.GetFloorLv_2() == 2 then
            stairsDown()
        else
            spin()
        end
    end

    ::continue::
    printProgressReport()
    API.RandomSleep2(100, 200, 200)
end