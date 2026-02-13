--- @module 'NecroRitualsGUI'
--- @version 1.0.0
--- ImGui-based GUI for Necromancy Rituals script

local API = require("api")

local NecroGUI = {}

NecroGUI.open = true
NecroGUI.started = false
NecroGUI.paused = false
NecroGUI.stopped = false
NecroGUI.cancelled = false
NecroGUI.selectConfigTab = true
NecroGUI.selectInfoTab = false

NecroGUI.config = {
    maxIdleTime = 5,
    disturbancesEnabled = true,
    autoRun = false,
    handleMoth = true,
    handleWanderingSoul = true,
    handleShamblingHorror = true,
    handleSparkingGlyph = true,
    handleCorruptGlyphs = true,
    handleSoulStorm = true,
    handleDefile = true,
}

local SCRIPT_DIR = ""
local CONFIG_DIR = ""

local function getCharacterName()
    local playerName = API.GetLocalPlayerName()
    if playerName then
        return playerName
    end
    return "default"
end

local CHARACTER_NAME = getCharacterName()
local CONFIG_PATH = CONFIG_DIR .. "necrorituals-" .. CHARACTER_NAME .. ".config.json"

local NECRO = {
    dark = { 0.08, 0.05, 0.12 },
    medium = { 0.15, 0.08, 0.20 },
    light = { 0.25, 0.12, 0.35 },
    bright = { 0.45, 0.20, 0.55 },
    glow = { 0.65, 0.30, 0.80 },
    accent = { 0.30, 0.70, 0.40 },
}

local function loadConfigFromFile()
    local file = io.open(CONFIG_PATH, "r")
    if not file then return nil end
    local content = file:read("*a")
    file:close()
    if not content or content == "" then return nil end
    local ok, data = pcall(API.JsonDecode, content)
    if not ok or not data then return nil end
    return data
end

local function saveConfigToFile(cfg)
    local data = {
        MaxIdleTime = cfg.maxIdleTime,
        DisturbancesEnabled = cfg.disturbancesEnabled,
        AutoRun = cfg.autoRun,
        HandleMoth = cfg.handleMoth,
        HandleWanderingSoul = cfg.handleWanderingSoul,
        HandleShamblingHorror = cfg.handleShamblingHorror,
        HandleSparkingGlyph = cfg.handleSparkingGlyph,
        HandleCorruptGlyphs = cfg.handleCorruptGlyphs,
        HandleSoulStorm = cfg.handleSoulStorm,
        HandleDefile = cfg.handleDefile,
    }
    local ok, json = pcall(API.JsonEncode, data)
    if not ok or not json then
        return
    end
    local file = io.open(CONFIG_PATH, "w")
    if not file then
        return
    end
    file:write(json)
    file:close()
end

function NecroGUI.updateSharedConfig()
    saveConfigToFile(NecroGUI.config)
end

function NecroGUI.getConfig()
    return NecroGUI.config
end

function NecroGUI.reset()
    NecroGUI.open = true
    NecroGUI.started = false
    NecroGUI.paused = false
    NecroGUI.stopped = false
    NecroGUI.cancelled = false
    NecroGUI.selectConfigTab = true
    NecroGUI.selectInfoTab = false
end

function NecroGUI.loadConfig()
    local saved = loadConfigFromFile()
    if not saved then return end
    
    local c = NecroGUI.config
    if type(saved.MaxIdleTime) == "number" then c.maxIdleTime = saved.MaxIdleTime end
    if type(saved.DisturbancesEnabled) == "boolean" then c.disturbancesEnabled = saved.DisturbancesEnabled end
    if type(saved.AutoRun) == "boolean" then c.autoRun = saved.AutoRun end
    if type(saved.HandleMoth) == "boolean" then c.handleMoth = saved.HandleMoth end
    if type(saved.HandleWanderingSoul) == "boolean" then c.handleWanderingSoul = saved.HandleWanderingSoul end
    if type(saved.HandleShamblingHorror) == "boolean" then c.handleShamblingHorror = saved.HandleShamblingHorror end
    if type(saved.HandleSparkingGlyph) == "boolean" then c.handleSparkingGlyph = saved.HandleSparkingGlyph end
    if type(saved.HandleCorruptGlyphs) == "boolean" then c.handleCorruptGlyphs = saved.HandleCorruptGlyphs end
    if type(saved.HandleSoulStorm) == "boolean" then c.handleSoulStorm = saved.HandleSoulStorm end
    if type(saved.HandleDefile) == "boolean" then c.handleDefile = saved.HandleDefile end
