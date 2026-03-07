--[[
# Script Name:   Harp Tuner
# Description:  Tunes harmonium harps at the Ithell Clan district of Prifddinas
# Author:        Higgins <discord@higginshax>
# Version:       1.2
# Date:          2024.01.01
--]]

local MAX_IDLE_TIME_MINUTES = 5
local API = require("api")

local SKILLS = { "CRAFTING", "CONSTRUCTION" }
local startXp = {
    CRAFTING = API.GetSkillXP("CRAFTING"),
    CONSTRUCTION = API.GetSkillXP("CONSTRUCTION")
}
local startTime = os.time()

local ID = {
    HARMONIC_DUST = 32622,
    HARP = { 94059, 94060 },
}

local startDust = Inventory:GetItemAmount(ID.HARMONIC_DUST)

local COLORS = {
    dark = { 0.06, 0.04, 0.10 },
    medium = { 0.12, 0.06, 0.18 },
    crafting = { 0.90, 0.55, 0.15 },
    construction = { 0.55, 0.35, 0.20 },
    text = { 0.85, 0.85, 0.90 },
    accent = { 0.65, 0.30, 0.80 },
}

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

local function formatElapsedTime(start)
    local elapsed = os.time() - start
    local hours = math.floor(elapsed / 3600)
    local minutes = math.floor((elapsed % 3600) / 60)
    local seconds = elapsed % 60
    return string.format("%02d:%02d:%02d", hours, minutes, seconds)
end

local function calcProgressPercentage(skill)
    local currentExp = API.GetSkillXP(skill)
    local currentLevel = API.XPLevelTable(currentExp)
    if currentLevel >= 120 then return 100 end
    local nextLevelExp = XPForLevel(currentLevel + 1)
    local currentLevelExp = XPForLevel(currentLevel)
    return math.floor((currentExp - currentLevelExp) / (nextLevelExp - currentLevelExp) * 100)
end

local function drawProgressBar(skill, progress, color, currentLevel, diffXp, xpPH)
    local barHeight = 22
    
    ImGui.PushStyleColor(ImGuiCol.Text, color[1], color[2], color[3], 1.0)
    ImGui.TextWrapped(skill:gsub("^%l", string.upper))
    ImGui.PopStyleColor(1)
    
    local label = string.format("Lvl %d | %d%% | XP: %s | XP/H: %s",
        currentLevel,
        progress,
        formatNumber(diffXp),
        formatNumber(xpPH)
    )
    
    ImGui.PushStyleColor(ImGuiCol.PlotHistogram, color[1], color[2], color[3], 0.75)
    ImGui.PushStyleColor(ImGuiCol.Text, 1.0, 1.0, 1.0, 1.0)
    ImGui.ProgressBar(progress / 100, -1, barHeight, label)
    ImGui.PopStyleColor(2)
    ImGui.Spacing()
end

local function drawGUI()
    local elapsedMinutes = (os.time() - startTime) / 60
    if elapsedMinutes < 0.01 then elapsedMinutes = 0.01 end
    
    ImGui.SetNextWindowSize(500, 0, ImGuiCond.Always)
    ImGui.SetNextWindowPos(100, 100, ImGuiCond.FirstUseEver)
    
    ImGui.PushStyleColor(ImGuiCol.WindowBg, COLORS.dark[1], COLORS.dark[2], COLORS.dark[3], 0.95)
    ImGui.PushStyleColor(ImGuiCol.TitleBg, COLORS.medium[1], COLORS.medium[2], COLORS.medium[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.TitleBgActive, COLORS.medium[1], COLORS.medium[2], COLORS.medium[3], 1.0)
    ImGui.PushStyleColor(ImGuiCol.Text, COLORS.text[1], COLORS.text[2], COLORS.text[3], 1.0)
    ImGui.PushStyleVar(ImGuiStyleVar.WindowRounding, 6)
    ImGui.PushStyleVar(ImGuiStyleVar.FrameRounding, 4)
    
    local visible = ImGui.Begin("Harp Tuner###HarpGUI", true)
    
    if visible then
        ImGui.PushStyleColor(ImGuiCol.Text, COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1.0)
        ImGui.TextWrapped("Time: " .. formatElapsedTime(startTime))
        ImGui.PopStyleColor(1)
        ImGui.Separator()
        ImGui.Spacing()
        
        for _, skill in ipairs(SKILLS) do
            local currentXp = API.GetSkillXP(skill)
            local diffXp = math.abs(currentXp - startXp[skill])
            local xpPH = round((diffXp * 60) / elapsedMinutes)
            local currentLevel = API.XPLevelTable(currentXp)
            local progress = calcProgressPercentage(skill)
            local color = skill == "CRAFTING" and COLORS.crafting or COLORS.construction
            
            drawProgressBar(skill, progress, color, currentLevel, diffXp, xpPH)
        end
        
        ImGui.Separator()
        ImGui.Spacing()
        
        local dust = Inventory:GetItemAmount(ID.HARMONIC_DUST) - startDust
        local dustPH = round((dust * 60) / elapsedMinutes)
        
        ImGui.PushStyleColor(ImGuiCol.Text, COLORS.accent[1], COLORS.accent[2], COLORS.accent[3], 1.0)
        ImGui.TextWrapped("Harmonic Dust")
        ImGui.PopStyleColor(1)
        ImGui.PushStyleColor(ImGuiCol.Text, COLORS.text[1], COLORS.text[2], COLORS.text[3], 1.0)
        ImGui.TextWrapped(string.format("  Gained: %s  |  Per Hour: %s", formatNumber(dust), formatNumber(dustPH)))
        ImGui.PopStyleColor(1)
    end
    
    ImGui.PopStyleVar(2)
    ImGui.PopStyleColor(4)
    ImGui.End()
end

API.SetMaxIdleTime(MAX_IDLE_TIME_MINUTES)

ClearRender()
DrawImGui(drawGUI)

while API.Read_LoopyLoop() do
    local anim = API.ReadPlayerAnim()
    if (anim ~= 25021 and anim ~= 25026) or GetVarbitValue(25951) >= 3 then
        Interact:Object("Harp", "Tune")
        API.RandomSleep2(1800, 800, 800)
    end
    API.RandomSleep2(500, 500, 500)
end