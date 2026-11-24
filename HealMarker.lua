-- Temporary visual role markers on Blizzard compact party/raid frames.
-- Resolve the current target with UnitIsUnit; never read GUIDs or player names.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local CreateFrame = CreateFrame
local InCombatLockdown = InCombatLockdown
local IsInRaid = IsInRaid
local IsInGroup = IsInGroup
local GetNumGroupMembers = GetNumGroupMembers
local UnitExists = UnitExists
local UnitIsUnit = UnitIsUnit
local hooksecurefunc = hooksecurefunc
local type = type
local pairs = pairs

local markedUnits = {}
local markersByFrame = setmetatable({}, { __mode = "k" })
local ROLE_MENU_ORDER = { "carry", "heal", "tank", "dps" }
local ROLE_MENU_LABELS = { carry = "Carry", heal = "Heal", tank = "Tank", dps = "DPS" }
local roleMenusRegistered = false
local function GetGroupState()
    if not IsInGroup or not IsInGroup() then return "none" end
    return IsInRaid and IsInRaid() and "raid" or "party"
end
local lastGroupKind = GetGroupState()
local ROLE_STYLE = {
    heal = { atlas = "roleicon-tiny-healer" },
    tank = { atlas = "roleicon-tiny-tank" },
    dps = { atlas = "roleicon-tiny-dps" },
    -- Carry is not a Blizzard group role, so use the familiar raid star.
    carry = { texture = "Interface\\TargetingFrame\\UI-RaidTargetingIcon_1" },
}

local function FindTargetGroupUnit()
    if not UnitExists("target") then return nil end
    local count = GetNumGroupMembers and GetNumGroupMembers() or 0
    if IsInRaid and IsInRaid() then
        if count > 40 then count = 40 end
        for index = 1, count do
            local unit = "raid" .. index
            if UnitIsUnit("target", unit) then return unit end
        end
    elseif IsInGroup and IsInGroup() then
        count = math.min(4, math.max(0, count - 1))
        for index = 1, count do
            local unit = "party" .. index
            if UnitIsUnit("target", unit) then return unit end
        end
    end
    return nil
end

local function IsCurrentGroupUnit(unit)
    if type(unit) ~= "string" then return false end
    local index = unit:match("^raid([1-9]?[0-9])$")
    if index then
        index = tonumber(index)
        return IsInRaid and IsInRaid() and index <= 40 and index <= (GetNumGroupMembers and GetNumGroupMembers() or 0)
    end
    index = unit:match("^party([1-4])$")
    if index then
        index = tonumber(index)
        local memberCount = GetNumGroupMembers and GetNumGroupMembers() or 0
        return IsInGroup and IsInGroup() and not (IsInRaid and IsInRaid())
            and index <= math.min(4, math.max(0, memberCount - 1))
    end
    return false
end

local function CreateMarker(frame)
    if not frame or addon.IsForbiddenFrame(frame) or InCombatLockdown() then return nil end
    local marker = CreateFrame("Frame", nil, frame)
    marker:SetSize(18, 18)
    marker:SetPoint("TOPLEFT", frame, "TOPLEFT", 1, -1)
    marker:SetFrameLevel((frame.GetFrameLevel and frame:GetFrameLevel() or 0) + 20)
    marker:EnableMouse(false)
    local background = marker:CreateTexture(nil, "BACKGROUND")
    background:SetAllPoints(marker)
    background:SetColorTexture(0.05, 0.05, 0.05, 0.82)
    local icon = marker:CreateTexture(nil, "OVERLAY")
    icon:SetSize(16, 16)
    icon:SetPoint("CENTER", marker, "CENTER", 0, 0)
    marker.icon = icon
    marker:Hide()
    markersByFrame[frame] = marker
    return marker
end

local function UpdateFrame(frame)
    if not frame or addon.IsForbiddenFrame(frame) or InCombatLockdown() then return end
    local unit = addon.GetUnit(frame)
    local marker = markersByFrame[frame]
    if not marker and unit and markedUnits[unit] then marker = CreateMarker(frame) end
    if not marker then return end
    local role = unit and markedUnits[unit]
    if role and ROLE_STYLE[role] then
        local style = ROLE_STYLE[role]
        if style.atlas then
            marker.icon:SetAtlas(style.atlas)
        else
            marker.icon:SetTexture(style.texture)
        end
        marker:Show()
    else
        marker:Hide()
    end
end

local function RefreshFrames()
    if InCombatLockdown() then return end
    for frame in pairs(markersByFrame) do UpdateFrame(frame) end
    addon.ForEachCompactFrame(UpdateFrame)
end

local function ClearMarks()
    for unit in pairs(markedUnits) do markedUnits[unit] = nil end
end

