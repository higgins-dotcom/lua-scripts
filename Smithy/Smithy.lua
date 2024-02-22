--[[

@title Smithy
@description AIO Smither for the Artisan Guild
@author Higgins <discord@higginshax>
@date 10/01/2024
@version 1.5

Add tasks to the settings

--]]

local API = require("api")

-- [[ SETTINGS ]] --

local MAX_IDLE_TIME_MINUTES = 15

local tasks = {
    -- #########################################################################
    -- Add more tasks as needed
    -- Tasks are done in order, so if you want to do Rune Armoured Boots from 0 to Burial then the example shows
    -- Replace any spaces with underscore so ELDER RUNE = ELDER_RUNE
    -- ARMOURED BOOTS = ARMOURED_BOOTS
    -- Amount will be amount of times crafted, so for some items like Arrowheads amount 1 = 1x75 = 75 arrowheads

    -- [ -- SMITHING example -- ]
    -- { metalType = "ELDER_RUNE", itemType = "FULL_HELM", itemLevel = "BURIAL", amount = 1 },
    -- { metalType = "ELDER_RUNE",      itemType = "PLATEBODY",  itemLevel = 0,        amount = 28 },
    -- { metalType = "ELDER_RUNE",      itemType = "PLATEBODY",  itemLevel = 1,        amount = 28 },
    -- { metalType = "ELDER_RUNE",      itemType = "PLATEBODY",  itemLevel = 2,        amount = 28 },
    -- { metalType = "ELDER_RUNE",      itemType = "PLATEBODY",  itemLevel = 3,        amount = 28 },
    -- { metalType = "ELDER_RUNE",      itemType = "PLATEBODY",  itemLevel = 4,        amount = 28 },
    -- { metalType = "ELDER_RUNE",      itemType = "PLATEBODY",  itemLevel = 5,        amount = 27 },
    -- { metalType = "ELDER_RUNE",      itemType = "SET",  itemLevel = "BURIAL",        amount = 0 }
    -- { metalType = "ORIKALKUM",      itemType = "PLATEBODY",  itemLevel = 2,        amount = 1 },
    -- { metalType = "ORIKALKUM",      itemType = "PLATEBODY",  itemLevel = 3,        amount = 50 },
    -- { metalType = "STEEL",      itemType = "FULL_HELM",  itemLevel = 0, amount = 5 },

    -- If unsure - open the lib/smithing_data.json file and search for the item
    --
    -- [ -- SMELTING example -- ]
    -- Set metalType as required, leave itemType as bar and itemLevel as 0
    -- { metalType = "BRONZE",    itemType = "BAR",             itemLevel = 0,        amount = 90 }
    -- #########################################################################
}

-- [[ END SETTINGS ]] --

local skill = "SMITHING"
local startXp = API.GetSkillXP(skill)
local startTime, afk = os.time(), os.time()

local ID = {
    UNFINISHED_SMITHING_ITEM = 47068,
    NORMAL = {
        FORGE = { 113264, 112738, 113263 },
        ANVIL = 113262,
        FURNACE = { 113266, 113265 }
    },
    BURIAL = {
        FORGE = { 113267, 120051 },
        ANVIL = 113268,
    },
    BANK_CHEST = 85341
}

local AREA = {
    NORMAL = 1,
    BURIAL = 2
}

local AREA_ACTIONS = {
    [AREA.BURIAL] = {
        forge = function()
            API.DoAction_Object1(0x3f, 0, ID.BURIAL.FORGE, 10)
        end,
        anvil = function()
            API.DoAction_Object1(0x3f, 0, { ID.BURIAL.ANVIL }, 50)
        end
    },
    [AREA.NORMAL] = {
        forge = function()
            API.DoAction_Object1(0x3f, 0, ID.NORMAL.FORGE, 10)
        end,
        anvil = function()
            API.DoAction_Object1(0x3f, 0, { ID.NORMAL.ANVIL }, 50)
        end,
        furnance = function()
            API.DoAction_Object1(0x3f, 0, { ID.NORMAL.FURNACE }, 50)
        end
    },
}

local function getCurrentDirectory()
    local str = debug.getinfo(1, "S").source:sub(2)
    return str:match("(.*\\)") or ""
end

local function loadJsonData()
    local filename = getCurrentDirectory() .. "lib\\smithing_data.json"
    local file = io.open(filename, "r")
    local content = file:read("*all")
    file:close()
    local data = JsonDecode(content)
    ITEMS = data["ITEMS"]
    ITEM_LEVELS = data["ITEM_LEVELS"]
    SETTING_IDS = data["SETTING_IDS"]
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

