-- Horizontal special-resource pips for the player's Blizzard group frame.
-- Discovery and rendering are intentionally separate from the absorb pipeline.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local CreateFrame = CreateFrame
local UnitClass = UnitClass
local C_Timer = C_Timer
local Enum = Enum
local UnitIsUnit = UnitIsUnit
local math_min = math.min
local type = type
local InCombatLockdown = InCombatLockdown

local _, playerClass = UnitClass("player")
local powerTypes = Enum and Enum.PowerType
local resourceProvider = addon.GetSpecialResourceProvider(
    playerClass, powerTypes
)

if not resourceProvider then return end

-- Fixed dimensions and a neutral bar texture for resource pips.
local MAX_PIPS = 7
local PIP_WIDTH = 12
local PIP_HEIGHT = 6
local pipWidth = PIP_WIDTH
local pipHeight = PIP_HEIGHT
local PIP_GAP = 3
local PIP_TEXTURE = "Interface\\Buttons\\WHITE8x8"

local overlay
local pips = {}
local progress = {}
local pipOrder = {}
local currentBar = nil
local enabled = true
local refreshScheduled = false
local eventFrame

local COMPACT_FRAME_NAMES = {}
local compactFrameNameCount = 0

for index = 1, 40 do
    compactFrameNameCount = compactFrameNameCount + 1
    COMPACT_FRAME_NAMES[compactFrameNameCount] = "CompactRaidFrame" .. index
    compactFrameNameCount = compactFrameNameCount + 1
    COMPACT_FRAME_NAMES[compactFrameNameCount] = "CompactPartyFrameMemberFrame" .. index
    compactFrameNameCount = compactFrameNameCount + 1
    COMPACT_FRAME_NAMES[compactFrameNameCount] = "PartyMemberFrame" .. index
end

local function IsForbidden(frame)
    return not frame or (frame.IsForbidden and frame:IsForbidden())
end

local function IsStatusBar(frame)
    return not IsForbidden(frame)
        and frame.GetObjectType and frame:GetObjectType() == "StatusBar"
end

local function IsResourceStatusBar(child)
    if not IsStatusBar(child) then return false end
    local name = child.GetName and child:GetName() or ""
    return name == "" or name:find("Power", 1, true)
        or name:find("Mana", 1, true) or name:find("Resource", 1, true)
end

local function GetUnit(frame)
    if IsForbidden(frame) then return nil end
    if type(frame.displayedUnit) == "string" and frame.displayedUnit ~= "" then
        return frame.displayedUnit
    end
    if type(frame.unit) == "string" and frame.unit ~= "" then
        return frame.unit
    end
    if frame.GetAttribute then
        local unit = frame:GetAttribute("unit")
        if type(unit) == "string" and unit ~= "" then return unit end
    end
    return nil
end

local function IsPlayerUnit(frame)
    local unit = GetUnit(frame)
    if not unit then return false end
    if unit == "player" then return true end
    return UnitIsUnit and UnitIsUnit(unit, "player") or false
end

local function GetResourceBar(frame)
    if IsForbidden(frame) then return nil end

    local bar = frame.powerBar
    if IsStatusBar(bar) then return bar end
    bar = frame.PowerBar
    if IsStatusBar(bar) then return bar end
    bar = frame.powerbar
    if IsStatusBar(bar) then return bar end
    bar = frame.manaBar
    if IsStatusBar(bar) then return bar end
    bar = frame.ManaBar
    if IsStatusBar(bar) then return bar end
    bar = frame.manabar
    if IsStatusBar(bar) then return bar end
    bar = frame.resourceBar
    if IsStatusBar(bar) then return bar end
    bar = frame.ResourceBar
    if IsStatusBar(bar) then return bar end
    bar = frame.classPowerBar
    if IsStatusBar(bar) then return bar end

    if frame.GetChildren then
        -- Inspect the first 12 direct children; deeper traversal belongs to
        -- FindPlayerFrame, which applies the bounded hierarchy scan.
        local child1, child2, child3, child4, child5, child6,
            child7, child8, child9, child10, child11, child12 = frame:GetChildren()
        if IsResourceStatusBar(child1) then return child1 end
        if IsResourceStatusBar(child2) then return child2 end
        if IsResourceStatusBar(child3) then return child3 end
        if IsResourceStatusBar(child4) then return child4 end
        if IsResourceStatusBar(child5) then return child5 end
        if IsResourceStatusBar(child6) then return child6 end
        if IsResourceStatusBar(child7) then return child7 end
        if IsResourceStatusBar(child8) then return child8 end
        if IsResourceStatusBar(child9) then return child9 end
        if IsResourceStatusBar(child10) then return child10 end
        if IsResourceStatusBar(child11) then return child11 end
        if IsResourceStatusBar(child12) then return child12 end
    end

    return nil
