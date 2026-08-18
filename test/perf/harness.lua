-- Minimal WoW API simulator for offline smoke tests and synthetic benchmarks.
local M = {}
local unpack_values = _G.unpack or table.unpack

_G = _G
_G.table.wipe = _G.table.wipe or function(t) for k in pairs(t) do t[k] = nil end end
_G.UIParent = { name = "UIParent", scale = 1 }
_G.UIParent.GetEffectiveScale = function(self) return self.scale end
_G.BloodShieldOverlayProfiles = nil
_G.BloodShieldOverlayDB = nil
_G.SlashCmdList = {}
_G.print = _G.print or function() end
_G.STANDARD_TEXT_FONT = "Fonts\\FRIZQT__.TTF"
_G.issecretvalue = function(value)
    return type(value) == "table" and value.__secret == true
end

local frames = {}
local objectCounts = {}
local timers = {}
local health = { player = 1000, party1 = 500, raid1 = 750 }
local absorbs = { player = 250, party1 = 100, raid1 = 200 }
local power = { player = 40 }
local maxPower = { player = 100 }
local inCombat = false
local inRaid = false
local inGroup = false
local groupMemberCount = 0
local getChildrenCalls = 0

local function frame_method(self, name, fn)
    self[name] = fn
end

local function new_frame(objectType, name, parent)
    local frameType = objectType or "Frame"
    local frame = { objectType = frameType, name = name, parent = parent, children = {}, scripts = {}, shown = true, width = 100, height = 100, events = {} }
    frames[#frames + 1] = frame
    objectCounts[frameType] = (objectCounts[frameType] or 0) + 1
    if parent and parent.children then parent.children[#parent.children + 1] = frame end
    frame_method(frame, "GetObjectType", function(self) return self.objectType end)
    frame_method(frame, "GetName", function(self) return self.name end)
    frame_method(frame, "GetParent", function(self) return self.parent end)
    frame_method(frame, "IsForbidden", function() return false end)
    frame_method(frame, "GetChildren", function(self)
        getChildrenCalls = getChildrenCalls + 1
        return unpack_values(self.children)
    end)
    frame_method(frame, "GetAttribute", function(self, key) return self[key] end)
    frame_method(frame, "SetAttribute", function(self, key, value) self[key] = value end)
    frame_method(frame, "SetScript", function(self, event, fn) self.scripts[event] = fn end)
    frame_method(frame, "GetScript", function(self, event) return self.scripts[event] end)
    frame_method(frame, "RegisterEvent", function(self, event) self.events[event] = true end)
    frame_method(frame, "UnregisterEvent", function(self, event) self.events[event] = nil end)
    frame_method(frame, "UnregisterAllEvents", function(self) self.events = {} end)
    frame_method(frame, "RegisterUnitEvent", function(self, event, ...)
        self.unitEvents = self.unitEvents or {}
        self.unitEvents[event] = self.unitEvents[event] or {}
        for index = 1, select("#", ...) do
            self.unitEvents[event][select(index, ...)] = true
        end
    end)
    frame_method(frame, "SetAllPoints", function(self, target) self.allPoints = target end)
    frame_method(frame, "SetParent", function(self, value) self.parent = value end)
    frame_method(frame, "SetStatusBarTexture", function(self, texture)
        self.texture = texture
        if not self.statusBarTexture then
            self.statusBarTexture = new_frame("Texture", nil, self)
        end
        self.statusBarTexture.texture = texture
    end)
    frame_method(frame, "GetStatusBarTexture", function(self) return self.statusBarTexture end)
    frame_method(frame, "SetStatusBarColor", function(self, r, g, b, a) self.color = { r, g, b, a } end)
    frame_method(frame, "SetOrientation", function(self, value) self.orientation = value end)
    frame_method(frame, "SetReverseFill", function(self, value) self.reverse = value end)
    frame_method(frame, "EnableMouse", function(self, value) self.mouseEnabled = value end)
    frame_method(frame, "RegisterForClicks", function(self, ...) self.clicks = { ... } end)
    frame_method(frame, "Show", function(self) self.shown = true end)
    frame_method(frame, "Hide", function(self) self.shown = false end)
    frame_method(frame, "IsShown", function(self) return self.shown end)
    frame_method(frame, "SetMinMaxValues", function(self, min, max) self.min, self.max = min, max end)
    frame_method(frame, "SetValue", function(self, value) self.value = value end)
    frame_method(frame, "SetSize", function(self, width, height) self.width, self.height = width, height end)
    frame_method(frame, "SetWidth", function(self, value) self.width = value end)
    frame_method(frame, "GetWidth", function(self) return self.width end)
    frame_method(frame, "GetHeight", function(self) return self.height end)
    frame_method(frame, "SetPoint", function(self, point, relative, relativePoint, x, y) self.point, self.relative, self.relativePoint, self.x, self.y = point, relative, relativePoint, x, y end)
    frame_method(frame, "GetPoint", function(self) return self.point, nil, self.relativePoint, self.x, self.y end)
    frame_method(frame, "ClearAllPoints", function(self) self.point = nil end)
    frame_method(frame, "SetFrameStrata", function() end)
    frame_method(frame, "SetFrameLevel", function(self, value) self.frameLevel = value end)
    frame_method(frame, "GetFrameLevel", function(self) return self.frameLevel or 0 end)
    frame_method(frame, "SetMovable", function(self, value) self.movable = value end)
    frame_method(frame, "RegisterForDrag", function(self, button) self.dragButton = button end)
    frame_method(frame, "StartMoving", function(self) self.moving = true end)
    frame_method(frame, "StopMovingOrSizing", function(self) self.moving = false end)
    frame_method(frame, "CreateTexture", function(self) return new_frame("Texture", nil, self) end)
    frame_method(frame, "CreateFontString", function(self) return new_frame("FontString", nil, self) end)
    frame_method(frame, "CreateMaskTexture", function(self) return new_frame("MaskTexture", nil, self) end)
    frame_method(frame, "AddMaskTexture", function(self, mask)
        self.maskTextures = self.maskTextures or {}
        self.maskTextures[#self.maskTextures + 1] = mask
    end)
    frame_method(frame, "SetColorTexture", function(self, r, g, b, a) self.color = { r, g, b, a } end)
    frame_method(frame, "SetTexture", function(self, texture, ...) self.texture = texture self.textureArgs = { ... } end)
    frame_method(frame, "SetTexCoord", function(self, ...) self.texCoord = { ... } end)
    frame_method(frame, "SetVertexColor", function(self, r, g, b, a) self.vertexColor = { r, g, b, a } end)
    frame_method(frame, "SetHeight", function(self, value) self.height = value end)
    frame_method(frame, "SetText", function(self, value) self.text = value end)
    frame_method(frame, "GetText", function(self) return self.text or "" end)
    frame_method(frame, "SetChecked", function(self, value) self.checked = value end)
    frame_method(frame, "GetChecked", function(self) return self.checked end)
    frame_method(frame, "SetAutoFocus", function() end)
    frame_method(frame, "SetJustifyH", function() end)
    frame_method(frame, "SetJustifyV", function() end)
    frame_method(frame, "SetFont", function() end)
    frame_method(frame, "SetTextColor", function() end)
    frame_method(frame, "SetShadowOffset", function() end)
    frame_method(frame, "SetWordWrap", function() end)
    frame_method(frame, "SetMaxLines", function() end)
    frame_method(frame, "SetAlpha", function(self, value) self.alpha = value end)
    frame_method(frame, "SetBlendMode", function(self, value) self.blendMode = value end)
    frame_method(frame, "SetSwipeTexture", function() end)
    frame_method(frame, "SetDrawEdge", function() end)
    frame_method(frame, "SetUseCircularEdge", function() end)
    frame_method(frame, "SetDrawSwipe", function() end)
    frame_method(frame, "SetDrawBling", function() end)
    frame_method(frame, "SetReverse", function() end)
    frame_method(frame, "SetHideCountdownNumbers", function() end)
    frame_method(frame, "Clear", function(self) self.cooldownCleared = true end)
    frame_method(frame, "SetCooldown", function(self, start, duration) self.cooldown = { start, duration } end)
    frame_method(frame, "SetCooldownFromDurationObject", function(self, duration) self.cooldownDuration = duration end)
    frame_method(frame, "SetCooldownFromExpression", function(self, spellID) self.cooldownExpression = spellID end)
    frame_method(frame, "SetCooldownTable", function(self, info) self.cooldownInfo = info end)
    frame_method(frame, "SetBackdrop", function(self, value) self.backdrop = value end)
    frame_method(frame, "SetClampedToScreen", function() end)
    return frame
end

_G.CreateFrame = function(objectType, name, parent)
    local frame = new_frame(objectType, name, parent)
    if objectType == "CheckButton" then
        frame.Text = new_frame("FontString", nil, frame)
    end
    if name then _G[name] = frame end
    return frame
end
_G.hooksecurefunc = function() end
_G.InCombatLockdown = function() return inCombat end
_G.IsInGroup = function() return inGroup end
_G.IsInRaid = function() return inRaid end
_G.GetNumGroupMembers = function() return groupMemberCount end
_G.UnitGetTotalAbsorbs = function(unit) return absorbs[unit] or 0 end
_G.UnitHealthMax = function(unit) return health[unit] or 0 end
_G.UnitHealth = function(unit) return health[unit] or 0 end
_G.UnitPower = function(unit) return power[unit] or 0 end
_G.UnitPowerMax = function(unit) return maxPower[unit] or 0 end
_G.UnitClass = function() return "Tester", "PALADIN" end
_G.Enum = { PowerType = { HolyPower = 9, Essence = 19, SoulShards = 7, Chi = 12, ComboPoints = 4 } }
_G.GetRuneCooldown = function() return 0, 0, true end
_G.GetPowerRegen = function() return 0.2, 0.2 end
_G.GetTime = function() return 100 end
_G.GetCursorPosition = function() return 960, 540 end
_G.UnitName = function() return "Tester" end
_G.GetNormalizedRealmName = function() return "Realm" end
_G.GetSpellTexture = function() return 134400 end
_G.GetSpellCooldown = function() return 0, 0 end
_G.C_Timer = { After = function(_, fn) timers[#timers + 1] = fn end }
_G.C_NamePlate = nil
_G.C_Spell = {}
_G.C_ActionBar = nil
_G.C_SpellActivationOverlay = nil
_G.UIDropDownMenu_SetText = function(frame, text) frame.text = text end
_G.UIDropDownMenu_SetWidth = function(frame, width) frame.dropdownWidth = width end
_G.UIDropDownMenu_Initialize = function(frame, initializer) frame.initialize = initializer end
_G.UIDropDownMenu_CreateInfo = function() return {} end
_G.UIDropDownMenu_AddButton = function() end
_G.CloseDropDownMenus = function() end

function M.load()
    dofile("BloodShieldOverlay.lua")
    dofile("Core.lua")
    dofile("FrameDiscovery.lua")
    dofile("AbsorbIndicator.lua")
    dofile("Configuration.lua")
    dofile("Performance.lua")
    dofile("ResourceProviders.lua")
    dofile("PlayerBar.lua")
    dofile("TargetTargetBar.lua")
    dofile("data/SpellData.lua")
    dofile("Mouse.lua")
    dofile("MouseResources.lua")
    dofile("MouseCooldowns.lua")
    dofile("Menu.lua")
    dofile("ResourceDisplayMenu.lua")
    dofile("options.lua")
    dofile("PerformanceMenu.lua")
    dofile("Commands.lua")
    dofile("BlizzardFrames.lua")
    dofile("ClassResourceOverlay.lua")
end

function M.new_frame(...) return new_frame(...) end
function M.set_combat(value) inCombat = value end
function M.set_group(group, raid, memberCount)
    inGroup, inRaid = group, raid
    if memberCount ~= nil then groupMemberCount = memberCount end
end
function M.set_values(unit, absorb, maxHealth) absorbs[unit], health[unit] = absorb, maxHealth end
function M.set_power(unit, current, maximum) power[unit], maxPower[unit] = current, maximum end
function M.fire(event, unit)
    for _, frame in ipairs(frames) do
        local registered = frame.events and frame.events[event]
        local unitRegistered = frame.unitEvents and frame.unitEvents[event]
        if (registered or (unitRegistered and unitRegistered[unit])) and frame.scripts.OnEvent then
            frame.scripts.OnEvent(frame, event, unit)
        end
    end
end
function M.tick(elapsed)
    for _, frame in ipairs(frames) do if frame.scripts.OnUpdate then frame.scripts.OnUpdate(frame, elapsed) end end
end
function M.flush_timers()
    local pending = timers; timers = {}
    for _, fn in ipairs(pending) do fn() end
end
function M.reset_get_children_calls() getChildrenCalls = 0 end
function M.get_children_calls() return getChildrenCalls end
function M.frames() return frames end
function M.object_counts()
    local result = {}
    for objectType, count in pairs(objectCounts) do result[objectType] = count end
    result.total = #frames
    return result
end
return M