local function printProgressReport()
    local currentXp = API.GetSkillXP(skill)
    local elapsedMinutes = (os.time() - startTime) / 60
    local diffXp = math.abs(currentXp - startXp)
    local xpPH = round((diffXp * 60) / elapsedMinutes)
    local time = formatElapsedTime(startTime)
    local currentLevel = API.XPLevelTable(API.GetSkillXP(skill))
    IGP.radius = calcProgressPercentage(skill, API.GetSkillXP(skill)) / 100
    local progress = time ..
        " | " ..
        string.lower(skill):gsub("^%l", string.upper) ..
        ": " .. currentLevel .. " | XP/H: " .. formatNumber(xpPH) .. " | XP: " .. formatNumber(diffXp)
    IGP.string_value = progress
end

local function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random((MAX_IDLE_TIME_MINUTES * 60) * 0.6, (MAX_IDLE_TIME_MINUTES * 60) * 0.9)

    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
    end
end

local function getItemText()
    return API.ScanForInterfaceTest2Get(false,
        { { 37, 17, -1, -1, 0 }, { 37, 19, -1, 17, 0 }, { 37, 29, -1, 19, 0 }, { 37, 40, -1, 29, 0 } })[1].textids
end

local function checkItemText(itemLevel)
    local itemText = getItemText()

    return (itemLevel == 0) and
        (not string.find(itemText, '+ ') and not string.find(itemText:lower(), 'burial')) or
        (type(itemLevel) == "number" and itemLevel > 0 and string.find(itemText, '+ ' .. itemLevel) ~= nil) or
        (type(itemLevel) == "string" and itemLevel:upper() == "BURIAL" and string.find(itemText:lower(), 'burial') ~= nil) or
        false
end