end

local function FindPlayerFrame(frame, depth)
    if IsForbidden(frame) then return nil end
    if IsPlayerUnit(frame) then return frame end
    if not frame.GetChildren or (depth or 0) >= 2 then return nil end

    local child1, child2, child3, child4, child5, child6,
        child7, child8, child9, child10, child11, child12 = frame:GetChildren()
    local nextDepth = (depth or 0) + 1
    local found = FindPlayerFrame(child1, nextDepth); if found then return found end
    found = FindPlayerFrame(child2, nextDepth); if found then return found end
    found = FindPlayerFrame(child3, nextDepth); if found then return found end
    found = FindPlayerFrame(child4, nextDepth); if found then return found end
    found = FindPlayerFrame(child5, nextDepth); if found then return found end
    found = FindPlayerFrame(child6, nextDepth); if found then return found end
    found = FindPlayerFrame(child7, nextDepth); if found then return found end
    found = FindPlayerFrame(child8, nextDepth); if found then return found end
    found = FindPlayerFrame(child9, nextDepth); if found then return found end
    found = FindPlayerFrame(child10, nextDepth); if found then return found end
    found = FindPlayerFrame(child11, nextDepth); if found then return found end
    return FindPlayerFrame(child12, nextDepth)
end

local function FindPlayerResourceBar()
    local playerFrame = FindPlayerFrame(CompactPartyFrame)
    local bar = playerFrame and GetResourceBar(playerFrame)
    if bar then return bar end

    playerFrame = FindPlayerFrame(CompactRaidFrameContainer)
    bar = playerFrame and GetResourceBar(playerFrame)
    if bar then return bar end

    playerFrame = FindPlayerFrame(PartyFrame)
    bar = playerFrame and GetResourceBar(playerFrame)
    if bar then return bar end

    for index = 1, compactFrameNameCount do
        local frame = _G[COMPACT_FRAME_NAMES[index]]
        if frame and IsPlayerUnit(frame) then
            bar = GetResourceBar(frame)
            if bar then return bar end
        end
    end

    local main = PlayerFrame and PlayerFrame.PlayerFrameContent
    local content = main and main.PlayerFrameContentMain
    local healthArea = content and content.HealthBarArea
    if healthArea then
        bar = GetResourceBar(healthArea)
        if bar then return bar end
    end

    return nil
end

local function EnsureOverlay()
    if overlay then return end

    overlay = CreateFrame("Frame", "BSO_ClassResourceOverlay", UIParent)
    overlay:SetHeight(pipHeight)
    overlay:EnableMouse(false)
    overlay:Hide()

    for index = 1, MAX_PIPS do
        local pip = CreateFrame("StatusBar", nil, overlay)
        pip:SetStatusBarTexture(PIP_TEXTURE)
        pip:SetOrientation("HORIZONTAL")
        pip:EnableMouse(false)

        local background = pip:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(pip)
        background:SetTexture(PIP_TEXTURE)
        background:SetVertexColor(0.15, 0.15, 0.15, 0.7)

        pips[index] = pip
        progress[index] = 0
        pipOrder[index] = index
    end
end

