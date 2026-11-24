---@meta

--#region Weapon Module (shared)
-- Nessuna native è disponibile in shared; solo definizioni di tipi/costanti.
--#endregion

---@class WeaponDef
---@field hash integer
---@field ammo? integer
---@field component? integer[]

---Costanti armi comuni disponibili in shared per comodità di configurazione loadout.
---@type table<string, integer>
weapon = weapon or {}

weapon.Hash = {
    -- Pistole
    PISTOL             = 0x1B06D571,
    PISTOL_MK2         = 0xBFE256D4,
    COMBAT_PISTOL      = 0x5EF9FEC4,
    AP_PISTOL          = 0x22D8FE39,
    SNS_PISTOL         = 0xBFD21232,
    HEAVY_PISTOL       = 0xD205520E,
    VINTAGE_PISTOL     = 0x083839C4,
    FLARE_GUN          = 0x47757124,
    MARKSMAN_PISTOL    = 0xDC4DB296,
    REVOLVER           = 0xC1B3C3D1,
    REVOLVER_MK2       = 0xCB96392F,
    -- SMG
    MICRO_SMG          = 0x13532244,
    SMG                = 0x2BE6766B,
    SMG_MK2            = 0x78A97CD0,
    ASSAULT_SMG        = 0xEFE7E2DF,
    COMBAT_PDW         = 0xA3D4D34,
    MACHINE_PISTOL     = 0xDB1AA450,
    -- Shotgun
    PUMP_SHOTGUN       = 0x1D073A89,
    PUMP_SHOTGUN_MK2   = 0x555AF99A,
    SAWN_OFF_SHOTGUN   = 0x7846A318,
    BULLPUP_SHOTGUN    = 0x9D61E50F,
    ASSAULT_SHOTGUN    = 0xE284C527,
    COMBAT_SHOTGUN     = 0x5A96BA4,
    HEAVY_SHOTGUN      = 0x3AABBBAA,
    -- Rifle
    ASSAULT_RIFLE      = 0xBFEFFF6D,
    ASSAULT_RIFLE_MK2  = 0x394F415C,
    CARBINE_RIFLE      = 0x83BF0278,
    CARBINE_RIFLE_MK2  = 0xFAD1F1C9,
    ADVANCED_RIFLE     = 0xAF113F99,
    SPECIAL_CARBINE    = 0xC0A3098D,
    BULLPUP_RIFLE      = 0x7F229F94,
    COMPACT_RIFLE      = 0x624FE830,
    -- Sniper
    SNIPER_RIFLE       = 0x05FC3C11,
    HEAVY_SNIPER       = 0x0C472FE2,
    HEAVY_SNIPER_MK2   = 0xA914799,
    MARKSMAN_RIFLE     = 0xC734385A,
    MARKSMAN_RIFLE_MK2 = 0x6A6C02E0,
    -- LMG
    MG                 = 0x9D07F764,
    COMBAT_MG          = 0x7FD62962,
    COMBAT_MG_MK2      = 0xDBBD7280,
    GUSENBERG_SWEEPER  = 0x61012683,
    -- Heavy
    MINIGUN            = 0x42BF8A85,
    RPG                = 0xB1CA77B1,
    GRENADE_LAUNCHER   = 0xA284510B,
    -- Melee / Unarmed
    UNARMED            = 0xA2719263,
    KNIFE              = 0x99B507EA,
    BAT                = 0x958A4A8F,
    HAMMER             = 0x4E875F73,
    FIST               = 0xA2719263,
}
