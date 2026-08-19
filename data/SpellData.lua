local addon = _G.BloodShieldOverlay or {}
_G.BloodShieldOverlay = addon

addon.Data = addon.Data or {}

-- Spell data format
-- ============================================================================
-- Each entry is an ordered list. Entries MUST be either a numeric spellID or:
--   { id = <spellID>, name = "<Spell Name>" }
--
-- The name is authoritative for menu display; id is used by the WoW API.
-- Mouse cooldowns intentionally use class-wide lists so the player can choose
-- from the full set of relevant short/base cooldowns regardless of spec.
--
-- Convention: each class lists exactly 2 core, spec-defining spells per spec
-- (one builder/generator-type ability and one spender/identity ability),
-- ordered spec by spec (e.g. spec1 spell A, spec1 spell B, spec2 spell A, ...).
-- ============================================================================

addon.Data.MOUSE_COOLDOWNS = {
    -- Holy / Protection / Retribution
    PALADIN = {
        { id = 20473, name = "Holy Shock" },
        { id = 375576, name = "Divine Toll" },
        { id = 35395, name = "Crusader Strike" },
        { id = 31935, name = "Avenger's Shield" },
    },
    -- Blood / Frost / Unholy
    DEATHKNIGHT = {
        { id = 195182, name = "Marrowrend" },
        { id = 206930, name = "Heart Strike" },
        { id = 49184, name = "Howling Blast" },
        { id = 49143, name = "Frost Strike" },
        { id = 85948, name = "Festering Strike" },
        { id = 55090, name = "Scourge Strike" },
    },
    -- Arms / Fury / Protection
    WARRIOR = {
        { id = 12294, name = "Mortal Strike" },
        { id = 7384, name = "Overpower" },
        { id = 23881, name = "Bloodthirst" },
        { id = 184367, name = "Rampage" },
        { id = 23922, name = "Shield Slam" },
        { id = 6572, name = "Revenge" },
    },
    -- Assassination / Outlaw / Subtlety
    ROGUE = {
        { id = 1329, name = "Mutilate" },
        { id = 32645, name = "Envenom" },
        { id = 185763, name = "Pistol Shot" },
        { id = 315341, name = "Between the Eyes" },
        { id = 185438, name = "Shadowstrike" },
        { id = 319175, name = "Black Powder" },
    },
    -- Arcane / Fire / Frost
    MAGE = {
        { id = 30451, name = "Arcane Blast" },
        { id = 44425, name = "Arcane Barrage" },
        { id = 133, name = "Fireball" },
        { id = 11366, name = "Pyroblast" },
        { id = 116, name = "Frostbolt" },
        { id = 30455, name = "Ice Lance" },
    },
    -- Elemental / Enhancement / Restoration
    SHAMAN = {
        { id = 51505, name = "Lava Burst" },
        { id = 8042, name = "Earth Shock" },
        { id = 17364, name = "Stormstrike" },
        { id = 60103, name = "Lava Lash" },
        { id = 8004, name = "Healing Surge" },
        { id = 61295, name = "Riptide" },
    },
    -- Beast Mastery / Marksmanship / Survival
    HUNTER = {
        { id = 34026, name = "Kill Command" },
        { id = 193455, name = "Cobra Shot" },
        { id = 19434, name = "Aimed Shot" },
        { id = 257044, name = "Rapid Fire" },
        { id = 186270, name = "Raptor Strike" },
        { id = 259495, name = "Wildfire Bomb" },
    },
    -- Discipline / Holy / Shadow
    PRIEST = {
        { id = 47540, name = "Penance" },
        { id = 194509, name = "Power Word: Radiance" },
        { id = 2050, name = "Holy Word: Serenity" },
        { id = 596, name = "Prayer of Healing" },
        { id = 8092, name = "Mind Blast" },
        { id = 205448, name = "Void Bolt" },
    },
    -- Affliction / Demonology / Destruction
    WARLOCK = {
        { id = 980, name = "Agony" },
        { id = 316099, name = "Unstable Affliction" },
        { id = 104316, name = "Call Dreadstalkers" },
        { id = 105174, name = "Hand of Gul'dan" },
        { id = 116858, name = "Chaos Bolt" },
        { id = 17962, name = "Conflagrate" },
    },
    -- Brewmaster / Mistweaver / Windwalker
    MONK = {
        { id = 121253, name = "Keg Smash" },
        { id = 115181, name = "Breath of Fire" },
        { id = 116670, name = "Vivify" },
        { id = 124682, name = "Enveloping Mist" },
        { id = 107428, name = "Rising Sun Kick" },
        { id = 113656, name = "Fists of Fury" },
    },
    -- Balance / Feral / Guardian / Restoration
    DRUID = {
        { id = 78674, name = "Starsurge" },
        { id = 191034, name = "Starfall" },
        { id = 1822, name = "Rake" },
        { id = 22568, name = "Ferocious Bite" },
        { id = 33917, name = "Mangle" },
        { id = 192090, name = "Thrash" },
        { id = 774, name = "Rejuvenation" },
        { id = 48438, name = "Wild Growth" },
    },
    -- Havoc / Vengeance
    DEMONHUNTER = {
        { id = 162794, name = "Chaos Strike" },
        { id = 188499, name = "Blade Dance" },
        { id = 228477, name = "Soul Cleave" },
        { id = 263642, name = "Fracture" },
    },
    -- Devastation / Preservation / Augmentation
    EVOKER = {
        { id = 357208, name = "Fire Breath" },
        { id = 359073, name = "Eternity Surge" },
        { id = 355936, name = "Dream Breath" },
        { id = 367226, name = "Spiritbloom" },
        { id = 395152, name = "Ebon Might" },
        { id = 409311, name = "Prescience" },
    },
}