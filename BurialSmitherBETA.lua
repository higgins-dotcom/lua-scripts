--[[

@title Burial Smither
@description Smiths burial items at the Artisan Guild
@author Higgins <discord@higginshax>
@date 28/12/2023
@version 1.0

Add tasks to the settings
Ensure you have plenty of bars in the smithing storage (no checks atm)

--]]

local API = require("api")

-- [[ SETTINGS ]] --

local MAX_IDLE_TIME_MINUTES = 15

local tasks = {
    { metalType = "ELDER_RUNE", itemType = "SET" },
    -- { metalType = "RUNE",    itemType = "SCIMITAR" },
    -- { metalType = "ADAMANT", itemType = "ARMOURED_BOOTS" }
    -- { metalType = "RUNE",    itemType = "GAUNTLETS" },
    -- { metalType = "RUNE",    itemType = "BATTLEAXE" },
    -- { metalType = "ADAMANT", itemType = "FULL_HELM" },
    -- { metalType = "ADAMANT", itemType = "2H_SWORD" },
    -- Add more tasks as needed
}

-- [[ END SETTINGS ]] --

local skill = "SMITHING"
local startXp = API.GetSkillXP(skill)
local startTime, afk = os.time(), os.time()

local ID = {
    UNFINISHED_SMITHING_ITEM = 47068,
    BURIAL = {
        FORGE = 113267,
        ANVIL = 113268,
        BANK_CHEST = 85341
    }
}

