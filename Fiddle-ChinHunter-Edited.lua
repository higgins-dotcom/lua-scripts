--[AUTHOR: Fiddle]--
--[V1.0.4]--
-- For red chins start the script near the church at Ooglog --
-- For azure chins start the script at the beginning of the area --

API = require('api')
startTime, afk = os.time(), os.time()


local Ccheck = API.ScriptDialogWindow2("What do you want to hunt?", { "chinchompa", "Red chinchompa", "Azure skillchompa" },
    "Start", "Close").Name

local shakingBox = 0;
local tileWPoints = {}
local hunterLvl = API.XPLevelTable(API.GetSkillXP("HUNTER"));

if Ccheck == "chinchompa" then
    shakingBox = 19189
    tileWPoints = {
        WPOINT.new(2350, 3535, 0), --1
        WPOINT.new(2349, 3535, 0), --2
        WPOINT.new(2351, 3535, 0), --3
    }
    if hunterLvl >= 80 then
        table.insert(tileWPoints, WPOINT.new(2505, 2899, 0))
        print("Hunter lvl is 80+ so 5 boxes")
    end
end
if Ccheck == "Red chinchompa" then
    shakingBox = 19190
    tileWPoints = {
        WPOINT.new(2504, 2898, 0), --1
        WPOINT.new(2504, 2900, 0), --2
        WPOINT.new(2506, 2898, 0), --3
        WPOINT.new(2506, 2900, 0)  --4
    }
    if hunterLvl >= 80 then
        table.insert(tileWPoints, WPOINT.new(2505, 2899, 0))
        print("Hunter lvl is 80+ so 5 boxes")
    end
end
if Ccheck == "Azure skillchompa" then
    shakingBox = 91232
    tileWPoints = {
        WPOINT.new(2728, 3857, 0),
        WPOINT.new(2728, 3859, 0),
        WPOINT.new(2730, 3857, 0),
        WPOINT.new(2730, 3859, 0)
    }
    if hunterLvl >= 80 then
        table.insert(tileWPoints, WPOINT.new(2729, 3858, 0))
        print("Hunter lvl is 80+ so 5 boxes")
    end
end

local function idleCheck()
    local timeDiff = os.difftime(os.time(), afk)
    local randomTime = math.random((5 * 60) * 0.6, (5 * 60) * 0.9)

    if timeDiff > randomTime then
        API.PIdle2()
        afk = os.time()
    end
end

local function getDistanceToTile(tile)
    local playerPos = API.PlayerCoordfloat()
    local dx = tile.x - playerPos.x
    local dy = tile.y - playerPos.y
    return math.sqrt(dx * dx + dy * dy)
end

local function sortTilesByDistance(tiles)
    local sortedTiles = {}
    for i, tile in ipairs(tiles) do
        table.insert(sortedTiles, {tile = tile, index = i, distance = getDistanceToTile(tile)})
    end
    
    table.sort(sortedTiles, function(a, b) return a.distance < b.distance end)
    return sortedTiles
end

local function placeBox(tile)
    API.RandomSleep2(600, 300, 300)
    if not API.CheckTileforObjects1(tile) then
        print("PLACING BOX")
        API.DoAction_Inventory3("Box trap", 0, 1, API.OFF_ACT_GeneralInterface_route)
        API.RandomSleep2(300, 300, 300)
        API.RandomSleep2(1800, 1200, 1200)
    end
end

local function initBox(tile)
    -- Check if we're already in range (within 2 tiles) to place the box
    if not API.PInAreaW(tile, 1) then
        print("Moving to tile to place box")
        API.DoAction_Tile(tile)
        API.RandomSleep2(800, 800, 800)
        API.WaitUntilMovingEnds(2, 2)
    else
        print("Already in range to place box")
    end
    placeBox(tile)
end

local function takeBox(objId, tile)
    print(tostring(tile))
    if not API.PInAreaW(tile, 1) then
        API.DoAction_Tile(tile)
        API.RandomSleep2(900, 300, 300)
        API.WaitUntilMovingEnds(2, 2)
    end
    API.DoAction_Object2(0x29, API.OFF_ACT_GeneralObject_route0, { objId }, 50, tile)
    API.RandomSleep2(1600, 1200, 300)
    -- placeBox(tile)
end

local function rebuildBox(objId, tile)
    API.DoAction_Object2(0x29, API.OFF_ACT_GeneralObject_route0, { objId }, 50, tile)
    API.RandomSleep2(1200, 300, 300)
    API.WaitUntilMovingEnds(2, 2)
    API.RandomSleep2(1200, 300, 300)
end

local function scanForBoxes()
    -- PRIORITY 1: Pick up ground items first
    local objs = API.ReadAllObjectsArray({ 3 }, { 19192, 10008 }, {})
    for _, obj in ipairs(objs) do
        if API.Read_LoopyLoop() == false then break end
        if obj.Id == 10008 then
            print("Ground item found:", obj.Id)
            API.DoAction_G_Items1(0x29, { obj.Id }, 20)
            API.RandomSleep2(1200, 800, 800)
            API.WaitUntilMovingEnds(2, 2)
            return -- Exit early to prioritize ground items
        end
    end

    -- PRIORITY 2: Shake boxes that have caught something (sorted by distance)
    local sortedTiles = sortTilesByDistance(tileWPoints)
    for _, tileData in ipairs(sortedTiles) do
        if API.Read_LoopyLoop() == false then break end
        local tile = tileData.tile
        local index = tileData.index
        if API.CheckTileforObjects2(tile, shakingBox, 1) then
            print("Shaking box found at tile", index, "distance:", tileData.distance)
            takeBox(shakingBox, tile)
            return -- Exit early to handle one shaking box at a time
        end
    end

    -- PRIORITY 3: Place new boxes or rebuild broken ones (sorted by distance)
    for _, tileData in ipairs(sortedTiles) do
        if API.Read_LoopyLoop() == false then break end
        local tile = tileData.tile
        local index = tileData.index
        if API.CheckTileforObjects2(tile, 19192, 1) then
            print("Broken box found at tile", index, "distance:", tileData.distance)
            rebuildBox(19192, tile)
            return -- Exit early to handle one action at a time
        elseif not API.CheckTileforObjects1(tile) then
            print("Empty tile found, placing box at tile", index, "distance:", tileData.distance)
            initBox(tile)
            return -- Exit early to handle one action at a time
        end
    end
end

local function shuffleTable(tbl)
    local rand = math.random
    local n = #tbl

    while n > 2 do
        local k = rand(n)
        tbl[n], tbl[k] = tbl[k], tbl[n]
        n = n - 1
    end

    return tbl
end

API.Write_fake_mouse_do(false)
TurnOffMrHasselhoff(false)

while API.Read_LoopyLoop() do
    idleCheck()

    if not API.ReadPlayerMovin2() and not API.CheckAnim(30) then
        scanForBoxes()
        shuffleTable(tileWPoints)
    end

    API.SetDrawTrackedSkills(true)
    API.RandomSleep2(300, 300, 300)
end