end

function NecroGUI.getConfig()
    return NecroGUI.config
end

function NecroGUI.isPaused()
    return NecroGUI.paused
end

function NecroGUI.isStopped()
    return NecroGUI.stopped
end

function NecroGUI.isCancelled()
    return NecroGUI.cancelled
end

function NecroGUI.setScriptDirectory(dir)
    SCRIPT_DIR = dir
    CONFIG_DIR = SCRIPT_DIR .. "configs/"
    CHARACTER_NAME = getCharacterName()
    CONFIG_PATH = CONFIG_DIR .. "necrorituals-" .. CHARACTER_NAME .. ".config.json"
end

local function row(label, value, lr, lg, lb, vr, vg, vb)
    ImGui.TableNextRow()
    ImGui.TableNextColumn()
    ImGui.PushStyleColor(ImGuiCol.Text, lr or 1.0, lg or 1.0, lb or 1.0, 1.0)
    ImGui.TextWrapped(label)
    ImGui.PopStyleColor(1)
    ImGui.TableNextColumn()
    if vr then
        ImGui.PushStyleColor(ImGuiCol.Text, vr, vg, vb, 1.0)
        ImGui.TextWrapped(value)
        ImGui.PopStyleColor(1)
    else
        ImGui.TextWrapped(value)
    end
end

local function sectionHeader(text)
    ImGui.PushStyleColor(ImGuiCol.Text, NECRO.glow[1], NECRO.glow[2], NECRO.glow[3], 1.0)
    ImGui.TextWrapped(text)
    ImGui.PopStyleColor(1)
end

local function flavorText(text)
    ImGui.PushStyleColor(ImGuiCol.Text, 0.55, 0.45, 0.65, 1.0)
    ImGui.TextWrapped(text)
    ImGui.PopStyleColor(1)
end