local ITEMS = {
    ADAMANT = {
        DAGGER = {
            BASE = 45495,
            OUTPUT = 44853,
            INPUT = 44850,
        },
        OFF_HAND_DAGGER = {
            BASE = 45496,
            OUTPUT = 44861,
            INPUT = 44858,
        },
        MACE = {
            BASE = 45497,
            OUTPUT = 44869,
            INPUT = 44866,
        },
        OFF_HAND_MACE = {
            BASE = 45498,
            OUTPUT = 44877,
            INPUT = 44874,
        },
        SWORD = {
            BASE = 45499,
            OUTPUT = 44885,
            INPUT = 44882,
        },
        OFF_HAND_SWORD = {
            BASE = 45500,
            OUTPUT = 44893,
            INPUT = 44890,
        },
        SCIMITAR = {
            BASE = 45501,
            OUTPUT = 44901,
            INPUT = 44898,
        },
        OFF_HAND_SCIMITAR = {
            BASE = 45502,
            OUTPUT = 44909,
            INPUT = 44906,
        },
        LONGSWORD = {
            BASE = 45503,
            OUTPUT = 44917,
            INPUT = 44914,
        },
        OFF_HAND_LONGSWORD = {
            BASE = 45504,
            OUTPUT = 44925,
            INPUT = 44922,
        },
        WARHAMMER = {
            BASE = 44926,
            OUTPUT = 44935,
            INPUT = 44932,
        },
        OFF_HAND_WARHAMMER = {
            BASE = 44936,
            OUTPUT = 44945,
            INPUT = 44942,
        },
        BATTLEAXE = {
            BASE = 45507,
            OUTPUT = 44953,
            INPUT = 44950,
        },
        OFF_HAND_BATTLEAXE = {
            BASE = 45508,
            OUTPUT = 44961,
            INPUT = 44958,
        },
        CLAWS = {
            BASE = 45509,
            OUTPUT = 44969,
            INPUT = 44966,
        },
        OFF_HAND_CLAWS = {
            BASE = 45510,
            OUTPUT = 44977,
            INPUT = 44974,
        },
        ["2H_SWORD"] = {
            BASE = 45511,
            OUTPUT = 44985,
            INPUT = 44982,
        },
        FULL_HELM = {
            BASE = 45512,
            OUTPUT = 44993,
            INPUT = 44990,
        },
        MED_HELM = {
            BASE = 45513,
            OUTPUT = 45001,
            INPUT = 44998,
        },
        PLATELEGS = {
            BASE = 45514,
            OUTPUT = 45009,
            INPUT = 45006,
        },
        PLATESKIRT = {
            BASE = 45515,
            OUTPUT = 45017,
            INPUT = 45014,
        },
        PLATEBODY = {
            BASE = 45516,
            OUTPUT = 45025,
            INPUT = 45022,
        },
        CHAINBODY = {
            BASE = 45517,
            OUTPUT = 45033,
            INPUT = 45030,
        },
        SQUARE_SHIELD = {
            BASE = 45518,
            OUTPUT = 45041,
            INPUT = 45038,
        },
        KITESHIELD = {
            BASE = 45519,
            OUTPUT = 45049,
            INPUT = 45046,
        },
        ARMOURED_BOOTS = {
            BASE = 45520,
            OUTPUT = 45057,
            INPUT = 45054,
        },
        GAUNTLETS = {
            BASE = 45058,
            OUTPUT = 45067,
            INPUT = 45064,
        },
        PICKAXE = {
            BASE = 45521,
            OUTPUT = 45075,
            INPUT = 45072,
        }
    },
    BANE = {
        LONGSWORD = {
            BASE = 45076,
            OUTPUT = 45101,
            INPUT = 45096,
        },
        OFF_HAND_LONGSWORD = {
            BASE = 45102,
            OUTPUT = 45127,
            INPUT = 45122,
        },
        ["2H_SWORD"] = {
            BASE = 45128,
            OUTPUT = 45153,
            INPUT = 45148,
        },
        PICKAXE = {
            BASE = 45154,
            OUTPUT = 45164,
            INPUT = 45162,
        },
        FULL_HELM = {
            BASE = 45165,
            OUTPUT = 45190,
            INPUT = 45185,
        },
        PLATELEGS = {
            BASE = 45191,
            OUTPUT = 45216,
            INPUT = 45211,
        },
        PLATEBODY = {
            BASE = 45217,
            OUTPUT = 45242,
            INPUT = 45237,
        },
        SQUARE_SHIELD = {
            BASE = 45243,
            OUTPUT = 45268,
            INPUT = 45263,
        },
        ARMOURED_BOOTS = {
            BASE = 45269,
            OUTPUT = 45294,
            INPUT = 45289,
        },
        GAUNTLETS = {
            BASE = 45295,
            OUTPUT = 45320,
            INPUT = 45315,
        }
    },
    ELDER_RUNE = {
        LONGSWORD = {
            BASE = 45549,
            OUTPUT = 45579,
            INPUT = 45574,
        },
        OFF_HAND_LONGSWORD = {
            BASE = 45580,
            OUTPUT = 45610,
            INPUT = 45605,
        },
        ["2H_SWORD"] = {
            BASE = 45611,
            OUTPUT = 45641,
            INPUT = 45636,
        },
        PICKAXE = {
            BASE = 45642,
            OUTPUT = 45654,
            INPUT = 45652,
        },
        FULL_HELM = {
            BASE = 45655,
            OUTPUT = 45685,
            INPUT = 45680,
        },
        PLATELEGS = {
            BASE = 45686,
            OUTPUT = 45716,
            INPUT = 45711,
        },
        PLATEBODY = {
            BASE = 45717,
            OUTPUT = 45747,
            INPUT = 45742,
        },
        ROUND_SHIELD = {
            BASE = 45748,
            OUTPUT = 45778,
            INPUT = 45773,
        },
        ARMOURED_BOOTS = {
            BASE = 45779,
            OUTPUT = 45809,
            INPUT = 45804,
        },
        GAUNTLETS = {
            BASE = 45810,
            OUTPUT = 45840,
            INPUT = 45835,
        },
        SET = {
            BASE = 45440,
            INPUT = { 45742, 45680, 45835, 45804, 45711 },
            OUTPUT = 45440
        }
    },
    NECRONIUM = {
        BATTLEAXE = {
            BASE = 46294,
            OUTPUT = 46319,
            INPUT = 46314,
        },
        OFF_HAND_BATTLEAXE = {
            BASE = 46320,
            OUTPUT = 46345,
            INPUT = 46340,
        },
        ["2H_GREATAXE"] = {
            BASE = 46346,
            OUTPUT = 46371,
            INPUT = 46366,
        },
        PICKAXE = {
            BASE = 46372,
            OUTPUT = 46382,
            INPUT = 46380,
        },
        FULL_HELM = {
            BASE = 46383,
            OUTPUT = 46408,
            INPUT = 46403,
        },
        PLATELEGS = {
            BASE = 46409,
            OUTPUT = 46434,
            INPUT = 46429,
        },
        PLATEBODY = {
            BASE = 46435,
            OUTPUT = 46460,
            INPUT = 46455,
        },
        KITESHIELD = {
            BASE = 46461,
            OUTPUT = 46486,
            INPUT = 46481,
        },
        ARMOURED_BOOTS = {
            BASE = 46487,
            OUTPUT = 46512,
            INPUT = 46507,
        },
        GAUNTLETS = {
            BASE = 46513,
            OUTPUT = 46538,
            INPUT = 46533,
        }
    },
    ORIKALKUM = {
        WARHAMMER = {
            BASE = 46539,
            OUTPUT = 46551,
            INPUT = 46548,
        },
        OFF_HAND_WARHAMMER = {
            BASE = 46552,
            OUTPUT = 46564,
            INPUT = 46561,
        },
        ["2H_WARHAMMER"] = {
            BASE = 46565,
            OUTPUT = 46577,
            INPUT = 46574,
        },
        PICKAXE = {
            BASE = 46578,
            OUTPUT = 46590,
            INPUT = 46587,
        },
        FULL_HELM = {
            BASE = 46591,
            OUTPUT = 46603,
            INPUT = 46600,
        },
        PLATELEGS = {
            BASE = 46604,
            OUTPUT = 46616,
            INPUT = 46613,
        },
        PLATEBODY = {
            BASE = 46617,
            OUTPUT = 46629,
            INPUT = 46626,
        },
        KITESHIELD = {
            BASE = 46630,
            OUTPUT = 46642,
            INPUT = 46639,
        },
        ARMOURED_BOOTS = {
            BASE = 46643,
            OUTPUT = 46655,
            INPUT = 46652,
        },
        GAUNTLETS = {
            BASE = 46656,
            OUTPUT = 46668,
            INPUT = 46665,
        },
    },
    RUNE = {
        DAGGER = {
            BASE = 45522,
            OUTPUT = 46678,
            INPUT = 46675,
        },
        OFF_HAND_DAGGER = {
            BASE = 45523,
            OUTPUT = 46688,
            INPUT = 46685,
        },
        MACE = {
            BASE = 45524,
            OUTPUT = 46698,
            INPUT = 46695,
        },
        OFF_HAND_MACE = {
            BASE = 45525,
            OUTPUT = 46708,
            INPUT = 46705,
        },
        SWORD = {
            BASE = 45526,
            OUTPUT = 46718,
            INPUT = 46715,
        },
        OFF_HAND_SWORD = {
            BASE = 45527,
            OUTPUT = 46728,
            INPUT = 46725,
        },
        SCIMITAR = {
            BASE = 45528,
            OUTPUT = 46738,
            INPUT = 46735,
        },
        OFF_HAND_SCIMITAR = {
            BASE = 45529,
            OUTPUT = 46748,
            INPUT = 46745,
        },
        LONGSWORD = {
            BASE = 45530,
            OUTPUT = 46758,
            INPUT = 46755,
        },
        OFF_HAND_LONGSWORD = {
            BASE = 45531,
            OUTPUT = 46768,
            INPUT = 46765,
        },
        WARHAMMER = {
            BASE = 45532,
            OUTPUT = 46778,
            INPUT = 46775,
        },
        OFF_HAND_WARHAMMER = {
            BASE = 45533,
            OUTPUT = 46788,
            INPUT = 46785,
        },
        BATTLEAXE = {
            BASE = 45534,
            OUTPUT = 46798,
            INPUT = 46795,
        },
        OFF_HAND_BATTLEAXE = {
            BASE = 45535,
            OUTPUT = 46808,
            INPUT = 46805,
        },
        CLAWS = {
            BASE = 45536,
            OUTPUT = 46818,
            INPUT = 46815,
        },
        OFF_HAND_CLAWS = {
            BASE = 45537,
            OUTPUT = 46828,
            INPUT = 46825,
        },
        ["2H_SWORD"] = {
            BASE = 45538,
            OUTPUT = 46838,
            INPUT = 46835,
        },
        FULL_HELM = {
            BASE = 45539,
            OUTPUT = 46848,
            INPUT = 46845,
        },
        MED_HELM = {
            BASE = 45540,
            OUTPUT = 46858,
            INPUT = 46855,
        },
        PLATELEGS = {
            BASE = 45541,
            OUTPUT = 46868,
            INPUT = 46865,
        },
        PLATESKIRT = {
            BASE = 45542,
            OUTPUT = 46878,
            INPUT = 46875,
        },
        PLATEBODY = {
            BASE = 45543,
            OUTPUT = 46888,
            INPUT = 46885,
        },
        CHAINBODY = {
            BASE = 45544,
            OUTPUT = 46898,
            INPUT = 46895,
        },
        SQUARE_SHIELD = {
            BASE = 45545,
            OUTPUT = 46908,
            INPUT = 46905,
        },
        KITESHIELD = {
            BASE = 45546,
            OUTPUT = 46918,
            INPUT = 46915,
        },
        ARMOURED_BOOTS = {
            BASE = 45547,
            OUTPUT = 46928,
            INPUT = 46925,
        },
        GAUNTLETS = {
            BASE = 46929,
            OUTPUT = 46941,
            INPUT = 46938,
        },
        PICKAXE = {
            BASE = 45548,
            OUTPUT = 46951,
            INPUT = 46948,
        }
    }
}

