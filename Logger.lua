local json = require('lib.json.json')
local LOGGER = {}

local function logToFile(char, text)
    local userProfile = os.getenv("USERPROFILE")
    local filename = userProfile .. "\\Documents\\MemoryError\\Logger\\" .. char .. ".txt"
    local file2 = io.open(filename, "a")

    if file2 then
        file2:write(os.date("%Y-%m-%d %H:%M:%S") .. " - " .. text .. "\n")
        file2:close()
    end
end

local function logToJson(char, fieldName, value)
    local userProfile = os.getenv("USERPROFILE")
    local filename = userProfile .. "\\Documents\\MemoryError\\Logger\\" .. char .. ".json"
    local file = io.open(filename, "r")

    local data = {}

    if file then
        local contents = file:read("*a")
        file:close()

        data = json.decode(contents)

        if fieldName ~= "lastCheckedTimestamp" and data[fieldName] then
            data[fieldName] = data[fieldName] + value
        else
            data[fieldName] = value
        end
    else
        data[fieldName] = value
    end

    file = io.open(filename, "w")
    if file then
        local encodedData = json.encode(data)
        file:write(encodedData)
        file:close()
    end
end

local function init(char)
    local userProfile = os.getenv("USERPROFILE")
    local filename = userProfile .. "\\Documents\\MemoryError\\Logger\\" .. char .. ".json"
    local file = io.open(filename, "r")

    local data = {}

    if file then
        local contents = file:read("*a")
        file:close()

        data = json.decode(contents)
        if data["lastCheckedTimestamp"] then
            lastCheckedTimestamp = data["lastCheckedTimestamp"]
        else
            lastCheckedTimestamp = 0
        end    
    else
        lastCheckedTimestamp = 0
    end
end

function LOGGER.watch()
    local char = GetLocalPlayerName()
    init(char)
    local chatTexts = ChatGetMessages()
    local timestamp = 0
    if chatTexts then
        for k, v in pairs(chatTexts) do

            local message = tostring(v.text)
            if string.find(message, "Pumpkin gifts you") then
                local hour, min, sec = string.match(message, "(%d+):(%d+):(%d+)")
                local currentDate = os.date("*t")
                currentDate.hour, currentDate.min, currentDate.sec = tonumber(hour), tonumber(min), tonumber(sec)
                timestamp = os.time(currentDate)
                if timestamp > lastCheckedTimestamp then
                    local quantity, itemName = string.match(message, ":(%s*%d+)%s*x%s*([^:]+)")
                    if quantity and itemName then
                        quantity = quantity:gsub("%s+", "")
                        itemName = itemName:gsub("^%s*(.-)%s*$", "%1")
                        logToFile(char, message)
                        logToJson(char, itemName, tonumber(quantity))
                    end
                end
            end
        end
        lastCheckedTimestamp = timestamp
        logToJson(char, "lastCheckedTimestamp", os.time())
    end
    return false
end

return LOGGER