local function drawConfigTab(cfg, gui)
    if gui.started then
        local statusText = gui.paused and "PAUSED" or "Running"
        local statusColor = gui.paused and { 1.0, 0.8, 0.2 } or { 0.4, 0.8, 0.4 }
        ImGui.PushStyleColor(ImGuiCol.Text, statusColor[1], statusColor[2], statusColor[3], 1.0)
        ImGui.TextWrapped(statusText)
        ImGui.PopStyleColor(1)
        ImGui.Spacing()
        ImGui.Separator()

        if ImGui.BeginTable("##cfgsummary", 2) then
            ImGui.TableSetupColumn("Label", ImGuiTableColumnFlags.WidthStretch, 0.4)
            ImGui.TableSetupColumn("Value", ImGuiTableColumnFlags.WidthStretch, 0.6)
            row("Max Idle Time:", cfg.maxIdleTime .. " minutes")
            row("Disturbances:", cfg.disturbancesEnabled and "Enabled" or "Disabled")
            ImGui.EndTable()
        end

        ImGui.Spacing()
        ImGui.Separator()
        ImGui.Spacing()

        if gui.paused then
            ImGui.PushStyleColor(ImGuiCol.Button, 0.15, 0.35, 0.20, 0.9)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.20, 0.45, 0.25, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.10, 0.50, 0.15, 1.0)
            if ImGui.Button("Resume Script##resume", -1, 28) then
                gui.paused = false
            end
            ImGui.PopStyleColor(3)
        else
            ImGui.PushStyleColor(ImGuiCol.Button, 0.25, 0.15, 0.30, 0.9)
            ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.35, 0.20, 0.40, 1.0)
            ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.45, 0.25, 0.50, 1.0)
            if ImGui.Button("Pause Script##pause", -1, 28) then
                gui.paused = true
            end
            ImGui.PopStyleColor(3)
        end

        ImGui.Spacing()

        ImGui.PushStyleColor(ImGuiCol.Button, 0.5, 0.15, 0.15, 0.9)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.6, 0.2, 0.2, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.7, 0.25, 0.25, 1.0)
        if ImGui.Button("Stop Script##stop", -1, 28) then
            gui.stopped = true
        end
        ImGui.PopStyleColor(3)
        return
    end

    ImGui.PushItemWidth(-1)

    sectionHeader("Auto Run")
    ImGui.Spacing()
    
    local autoRunChanged, newAutoRun = ImGui.Checkbox("Auto Run", cfg.autoRun)
    if autoRunChanged then
        cfg.autoRun = newAutoRun
    end
    ImGui.PushStyleColor(ImGuiCol.Text, NECRO.bright[1], NECRO.bright[2], NECRO.bright[3], 1.0)
    ImGui.TextWrapped("When enabled, script will start automatically without clicking Start.")
    ImGui.PopStyleColor(1)
    
    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    sectionHeader("Idle Settings")
    flavorText("Configure maximum idle time (minutes) before AFK check.")
    ImGui.Spacing()
    
    local idleTime = cfg.maxIdleTime
    local changed, newIdle = ImGui.SliderInt("##idleTime", idleTime, 5, 15)
    if changed then
        cfg.maxIdleTime = newIdle
    end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    sectionHeader("Disturbance Handling")
    flavorText("Toggle which disturbances the script will handle.")
    ImGui.Spacing()

    local distEnabled = cfg.disturbancesEnabled
    local distChanged, newDistEnabled = ImGui.Checkbox("Enable Disturbances##distToggle", distEnabled)
    if distChanged then
        cfg.disturbancesEnabled = newDistEnabled
    end
    ImGui.PushStyleColor(ImGuiCol.Text, NECRO.bright[1], NECRO.bright[2], NECRO.bright[3], 1.0)
    ImGui.TextWrapped("When enabled, the script will automatically handle random disturbances.")
    ImGui.PopStyleColor(1)
    
    ImGui.Spacing()
    
    if cfg.disturbancesEnabled then
        if ImGui.BeginTable("##disturbances", 2) then
            ImGui.TableSetupColumn("Disturbance", ImGuiTableColumnFlags.WidthStretch, 0.6)
            ImGui.TableSetupColumn("Enabled", ImGuiTableColumnFlags.WidthStretch, 0.4)
            
            local dists = {
                { key = "handleMoth", name = "Moth" },
                { key = "handleWanderingSoul", name = "Wandering Soul" },
                { key = "handleShamblingHorror", name = "Shambling Horror" },
                { key = "handleSparkingGlyph", name = "Sparking Glyph" },
                { key = "handleCorruptGlyphs", name = "Corrupt Glyphs" },
                { key = "handleSoulStorm", name = "Soul Storm" },
                { key = "handleDefile", name = "Defile" },
            }
            
            for _, dist in ipairs(dists) do
                ImGui.TableNextRow()
                ImGui.TableNextColumn()
                ImGui.PushStyleColor(ImGuiCol.Text, 0.8, 0.8, 0.8, 1.0)
                ImGui.TextWrapped(dist.name)
                ImGui.PopStyleColor(1)
                ImGui.TableNextColumn()
                
                local currentVal = cfg[dist.key]
                local checkboxLabel = "##" .. dist.key
                local cbChanged, newVal = ImGui.Checkbox(checkboxLabel, currentVal)
                if cbChanged then
                    cfg[dist.key] = newVal
                end
            end
            
            ImGui.EndTable()
        end
    end

    ImGui.PopItemWidth()

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    ImGui.PushStyleColor(ImGuiCol.Button, 0.35, 0.15, 0.45, 0.9)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.45, 0.20, 0.55, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.55, 0.25, 0.65, 1.0)
    if ImGui.Button("Start Ritual##start", -1, 32) then
        NecroGUI.updateSharedConfig()
        gui.started = true
    end
    ImGui.PopStyleColor(3)

    ImGui.Spacing()

    ImGui.PushStyleColor(ImGuiCol.Button, 0.4, 0.4, 0.4, 0.2)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.4, 0.4, 0.4, 0.35)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.5, 0.5, 0.5, 0.5)
    if ImGui.Button("Cancel##cancel", -1, 28) then
        gui.cancelled = true
    end
    ImGui.PopStyleColor(3)