local SETTING_IDS = {
    BRONZE = { BAR = 1490, INTERFACE = 1 },
    IRON = { BAR = 1491, INTERFACE = 3 },
    STEEL = { BAR = 1492, INTERFACE = 5 },
    MITHRIL = { BAR = 1493, INTERFACE = 7 },
    ADAMANT = { BAR = 1494, INTERFACE = 9 },
    RUNE = { BAR = 1495, INTERFACE = 11 },
    ORIKALKUM = { BAR = 1496, INTERFACE = 13 },
    NECRONIUM = { BAR = 1497, INTERFACE = 15 },
    BANE = { BAR = 1498, INTERFACE = 17 },
    ELDER_RUNE = { BAR = 1499, INTERFACE = 19 },
}

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

local function selectItem(bar, choice)
    if not (API.VB_FindPSett(8332).state == SETTING_IDS[bar].BAR) then
        API.DoAction_Interface(0xffffffff, 0x93b, 1, 37, 52, SETTING_IDS[bar].INTERFACE,
            API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(800, 600, 600)
    end

    if not (API.VB_FindPSett(8329).state == 204800) then
        API.DoAction_Interface(0x24, 0xffffffff, 1, 37, 151, -1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(800, 600, 600)
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

local function openSmithingInterface()
    API.DoAction_Object1(0x29, 256, { ID.BURIAL.FORGE }, 50)
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
    end
end

local function bank(item)
    if type(item) == "number" then
        if API.BankOpen2() then
            if API.BankGetItemStack1(item) > 0 then
                if API.VB_FindPSett(8958).state ~= 7 then
                    API.DoAction_Interface(0x2e, 0xffffffff, 1, 517, 103, -1, API.OFF_ACT_GeneralInterface_route)
                    API.RandomSleep2(800, 500, 300)
                end
                if API.DoAction_Bank(item, 1, API.OFF_ACT_GeneralInterface_route) then
                    API.RandomSleep2(800, 500, 300)
                end
            else
                return false
            end
        else
            if API.DoAction_Object1(0x2e, 0, { ID.BURIAL.BANK_CHEST }, 50) then
                API.RandomSleep2(800, 500, 300)
            end
        end
    elseif type(item) == "table" then
        local itemCount = #item
        local slotsToWithdraw = math.floor(28 / itemCount)

        if API.BankOpen2() then
            for _, tableItem in ipairs(item) do
                for i = 1, slotsToWithdraw do
                    if API.BankGetItemStack1(tableItem) > 0 then
                        if API.VB_FindPSett(8958).state ~= 2 then
                            API.DoAction_Interface(0x2e, 0xffffffff, 1, 517, 93, -1, API.OFF_ACT_GeneralInterface_route)
                            API.RandomSleep2(800, 500, 300)
                        end
                        if API.DoAction_Bank(tableItem, 1, API.OFF_ACT_GeneralInterface_route) then
                            API.RandomSleep2(800, 500, 300)
                        end
                    else
                        if i == 1 then return false end
                        break
                    end
                end
            end
        else
            if API.DoAction_Object1(0x2e, 0, { ID.BURIAL.BANK_CHEST }, 50) then
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
    IGP.string_value = "BURIAL SMITHER LOADING..."
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

while API.Read_LoopyLoop() do
    if currentTaskIndex > #tasks then
        break
    end
    local currentTask = tasks[currentTaskIndex]

    e = e or 0
    API.DoRandomEvents()
    drawGUI()
    idleCheck()

    if API.ReadPlayerMovin2() then
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
        local selectedBarType = currentTask.metalType
        local selectedItemType = currentTask.itemType
        local choice = ITEMS[selectedBarType][selectedItemType]

        if choice then
            if not invContains(choice.INPUT) and hasUnfinishedItems() then
                if API.LocalPlayer_HoverProgress() <= 165 then
                    if API.LocalPlayer_HoverProgress() == 0 then
                        if e < 3 then
                            e = e + 1
                            goto continue
                        end
                        e = 0
                    end
                    if API.DoAction_Object1(0x3f, 0, { ID.BURIAL.FORGE }, 10) then
                        API.RandomSleep2(1800, 2000, 2200);
                        API.DoAction_Object1(0x3f, 0, { ID.BURIAL.ANVIL }, 50);
                        API.RandomSleep2(1800, 2000, 2200);
                    end
                else
                    if not API.CheckAnim(50) then
                        API.DoAction_Object1(0x3f, 0, { ID.BURIAL.ANVIL }, 50);
                        API.RandomSleep2(600, 800, 1000);
                    end
                end
            elseif invContains(choice.INPUT) then
                if isSmithingInterfaceOpen() then
                    if API.VB_FindPSett(8332).state == SETTING_IDS[selectedBarType].BAR and API.VB_FindPSett(8333).state == choice.BASE then
                        API.KeyboardPress2(0x20, 60, 100)
                        API.RandomSleep2(600, 800, 1200)
                    else
                        selectItem(selectedBarType, choice)
                        API.RandomSleep2(600, 300, 300)
                    end
                else
                    openSmithingInterface()
                end
            else
                if not bank(choice.INPUT) then
                    currentTaskIndex = currentTaskIndex + 1
                end
            end
        end
    end

    ::continue::
    printProgressReport()
    API.RandomSleep2(200, 200, 200)
end