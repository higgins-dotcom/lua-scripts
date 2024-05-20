API = require('API')

API.SetDrawTrackedSkills(true)
SetMaxIdleTime(10)

local ID = {
    OBJ = {
        FRUIT_TREE_PATCH = 8047
    },
    ITEM = {
        POTION = { 44022, 44024, 44026 },
        SAPLING = { 48705, 48707, 48709, 48763 }
    }
}

local function invContains(item)
    if type(item) == "number" then
        return API.InvItemFound1(item)
    elseif type(item) == "table" then
        local items = API.InvItemcount_2(item)
        for _, v in ipairs(items) do
            if v > 0 then
                return true
            end
        end
        return false
    else
        local items = API.ReadInvArrays33()
        for k, v in pairs(items) do
            if v.itemid1 > 0 then
                if v.textitem == item then
                    return true
                end
            end
        end
    end
    return false
end

local function hasPotions()
    return invContains(ID.ITEM.POTION)
end

local function hasSaplings()
    return invContains(ID.ITEM.SAPLING)
end

local function findPatch()
    local objs = API.ReadAllObjectsArray({ 0 }, { -1 }, {})
    for _, obj in pairs(objs) do
        -- if obj.Id > 0 and obj.CalcX == 2218 and obj.CalcY == 3435 then -- priff
        if obj.Id > 0 and obj.CalcX == 3343 and obj.CalcY == 3205 then -- hets cactus
            return obj
        end
    end
    return false
end

local function checkTree(tree)
    if tree.Action == "Rake" or tree.Action == "Check-health" or tree.Action == "Pick-fruit" or tree.Action == "Pick" then
        if tree.Action == "Check-health" then
            API.RandomSleep2(400, 400, 400)
        end
        API.DoAction_Object_Direct(0x29, API.OFF_ACT_GeneralObject_route0, tree)
    elseif tree.Action == "Harvest" or tree.Action == "Clear" or tree.Id == 114427 then
        API.DoAction_Object_Direct(0x29, API.OFF_ACT_GeneralObject_route2, tree)
    elseif tree.Action == "Chop-down" then
        API.DoAction_Object_Direct(0x3B, API.OFF_ACT_GeneralObject_route0, tree)
    elseif tree.Action == "Inspect" then
        return true
    end
    API.RandomSleep2(600, 600, 400)
    return false
end

while API.Read_LoopyLoop() do

    if API.ReadPlayerMovin2() or API.CheckAnim(35) then
        goto continue
    end

    if API.Select_Option("Yes, I want to clear it for new crops.") then
        API.RandomSleep2(300, 300, 300)
        goto continue
    end

    if hasPotions() and hasSaplings() then
        local patch = findPatch()
        if patch then
            if not string.find(patch.Name, "cactus") and checkTree(patch) then
                API.DoAction_Inventory2(ID.ITEM.SAPLING, 1, 0, API.OFF_ACT_Bladed_interface_route)
                API.RandomSleep2(400, 600, 600)
                API.DoAction_Object_Direct(0x24, API.OFF_ACT_GeneralObject_route00, patch)
                API.RandomSleep2(400, 600, 600)
            elseif checkTree(patch) then
                API.DoAction_Inventory2(ID.ITEM.POTION, 1, 0, API.OFF_ACT_Bladed_interface_route)
                API.RandomSleep2(400, 600, 600)
                API.DoAction_Object_Direct(0x24, API.OFF_ACT_GeneralObject_route00, patch)
                API.RandomSleep2(400, 600, 600)
            end
        end
    end

    ::continue::
    API.RandomSleep2(200, 200, 200)
end
