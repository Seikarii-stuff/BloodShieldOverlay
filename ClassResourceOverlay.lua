-- Horizontal special-resource pips for the player's Blizzard group frame.
-- Discovery and rendering are intentionally separate from the absorb pipeline.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local UnitClass = UnitClass
local GetTime = GetTime
local C_Timer = C_Timer
local Enum = Enum
local UnitIsUnit = UnitIsUnit
local ipairs = ipairs
local math_min = math.min
local type = type
local issecretvalue = issecretvalue

local _, playerClass = UnitClass("player")
local powerTypes = Enum and Enum.PowerType
local resourceProvider, resourceToken = addon.CreateSpecialResourceProvider(
    playerClass, powerTypes
)

if not resourceProvider then return end

local MAX_PIPS = 7
local PIP_HEIGHT = 3
local PIP_GAP = 1
local FALLBACK_PIP_WIDTH = 9
local PIP_TEXTURE = "Interface\\Buttons\\WHITE8x8"

local overlay
local pips = {}
local progress = {}
local pipOrder = {}
local currentBar
local refreshPending = false
local refreshScheduled = false
local pipWidth = FALLBACK_PIP_WIDTH
local layoutWidth = FALLBACK_PIP_WIDTH * MAX_PIPS + PIP_GAP * (MAX_PIPS - 1)
local resourceElapsed = 0
local RESOURCE_TICK = 0.2
local eventFrame

local RESOURCE_BAR_KEYS = {
    "powerBar", "PowerBar", "powerbar",
    "manaBar", "ManaBar", "manabar",
    "resourceBar", "ResourceBar", "classPowerBar",
}
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
    -- In a raid, Blizzard normally exposes the player's compact frame as
    -- raidN rather than player. UnitIsUnit is the authoritative comparison.
    return UnitIsUnit and UnitIsUnit(unit, "player") or false
end

local function GetResourceBar(frame)
    if IsForbidden(frame) then return nil end

    for _, key in ipairs(RESOURCE_BAR_KEYS) do
        local bar = frame[key]
        if IsStatusBar(bar) then return bar end
    end

    -- Some Blizzard layouts nest the power bar one level below the unit frame.
    if frame.GetChildren then
        local children = { frame:GetChildren() }
        for _, child in ipairs(children) do
            if IsStatusBar(child) then
                local name = child.GetName and child:GetName() or ""
                if name == "" or name:find("Power", 1, true)
                    or name:find("Mana", 1, true)
                    or name:find("Resource", 1, true) then
                    return child
                end
            end
        end
    end

    return nil
end

local function FindPlayerFrame(frame)
    if IsForbidden(frame) then return nil end
    if IsPlayerUnit(frame) then return frame end
    if not frame.GetChildren then return nil end

    local children = { frame:GetChildren() }
    for _, child in ipairs(children) do
        local found = FindPlayerFrame(child)
        if found then return found end
    end
    return nil
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

    -- Static names cover the normal CompactUnitFrame pools without scanning
    -- every global frame. The frame's unit is still checked before use.
    for index = 1, compactFrameNameCount do
        local frame = _G[COMPACT_FRAME_NAMES[index]]
        if frame and IsPlayerUnit(frame) then
            bar = GetResourceBar(frame)
            if bar then return bar end
        end
    end

    -- Keep the main player frame as a fallback for layouts that remove the
    -- compact party frame while the player is alone.
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
    overlay:SetHeight(PIP_HEIGHT)
    overlay:EnableMouse(false)
    overlay:Hide()

    for index = 1, MAX_PIPS do
        local pip = CreateFrame("StatusBar", nil, overlay)
        pip:SetStatusBarTexture(PIP_TEXTURE)
        pip:SetOrientation("HORIZONTAL")
        pip:EnableMouse(false)

        local background = pip:CreateTexture(nil, "BACKGROUND")
        background:SetAllPoints(pip)
        background:SetColorTexture(0, 0, 0, 0.65)

        pips[index] = pip
        progress[index] = 0
        pipOrder[index] = index
    end
end

local function AttachTo(bar)
    EnsureOverlay()

    if currentBar == bar then
        overlay:Show()
        return
    end

    if currentBar then overlay:Hide() end
    currentBar = bar
    if not bar then return end

    overlay:SetParent(bar)
    overlay:ClearAllPoints()
    overlay:SetPoint("BOTTOMLEFT", bar, "BOTTOMLEFT", 0, 0)
    overlay:SetPoint("BOTTOMRIGHT", bar, "BOTTOMRIGHT", 0, 0)
    overlay:SetFrameLevel((bar:GetFrameLevel() or 0) + 5)
    overlay:Show()