end

local function drawInfoTab(cfg)
    local statusText = NecroGUI.paused and "PAUSED" or "Running"
    local statusColor = NecroGUI.paused and { 1.0, 0.8, 0.2 } or { 0.4, 0.8, 0.4 }
    ImGui.PushStyleColor(ImGuiCol.Text, statusColor[1], statusColor[2], statusColor[3], 1.0)
    ImGui.TextWrapped(statusText)
    ImGui.PopStyleColor(1)

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    sectionHeader("Current Settings")
    ImGui.Spacing()
    
    if ImGui.BeginTable("##currsettings", 2) then
        ImGui.TableSetupColumn("Setting", ImGuiTableColumnFlags.WidthStretch, 0.5)
        ImGui.TableSetupColumn("Value", ImGuiTableColumnFlags.WidthStretch, 0.5)
        
        row("Max Idle Time", cfg.maxIdleTime .. " minutes")
        row("Disturbances", cfg.disturbancesEnabled and "Enabled" or "Disabled")
        
        if cfg.disturbancesEnabled then
            row("Moth", cfg.handleMoth and "Yes" or "No")
            row("Wandering Soul", cfg.handleWanderingSoul and "Yes" or "No")
            row("Shambling Horror", cfg.handleShamblingHorror and "Yes" or "No")
            row("Sparking Glyph", cfg.handleSparkingGlyph and "Yes" or "No")
            row("Corrupt Glyphs", cfg.handleCorruptGlyphs and "Yes" or "No")
            row("Soul Storm", cfg.handleSoulStorm and "Yes" or "No")
            row("Defile", cfg.handleDefile and "Yes" or "No")
        end
        
        ImGui.EndTable()
    end

    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()

    if NecroGUI.paused then
        ImGui.PushStyleColor(ImGuiCol.Button, 0.15, 0.35, 0.20, 0.9)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.20, 0.45, 0.25, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.10, 0.50, 0.15, 1.0)
        if ImGui.Button("Resume Script##resume", -1, 28) then
            NecroGUI.paused = false
        end
        ImGui.PopStyleColor(3)
    else
        ImGui.PushStyleColor(ImGuiCol.Button, 0.25, 0.15, 0.30, 0.9)
        ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.35, 0.20, 0.40, 1.0)
        ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.45, 0.25, 0.50, 1.0)
        if ImGui.Button("Pause Script##pause", -1, 28) then
            NecroGUI.paused = true
        end
        ImGui.PopStyleColor(3)
    end

    ImGui.Spacing()

    ImGui.PushStyleColor(ImGuiCol.Button, 0.5, 0.15, 0.15, 0.9)
    ImGui.PushStyleColor(ImGuiCol.ButtonHovered, 0.6, 0.2, 0.2, 1.0)
    ImGui.PushStyleColor(ImGuiCol.ButtonActive, 0.7, 0.25, 0.25, 1.0)
    if ImGui.Button("Stop Script##stop", -1, 28) then
        NecroGUI.stopped = true
    end
    ImGui.PopStyleColor(3)
end

local function drawContent(data, gui)
    local currentState = data.state or "Idle"
    local statusColor = NECRO.glow
    if currentState == "Paused" then
        statusColor = { 1.0, 0.8, 0.2 }
    elseif currentState == "Handling Disturbance" then
        statusColor = { 0.8, 0.4, 0.2 }
    elseif currentState == "Repairing Glyphs" then
        statusColor = { 0.3, 0.8, 0.4 }
    end
    
    ImGui.PushStyleColor(ImGuiCol.Text, statusColor[1], statusColor[2], statusColor[3], 1.0)
    ImGui.TextWrapped("Status: " .. currentState)
    ImGui.PopStyleColor(1)
    ImGui.Spacing()
    ImGui.Separator()
    ImGui.Spacing()
    
    if ImGui.BeginTabBar("##maintabs", 0) then
        local configFlags = gui.selectConfigTab and ImGuiTabItemFlags.SetSelected or 0
        gui.selectConfigTab = false

        if ImGui.BeginTabItem("Config###config", nil, configFlags) then
            ImGui.Spacing()
            drawConfigTab(gui.config, gui)
            ImGui.EndTabItem()
        end

        if gui.started then
            local infoFlags = gui.selectInfoTab and ImGuiTabItemFlags.SetSelected or 0
            gui.selectInfoTab = false
            if ImGui.BeginTabItem("Info###info", nil, infoFlags) then
                ImGui.Spacing()
                drawInfoTab(gui.config)
                ImGui.EndTabItem()
            end
        end

        ImGui.EndTabBar()
    end
