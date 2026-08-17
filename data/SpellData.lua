local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

addon.Data = addon.Data or {}

-- Spell data format
-- ============================================================================
-- Each entry is an ordered list. Entries MUST be either a numeric spellID or:
--   { id = <spellID>, name = "<Spell Name>" }
--
-- The name is authoritative for menu display; id is used by the WoW API.
-- Spec-specific tables override the class fallback table below.
-- ============================================================================

addon.Data.MOUSE_COOLDOWNS = {
    PALADIN = {
        { id = 20473, name = "Holy Shock" },
        { id = 375576, name = "Divine Toll" },
        { id = 35395, name = "Crusader Strike" },
        { id = 31935, name = "Avenger's Shield" },
    },
    DEATHKNIGHT = {
        { id = 290541, name = "Marrowrend" },
        { id = 206930, name = "Heart Strike" },
        { id = 49184, name = "Howling Blast" },
        { id = 49143, name = "Frost Strike" },
        { id = 85948, name = "Festering Strike" },
        { id = 55090, name = "Scourge Strike" },
    },
    WARRIOR = {
        { id = 6552, name = "Pummel" },
        { id = 107574, name = "Avatar" },
    },
    ROGUE = {
        { id = 1766, name = "Kick" },
        { id = 13750, name = "Adrenaline Rush" },
    },
    MAGE = {
        { id = 2139, name = "Counterspell" },
        { id = 190319, name = "Combustion" },
    },
    SHAMAN = {
        { id = 57994, name = "Wind Shear" },
        { id = 191634, name = "Stormkeeper" },
    },
    HUNTER = {
        { id = 147362, name = "Counter Shot" },
        { id = 19574, name = "Bestial Wrath" },
    },
    PRIEST = {
        { id = 10060, name = "Power Infusion" },
        { id = 19236, name = "Desperate Prayer" },
    },
    WARLOCK = {
        { id = 19647, name = "Spell Lock" },
        { id = 1122, name = "Infernal" },
    },
    MONK = {
        { id = 116705, name = "Spear Hand Strike" },
        { id = 123904, name = "Invoke Xuen" },
    },
    DRUID = {
        { id = 106839, name = "Skull Bash" },
        { id = 102558, name = "Incarnation" },
    },
    DEMONHUNTER = {
        { id = 183752, name = "Consume Magic" },
        { id = 191427, name = "Metamorphosis" },
    },
    EVOKER = {
        { id = 351338, name = "Globe of Frost" },
        { id = 375087, name = "Dragonrage" },
    },
}

addon.Data.MOUSE_COOLDOWNS_BY_SPEC = {
    [65] = {
        { id = 20473, name = "Holy Shock" },
        { id = 375576, name = "Divine Toll" },
        { id = 35395, name = "Crusader Strike" },
    },
    [66] = {
        { id = 31935, name = "Avenger's Shield" },
        { id = 375576, name = "Divine Toll" },
    },
    [70] = {
        { id = 35395, name = "Crusader Strike" },
        { id = 375576, name = "Divine Toll" },
    },
    [250] = {
        { id = 290541, name = "Marrowrend" },
        { id = 206930, name = "Heart Strike" },
    },
    [251] = {
        { id = 49184, name = "Howling Blast" },
        { id = 49143, name = "Frost Strike" },
    },
    [252] = {
        { id = 85948, name = "Festering Strike" },
        { id = 55090, name = "Scourge Strike" },
    },
}