end

local UpdatePips

local function OnResourceTick(_, elapsed)
    resourceElapsed = resourceElapsed + elapsed
    if resourceElapsed < RESOURCE_TICK then return end
    resourceElapsed = 0
    UpdatePips()
end

local function SetResourceTicking(active)
    if active then
        eventFrame:SetScript("OnUpdate", OnResourceTick)
    else
        resourceElapsed = 0
        eventFrame:SetScript("OnUpdate", nil)
    end
end

UpdatePips = function()
    if not overlay or not currentBar then
        SetResourceTicking(false)
        return
    end

    local maximum = math_min(resourceProvider:GetMax() or 0, MAX_PIPS)
    if maximum <= 0 then
        overlay:Hide()
        SetResourceTicking(false)
        return
    end

    local _, charging = resourceProvider:Update(progress, pips, GetTime())
    addon.SortSpecialResources(progress, pipOrder, maximum)

    -- Protected compact bars can return a secret width. Secret values may be
    -- passed through WoW frame APIs, but cannot be compared or divided in
    -- Lua. When the width is public (normally outside protected layout work),
    -- cache the current geometry and reuse it while the value is secret.
    if issecretvalue then
        local width = overlay:GetWidth()
        if not issecretvalue(width) and width > 0 then
            layoutWidth = width
        end
    end

    local available = layoutWidth - PIP_GAP * (maximum - 1)
    if available > 0 then pipWidth = available / maximum end

    overlay:Show()
    for index = 1, MAX_PIPS do
        local pip = pips[pipOrder[index]]
        if index <= maximum then
            pip:SetSize(pipWidth, PIP_HEIGHT)
            pip:ClearAllPoints()
            pip:SetPoint("LEFT", overlay, "LEFT",
                (index - 1) * (pipWidth + PIP_GAP), 0)
            pip:Show()
        else
            pip:Hide()
        end
    end

    -- Runes and Evoker Essence expose a cooldown fraction, not a new power
    -- event for every visual step. Keep a demand-driven ticker only while a
    -- pip is charging; completed/instant resources remain event-driven.
    SetResourceTicking(charging and true or false)
end

local function Locate()
    if InCombatLockdown() then
        refreshPending = true
        return
    end

    refreshPending = false
    AttachTo(FindPlayerResourceBar())
    UpdatePips()
end

local function ScheduleLocate()
    if InCombatLockdown() then
        refreshPending = true
        return
    end
    if refreshScheduled then return end

    refreshScheduled = true
    C_Timer.After(0.05, function()
        refreshScheduled = false
        Locate()
    end)
end

eventFrame = CreateFrame("Frame")
eventFrame:RegisterUnitEvent("UNIT_POWER_UPDATE", "player")
eventFrame:RegisterUnitEvent("UNIT_MAXPOWER", "player")
eventFrame:RegisterUnitEvent("UNIT_POWER_FREQUENT", "player")
eventFrame:RegisterEvent("RUNE_POWER_UPDATE")
eventFrame:RegisterEvent("GROUP_ROSTER_UPDATE")
eventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
eventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
eventFrame:RegisterEvent("UI_SCALE_CHANGED")
eventFrame:RegisterEvent("DISPLAY_SIZE_CHANGED")
eventFrame:RegisterEvent("EDIT_MODE_LAYOUTS_UPDATED")
eventFrame:SetScript("OnEvent", function(_, event, _, powerType)
    if event == "GROUP_ROSTER_UPDATE" or event == "PLAYER_ENTERING_WORLD"
        or event == "UI_SCALE_CHANGED" or event == "DISPLAY_SIZE_CHANGED"
        or event == "EDIT_MODE_LAYOUTS_UPDATED" then
        ScheduleLocate()
    elseif event == "PLAYER_REGEN_ENABLED" then
        if refreshPending then ScheduleLocate() end
    elseif event == "RUNE_POWER_UPDATE" or event == "UNIT_MAXPOWER"
        or (resourceToken and powerType == resourceToken) then
        UpdatePips()
    end
end)

addon.RegisterInitializer(function()
    EnsureOverlay()
    Locate()
    if addon.RequestRefresh then addon.RequestRefresh() end
    -- Blizzard may populate CompactUnitFrames on the next layout pass.
    -- Retry after that pass without touching protected frames in combat.
    ScheduleLocate()
end)