end

function NecroGUI.draw(data)
    data = data or {}
    ImGui.SetNextWindowSize(480, 0, ImGuiCond.Always)
    ImGui.SetNextWindowPos(100, 100, ImGuiCond.FirstUseEver)

    ImGui.PushStyleColor(ImGuiCol.WindowBg, NECRO.dark[1], NECRO.dark[2], NECRO.dark[3], 0.97)
    ImGui.PushStyleColor(ImGuiCol.TitleBg, NECRO.medium[1] * 0.6, NECRO.medium[2] * 0.6, NECRO.medium[3] * 0.6, 1.0)
    ImGui.PushStyleColor(ImGuiCol.TitleBgActive, NECRO.medium[1], NECRO.medium[2], NECRO.medium[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Separator, NECRO.light[1], NECRO.light[2], NECRO.light[3], 0.4)
    ImGui.PushStyleColor(ImGuiCol.Tab, NECRO.medium[1], NECRO.medium[2], NECRO.medium[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.ImGuiCol_TabActive, NECRO.medium[1], NECRO.medium[2], NECRO.medium[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.TabHovered, NECRO.light[1], NECRO.light[2], NECRO.light[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.TabActive, NECRO.bright[1], NECRO.bright[2], NECRO.bright[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.FrameBg, NECRO.medium[1] * 0.5, NECRO.medium[2] * 0.5, NECRO.medium[3] * 0.5, 0.9)
    ImGui.PushStyleColor(ImGuiCol.FrameBgHovered, NECRO.light[1] * 0.7, NECRO.light[2] * 0.7, NECRO.light[3] * 0.7, 1.0)
    ImGui.PushStyleColor(ImGuiCol.FrameBgActive, NECRO.bright[1] * 0.5, NECRO.bright[2] * 0.5, NECRO.bright[3] * 0.5, 1.0)
    ImGui.PushStyleColor(ImGuiCol.SliderGrab, NECRO.bright[1], NECRO.bright[2], NECRO.bright[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.SliderGrabActive, NECRO.glow[1], NECRO.glow[2], NECRO.glow[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.CheckMark, NECRO.glow[1], NECRO.glow[2], NECRO.glow[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Header, NECRO.medium[1], NECRO.medium[2], NECRO.medium[3], 0.8)
    ImGui.PushStyleColor(ImGuiCol.HeaderHovered, NECRO.light[1], NECRO.light[2], NECRO.light[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.HeaderActive, NECRO.bright[1], NECRO.bright[2], NECRO.bright[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 1.0, 1.0, 1.0)

    ImGui.PushStyleVar(ImGuiStyleVar.WindowPadding, 14, 10)
    ImGui.PushStyleVar(ImGuiStyleVar.ItemSpacing, 6, 4)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 4)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 6)
    ImGui.PushStyleVar(ImGuiStyleVar.TabRounding, 4)

    local titleText = "Necromancy Rituals###NecroGUI"
    local visible = ImGui.Begin(titleText, true)

    if visible then
        local ok, err = pcall(drawContent, data, NecroGUI)
        if not ok then
            ImGui.TextColored(1.0, 0.3, 0.3, 1.0, "Error: " .. tostring(err))
        end
    end

    ImGui.PopStyleVar(5)
    ImGui.PopStyleColor(18)
    ImGui.End()

    return NecroGUI.open
end

return NecroGUI
