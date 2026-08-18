-- Horizontal special-resource pips for the player's Blizzard group frame.
-- Discovery and rendering are intentionally separate from the absorb pipeline.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local CreateFrame = CreateFrame
local UnitClass = UnitClass
local C_Timer = C_Timer
local Enum = Enum
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

-- Discovery predicates and the bounded compact-frame walk are shared with
-- BlizzardFrames.lua via FrameDiscovery.lua, instead of each module keeping
-- its own copy (and its own full tree walk) of the same lookup logic.
local IsForbidden = addon.IsForbiddenFrame
local IsStatusBar = addon.IsStatusBar
local GetUnit = addon.GetUnit
local IsPlayerUnit = addon.IsPlayerUnit
local FindPlayerFrame = addon.FindPlayerFrame
local ForEachCompactFrame = addon.ForEachCompactFrame

local function IsResourceStatusBar(child)
    if not IsStatusBar(child) then return false end
    local name = child.GetName and child:GetName() or ""
    return name == "" or name:find("Power", 1, true)
        or name:find("Mana", 1, true) or name:find("Resource", 1, true)
end

local function FindResourceStatusBar(...)
    local childCount = select("#", ...)
    for index = 1, childCount do
        local child = select(index, ...)
        if IsResourceStatusBar(child) then return child end
    end
    return nil
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
        return FindResourceStatusBar(frame:GetChildren())
    end

    return nil
end

-- Reused across FindPlayerResourceBar calls so bounding the compact-frame
-- scan doesn't allocate a new closure every retry/locate pass.
local foundResourceBar
local function HandlePlayerCompactFrame(frame)
    if foundResourceBar then return end
    if IsPlayerUnit(frame) then
        foundResourceBar = GetResourceBar(frame)
    end
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

    -- Bounded by the actual group/raid size instead of always resolving all
    -- ~200 fixed compact-frame names (shared with BlizzardFrames.lua).
    foundResourceBar = nil
    ForEachCompactFrame(HandlePlayerCompactFrame)
    if foundResourceBar then return foundResourceBar end

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
    -- Shared with PlayerBar.lua's circle rendering: fills progress/order and
    -- applies value/color/sort to each pip, returning the clamped maximum.
    local maximum = addon.RenderResourcePips(state, pips, progress, pipOrder, MAX_PIPS)
    if maximum <= 0 then
        overlay:Hide()
        return
    end

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

addon.RegisterLayoutListener(function(event)
    if event == "PLAYER_REGEN_ENABLED" then
        if pendingLocate then ScheduleLocate() end
        return
    end
    ScheduleLocate()
end)

addon.RegisterSpecialResourceListener(function()
    UpdatePips()
end)

addon.RegisterInitializer(function()
    EnsureOverlay()
    Locate()
end)