function addon.ToggleRoleForUnit(unit, role)
    if not ROLE_STYLE[role] or not IsCurrentGroupUnit(unit) then return false end
    local previousRole = markedUnits[unit]
    if previousRole == role then
        markedUnits[unit] = nil
    else
        markedUnits[unit] = role
    end
    RefreshFrames()
    return true, markedUnits[unit] and "assigned" or "removed", previousRole
end

function addon.HandleRoleSlashCommand(role, message)
    if not ROLE_STYLE[role] then return end
    local argument = type(message) == "string" and message:match("^%s*(.-)%s*$") or ""
    if argument ~= "" then
        print("BloodShieldOverlay: /" .. role .. " takes no arguments. Target a group member, then use /" .. role .. ".")
        return
    end

    local unit = FindTargetGroupUnit()
    if not unit then
        print("BloodShieldOverlay: your target is not in your current party or raid.")
        return
    end

    local _, state, previousRole = addon.ToggleRoleForUnit(unit, role)
    if state == "assigned" then
        print("BloodShieldOverlay: target marked as " .. role .. ".")
    elseif previousRole then
        print("BloodShieldOverlay: " .. previousRole .. " marker removed.")
    end
end

function addon.HandleHealSlashCommand(message)
    addon.HandleRoleSlashCommand("heal", message)
end

addon.RegisterLayoutListener(function(event)
    if event == "GROUP_ROSTER_UPDATE" then
        local groupKind = GetGroupState()
        -- Keep marks while this group changes. Clear only after leaving it so
        -- marks do not carry into the next party/raid.
        if groupKind == "none" and lastGroupKind ~= "none" then ClearMarks() end
        lastGroupKind = groupKind
    end
    RefreshFrames()
end)

addon.RegisterRegenListener(function(event)
    if event == "PLAYER_REGEN_ENABLED" then RefreshFrames() end
end)

if hooksecurefunc then
    local function OnCompactFrameUpdated(frame) UpdateFrame(frame) end
    if _G.CompactUnitFrame_UpdateAll then hooksecurefunc("CompactUnitFrame_UpdateAll", OnCompactFrameUpdated) end
    if _G.CompactUnitFrame_UpdateHealth then hooksecurefunc("CompactUnitFrame_UpdateHealth", OnCompactFrameUpdated) end
    if _G.CompactUnitFrame_UpdateHealPrediction then hooksecurefunc("CompactUnitFrame_UpdateHealPrediction", OnCompactFrameUpdated) end
    if _G.CompactUnitFrame_SetUpFrame then hooksecurefunc("CompactUnitFrame_SetUpFrame", OnCompactFrameUpdated) end
end

local function RegisterRoleContextMenus()
    if roleMenusRegistered or not _G.Menu or type(_G.Menu.ModifyMenu) ~= "function"
        or not _G.MenuUtil or type(_G.MenuUtil.CreateButton) ~= "function" then return false end

    local function AddRoleSubmenu(owner, rootDescription, contextData)
        -- Do not inspect owner/context data while Blizzard builds its secure
        -- menu. Read the normal unit token only after the user clicks an item.
        local submenu = _G.MenuUtil.CreateButton("Añadir stick")
        -- Attach first: child descriptions inherit shared menu properties
        -- from their parent and otherwise Menu.lua's callbacks are nil.
        rootDescription:Insert(submenu, 1)
        for _, role in ipairs(ROLE_MENU_ORDER) do
            local selectedRole = role
            submenu:CreateButton(ROLE_MENU_LABELS[role], function()
                local ok, unit = pcall(addon.GetUnit, owner)
                if ok then
                    local actionOK, assigned = pcall(addon.ToggleRoleForUnit, unit, selectedRole)
                    if actionOK and assigned then return end
                end

                -- Some self/player popup variants expose their unit token only
                -- through contextData; access it only after the menu is chosen.
                local contextOK, contextUnit = pcall(function() return contextData and contextData.unit end)
                if contextOK then pcall(addon.ToggleRoleForUnit, contextUnit, selectedRole) end
            end)
        end
    end

    _G.Menu.ModifyMenu("MENU_UNIT_SELF", AddRoleSubmenu)
    _G.Menu.ModifyMenu("MENU_UNIT_PLAYER", AddRoleSubmenu)
    _G.Menu.ModifyMenu("MENU_UNIT_RAID_PLAYER", AddRoleSubmenu)
    _G.Menu.ModifyMenu("MENU_UNIT_RAID", AddRoleSubmenu)
    _G.Menu.ModifyMenu("MENU_UNIT_PARTY", AddRoleSubmenu)
    roleMenusRegistered = true
    return true
end

addon.RegisterInitializer(RegisterRoleContextMenus)

local menuLoadFrame = CreateFrame("Frame")
menuLoadFrame:RegisterEvent("ADDON_LOADED")
menuLoadFrame:SetScript("OnEvent", function(_, _, loadedAddon)
    if loadedAddon == "Blizzard_Menu" and RegisterRoleContextMenus() then
        menuLoadFrame:UnregisterEvent("ADDON_LOADED")
    end
end)
