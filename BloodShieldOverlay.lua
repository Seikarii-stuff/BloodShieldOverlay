-- Bootstrap/namespace and deterministic module initialization coordinator.

local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

local addonName = ... or "BloodShieldOverlay"
local initializers = {}
local initialized = false

function addon.RegisterInitializer(initializer)
	if type(initializer) ~= "function" then return end

	if initialized then
		initializer()
	else
		initializers[#initializers + 1] = initializer
	end
end

local function Initialize()
	if initialized then return end
	initialized = true

	for index = 1, #initializers do
		initializers[index]()
		initializers[index] = nil
	end
end

local bootstrapFrame = CreateFrame("Frame")
bootstrapFrame:RegisterEvent("ADDON_LOADED")
bootstrapFrame:RegisterEvent("PLAYER_LOGIN")
bootstrapFrame:SetScript("OnEvent", function(_, event, loadedAddon)
	if event == "PLAYER_LOGIN" or loadedAddon == addonName then
		Initialize()
	end
end)

-- The bootstrap owns the public command registration. PlayerBar only exposes
-- the command handler and remains responsible for rendering/config behavior.
SlashCmdList["BLOODSHIELDOVERLAY"] = function(msg)
		if addon.HandleSlashCommand then
			addon.HandleSlashCommand(msg)
		end
	end
SLASH_BLOODSHIELDOVERLAY1 = "/shield"
SLASH_BLOODSHIELDOVERLAY2 = "/shieldbar"
SLASH_BLOODSHIELDOVERLAY3 = "/shields"
SlashCmdList["BLOODSHIELDHEAL"] = function(msg)
		if addon.HandleHealSlashCommand then
			addon.HandleHealSlashCommand(msg)
		end
	end
SLASH_BLOODSHIELDHEAL1 = "/heal"
SlashCmdList["BLOODSHIELDTANK"] = function(msg)
		if addon.HandleRoleSlashCommand then addon.HandleRoleSlashCommand("tank", msg) end
	end
SLASH_BLOODSHIELDTANK1 = "/tank"
SlashCmdList["BLOODSHIELDDPS"] = function(msg)
		if addon.HandleRoleSlashCommand then addon.HandleRoleSlashCommand("dps", msg) end
	end
SLASH_BLOODSHIELDDPS1 = "/dps"
SlashCmdList["BLOODSHIELDCARRY"] = function(msg)
		if addon.HandleRoleSlashCommand then addon.HandleRoleSlashCommand("carry", msg) end
	end
SLASH_BLOODSHIELDCARRY1 = "/carry"