local function selectItem(bar, choice)
    if not (VB_FindPSettinOrder(8332, -1).state == SETTING_IDS[bar].BAR) and (choice.ITEM_TYPE ~= "BAR") then
        -- if not (API.VB_FindPSett(8332, -1, -1).state == SETTING_IDS[bar].BAR) and (choice.ITEM_TYPE ~= "BAR") then
        API.DoAction_Interface(0xffffffff, 0x93b, 1, 37, 52, SETTING_IDS[bar].INTERFACE,
            API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(600, 600, 600)
    end

    if not checkItemText(choice.ITEM_LEVEL) then
        API.DoAction_Interface(0x24, 0xffffffff, 1, 37, ITEM_LEVELS[tostring(choice.ITEM_LEVEL)], -1,
            API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(600, 600, 600)
    end

    local base = { { 37, 17, -1, -1, 0 }, { 37, 19, -1, 17, 0 }, { 37, 26, -1, 19, 0 }, { 37, 27, -1, 26, 0 } }

    local sections = {
        { { 37, 93, -1, 27, 0 },  { 37, 103, -1, 93, 0 } },
        { { 37, 104, -1, 27, 0 }, { 37, 114, -1, 104, 0 } },
        { { 37, 115, -1, 27, 0 }, { 37, 125, -1, 115, 0 } },
        { { 37, 126, -1, 27, 0 }, { 37, 136, -1, 126, 0 } },
        { { 37, 137, -1, 27, 0 }, { 37, 147, -1, 137, 0 } },
    }

    for _, section in ipairs(sections) do
        local combined = {}
        for _, element in ipairs(base) do
            table.insert(combined, element)
        end
        for _, element in ipairs(section) do
            table.insert(combined, element)
        end

        local opt = API.ScanForInterfaceTest2Get(true, combined)
        for _, v in ipairs(opt) do
            if v.itemid1 == choice.OUTPUT then
                API.DoAction_Interface(0xffffffff, string.format("0x%X", choice.OUTPUT), 1, v.id1, v.id2, v.id3,
                    API.OFF_ACT_GeneralInterface_route)
                break
            end
        end
    end
end

local function isSmithingInterfaceOpen()
    return API.Compare2874Status(85, false)
end

local function openSmithingInterface(area)
    local forgeObject = area == AREA.BURIAL and ID.BURIAL.FORGE or ID.NORMAL.FORGE
    if selectedItemType == "BAR" then
        forgeObject = ID.NORMAL.FURNACE
    end
    local action = selectedItemType == "BAR" and 0x3f or 0x29
    local offset = selectedItemType == "BAR" and 0 or 240
    API.DoAction_Object1(action, offset, forgeObject, 50)
    API.RandomSleep2(800, 400, 600)
end

local function hasOption()
    local option = API.ScanForInterfaceTest2Get(false,
        { { 1188, 5, -1, -1, 0 }, { 1188, 3, -1, 5, 0 }, { 1188, 3, 14, 3, 0 } })
    if #option > 0 then
        if #option[1].textids > 0 then
            return option[1].textids
        end
    end
    return false
end

local function checkStorage(choice)
    if choice.ITEM_LEVEL == "BURIAL" then return true end
    if choice.ITEM_TYPE == "BAR" then
        return VB_FindPSettinOrder(8336, -1).state > 0
        -- return API.VB_FindPSett(8336, -1, -1).state > 0
    else
        local barId = ITEMS[choice.BAR]["BAR"]["0"]["BASE"]
        if (API.Container_Get_s(858, barId).item_stack < 10) then
            return false
        end
        return true
    end
end

local function hasUnfinishedItems()
    return API.CheckInvStuff0(ID.UNFINISHED_SMITHING_ITEM)
end

local function invContains(item)
    if type(item) == "number" then
        return API.InvItemFound1(item)
    elseif type(item) == "table" then
        local items = API.ReadInvArrays33()
        for _, tableItem in ipairs(item) do
            local found = false
            for k, v in pairs(items) do
                if v.itemid1 > 0 and v.itemid1 == tableItem then
                    found = true
                    break
                end
            end
            if not found then
                return false
            end
        end
        return true
    elseif item == nil then
        return false
    end
end

local function Action_Bank(item)
    local inventory = API.FetchBankArray()
    for _, inv in ipairs(inventory) do
        if inv.itemid1 == item then
            API.DoAction_Interface(-1, inv.itemid1, 1, inv.id1, inv.id2, inv.id3, API.OFF_ACT_GeneralInterface_route)
            API.RandomSleep2(300, 600, 600)
            break
        end
    end
end

local function bank(item)
    if selectedItemType == "BAR" then
        API.DoAction_Object1(0x29, 80, ID.NORMAL.FURNACE, 50)
        API.RandomSleep2(600, 600, 600)
    else
        if API.BankOpen2() then
            if API.Invfreecount_() < 26 then
                API.KeyboardPress2(0x33, 60, 120)
                API.RandomSleep2(300, 600, 600)
            end

            if type(item) == "number" then
                if API.BankGetItemStack1(item) > 0 then
                    if VB_FindPSettinOrder(8958, -1).state ~= 7 then
                        -- if API.VB_FindPSett(8958, -1, -1).state ~= 7 then
                        API.DoAction_Interface(0x2e, 0xffffffff, 1, 517, 103, -1, API.OFF_ACT_GeneralInterface_route)
                        API.RandomSleep2(800, 500, 300)
                    end
                    if not API.DoAction_Bank(item, 1, API.OFF_ACT_GeneralInterface_route) then
                        Action_Bank(item)
                    end
                    API.RandomSleep2(800, 500, 300)
                else
                    return false
                end
            elseif type(item) == "table" then
                local itemCount = #item
                local slotsToWithdraw = math.floor(28 / itemCount)

                for _, tableItem in ipairs(item) do
                    for i = 1, slotsToWithdraw do
                        if API.BankGetItemStack1(tableItem) > 0 then
                            if VB_FindPSettinOrder(8958, -1).state ~= 2 then
                                -- if API.VB_FindPSett(8958, -1, -1).state ~= 2 then
                                API.DoAction_Interface(0x2e, 0xffffffff, 1, 517, 93, -1,
                                    API.OFF_ACT_GeneralInterface_route)
                                API.RandomSleep2(800, 500, 300)
                            end
                            if not API.DoAction_Bank(tableItem, 1, API.OFF_ACT_GeneralInterface_route) then
                                Action_Bank(item)
                            end
                            API.RandomSleep2(800, 500, 300)
                        else
                            if i == 1 then return false end
                            break
                        end
                    end
                end
            elseif item == nil then
                if API.Invfreecount_() < 26 then
                    API.KeyboardPress2(0x33, 60, 120)
                    API.RandomSleep2(300, 600, 600)
                end
                API.KeyboardPress2(0x1B, 60, 120)
                API.RandomSleep2(800, 600, 600)
            end
        else
            if API.DoAction_Object1(0x2e, 0, { ID.BANK_CHEST }, 50) then
                API.RandomSleep2(800, 500, 300)
            end
        end
    end
    return true
end

local function setupGUI()
    IGP = API.CreateIG_answer()
    IGP.box_start = FFPOINT.new(5, 5, 0)
    IGP.box_name = "PROGRESSBAR"
    IGP.colour = ImColor.new(6, 82, 221);
    IGP.string_value = "SMITHY LOADING..."
    IGP.radius = 100.0
end

local function drawGUI()
    API.DrawProgressBar(IGP)
end

-- sword stuff
-- 8936 Lige
-- DO::DoAction_NPC(0x2c,3120,{ ids },50);
-- space
-- sword 20561

setupGUI()

local currentTaskIndex = 1
local wasFull = false
selectedItemType = nil

loadJsonData()

while API.Read_LoopyLoop() do
    if currentTaskIndex > #tasks then
        print("No more tasks")
        break
    end
    local currentTask = tasks[currentTaskIndex]

    e = e or 0
    API.DoRandomEvents()
    drawGUI()
    idleCheck()

    if API.ReadPlayerMovin2() or API.isProcessing() then
        goto continue
    end

    if API.Compare2874Status(12) then
        o = hasOption()
        if o and o == "Continue making a burial item?" or
            o == "Would you like to partake in ceremonial smithing?" then
            API.KeyboardPress2(0x32, 60, 100)
        else
            API.KeyboardPress2(0x20, 60, 100)
        end
        API.RandomSleep2(600, 800, 800)
        goto continue
    end

    if currentTask then
        local currentTask = tasks[currentTaskIndex]
        selectedBarType = currentTask.metalType
        selectedItemType = currentTask.itemType
        selectedItemLevel = currentTask.itemLevel
        if type(selectedItemLevel) == "number" then
            itemLevel = tostring(selectedItemLevel)
            ID.ANVIL = ID.ANVIL
            ID.FORGE = ID.BURIAL.FORGE
        else
            if selectedItemType == "SET" then
                itemLevel = "0"
            else
                itemLevel = "BURIAL"
            end
            ID.ANVIL = ID.BURIAL.ANVIL
            ID.FORGE = ID.BURIAL.FORGE
        end

        local area = itemLevel == "BURIAL" and AREA.BURIAL or AREA.NORMAL
        if selectedItemType == "SET" then area = AREA.BURIAL end
        local success, choice = pcall(function()
            return ITEMS[currentTask.metalType][currentTask.itemType][itemLevel]
        end)

        if choice then
            choice.ITEM_LEVEL = selectedItemLevel
            choice.ITEM_TYPE = selectedItemType
            choice.BAR = selectedBarType

            if (
                    (choice.INPUT == nil and not API.InvFull_()) or
                    invContains(choice.INPUT)
                ) and
                currentTask.amount > 0 and not wasFull
            then
                wasFull = false
                if isSmithingInterfaceOpen() then
                    if VB_FindPSettinOrder(8333, -1).state == choice.BASE and checkItemText(choice.ITEM_LEVEL) then
                        -- if API.VB_FindPSett(8333, -1, -1).state == choice.BASE and checkItemText(choice.ITEM_LEVEL) then
                        if not checkStorage(choice) then
                            print("Bar quantity less than 10 - halting task")
                            currentTaskIndex = currentTaskIndex + 1
                            goto continue
                        end

                        if selectedItemType == "BAR" then
                            local quantity = VB_FindPSettinOrder(8336, -1).state
                            -- local quantity = API.VB_FindPSett(8336, -1, -1).state
                            API.KeyboardPress2(0x20, 60, 100)
                            API.RandomSleep2(600, 800, 1200)
                            currentTask.amount = currentTask.amount - quantity
                        else
                            if VB_FindPSettinOrder(8332, -1).state == SETTING_IDS[selectedBarType].BAR then
                                -- if API.VB_FindPSett(8332, -1, -1).state == SETTING_IDS[selectedBarType].BAR then
                                API.KeyboardPress2(0x20, 60, 100)
                                API.RandomSleep2(600, 800, 1200)
                                currentTask.amount = currentTask.amount - 1
                            else
                                selectItem(selectedBarType, choice)
                                API.RandomSleep2(500, 300, 300)
                            end
                        end
                    else
                        selectItem(selectedBarType, choice)
                        API.RandomSleep2(500, 300, 300)
                    end
                else
                    openSmithingInterface(area)
                end
            elseif hasUnfinishedItems() then
                wasFull = true
                if API.LocalPlayer_HoverProgress() <= 165 then
                    if API.LocalPlayer_HoverProgress() == 0 then
                        if e < 3 then
                            e = e + 1
                            goto continue
                        end
                        e = 0
                    end
                    AREA_ACTIONS[area]['forge']()
                    API.RandomSleep2(1800, 2000, 2200);
                    AREA_ACTIONS[area]['anvil']()
                    API.RandomSleep2(1800, 2000, 2200);
                else
                    if not API.CheckAnim(50) then
                        AREA_ACTIONS[area]['anvil']()
                        API.RandomSleep2(600, 200, 200);
                    end
                end
            else
                if currentTask.amount > 0 then
                    if not bank(choice.INPUT) then
                        currentTaskIndex = currentTaskIndex + 1
                    end
                else
                    currentTaskIndex = currentTaskIndex + 1
                end
                wasFull = false
            end
        else
            print("Invalid item in tasks - please check task list for spelling errors/invalid levels etc")
            break
        end
    end

    ::continue::
    printProgressReport()
    API.RandomSleep2(200, 200, 200)
end