local function AttachTo(bar)
    if InCombatLockdown() then return false end
    EnsureOverlay()

    if currentBar ~= bar then
        if currentBar then overlay:Hide() end
        currentBar = bar
    end

    if not bar then
        overlay:Hide()
        return
    end

    overlay:SetParent(bar)
    overlay:ClearAllPoints()
    overlay:SetPoint("BOTTOM", bar, "BOTTOM", 0, -1)
    overlay:SetFrameLevel((bar:GetFrameLevel() or 0) + 5)
    return true
end

local UpdatePips

UpdatePips = function()
    if not enabled then
        if overlay then overlay:Hide() end
        return
    end
    if not overlay or not currentBar then
        return
    end

    local state = resourceProvider:GetState()
    local maximum = math_min(state.maximum or 0, MAX_PIPS)
    if maximum <= 0 then
        overlay:Hide()
        return
    end

    for index = 1, MAX_PIPS do
        progress[index] = state.progress[index] or 0
        local pip = pips[index]
        pip:SetMinMaxValues(0, 1)
        pip:SetValue(progress[index])
        if progress[index] >= 1 then
            pip:SetStatusBarColor(1, 0.82, 0, 1)
        else
            pip:SetStatusBarColor(1, 1, 1, 1)
        end
    end
    addon.SortSpecialResources(progress, pipOrder, maximum)

    local totalWidth = maximum * pipWidth + (maximum - 1) * PIP_GAP
    overlay:SetSize(totalWidth, pipHeight)

    overlay:Show()
    for index = 1, MAX_PIPS do
        local pip = pips[pipOrder[index]]
        if index <= maximum then
            pip:SetSize(pipWidth, pipHeight)
            pip:ClearAllPoints()
            pip:SetPoint("LEFT", overlay, "LEFT", (index - 1) * (pipWidth + PIP_GAP), 0)
            pip:Show()
        else
            pip:Hide()
        end
    end

end

local pendingLocate = false
local locateAttempts = 0
local MAX_LOCATE_ATTEMPTS = 6
local ScheduleLocate

local function Locate()
    if not enabled then return false end
    if InCombatLockdown() then
        pendingLocate = true
        return false
    end
    local targetBar = FindPlayerResourceBar()
    if not AttachTo(targetBar) then return false end
    UpdatePips()
    return true
end

local function OnLocateTimer()
    refreshScheduled = false
    if InCombatLockdown() then
        pendingLocate = true
        return
    end
    pendingLocate = false
    if Locate() then
        locateAttempts = 0
    elseif enabled and locateAttempts < MAX_LOCATE_ATTEMPTS then
        locateAttempts = locateAttempts + 1
        ScheduleLocate(true)
    end
end

ScheduleLocate = function(isRetry)
    if not isRetry then locateAttempts = 0 end
    if not enabled or refreshScheduled then return end
    refreshScheduled = true
    C_Timer.After(0.05, OnLocateTimer)
end

function addon.SetClassResourceOverlayEnabled(value)
    enabled = value and true or false
    if not enabled then
        pendingLocate = false
        locateAttempts = 0
        if overlay then overlay:Hide() end
        return
    end
    ScheduleLocate()
end

function addon.SetClassResourceOverlayPipSize(width, height)
    if type(width) ~= "number" or type(height) ~= "number" then return false end
    if width < 4 or width > 32 or height < 2 or height > 20 then return false end

    pipWidth, pipHeight = width, height
    if overlay then overlay:SetHeight(pipHeight) end
    UpdatePips()
    return true
end

eventFrame = CreateFrame("Frame")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("UI_SCALE_CHANGED")
eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")

eventFrame:SetScript("OnEvent", function(_, event, _, powerType)
    if not enabled and event ~= "PLAYER_REGEN_ENABLED" then return end
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingLocate then ScheduleLocate() end
    elseif event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD"
        or event == "UI_SCALE_CHANGED"
        or event == "DISPLAY_SIZE_CHANGED" or event == "EDIT_MODE_LAYOUTS_UPDATED" then
        ScheduleLocate()
    end
end)

addon.RegisterSpecialResourceListener(function()
    UpdatePips()
end)

addon.RegisterInitializer(function()
    EnsureOverlay()
    Locate()
end)