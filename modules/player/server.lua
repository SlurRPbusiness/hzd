---@meta

--#region Native Upvalue Optimization

local GetPlayerName <const>           = GetPlayerName
local GetPlayerPing <const>           = GetPlayerPing
local GetPlayerIdentifier <const>     = GetPlayerIdentifier
local GetNumPlayerIdentifiers <const> = GetNumPlayerIdentifiers
local GetPlayerToken <const>          = GetPlayerToken
local GetNumPlayerTokens <const>      = GetNumPlayerTokens
local DropPlayer <const>              = DropPlayer

--#endregion

---@class PlayerConfig
---@field maxHealth  integer   Salute massima del ped (100 = barra piena, 200 = con boost)
---@field maxArmour  integer   Armatura massima (0–100)
---@field pvp        boolean   Il giocatore partecipa al PvP

local DEFAULT_CONFIG                  = {
    maxHealth = 200,
    maxArmour = 100,
    pvp       = true,
}

local DEFAULT_SKIN = {
    model = joaat("mp_m_freemode_01"),
    components = {},
    props = {},
    loadout = {},
}

local function decodeTable(value, field)
    if value == nil then return {} end
    if type(value) == "table" then return value end

    assertType(field, value, "string")
    local decoded = json.decode(value)
    assert(type(decoded) == "table", ("stored %s must decode to a table"):format(field))
    return decoded
end

local function normalizeConfig(config)
    local maxHealth = config.maxHealth == nil and DEFAULT_CONFIG.maxHealth or config.maxHealth
    local maxArmour = config.maxArmour == nil and DEFAULT_CONFIG.maxArmour or config.maxArmour
    local pvp = config.pvp == nil and DEFAULT_CONFIG.pvp or config.pvp

    assertType("maxHealth", maxHealth, "number")
    assertType("maxArmour", maxArmour, "number")
    assertType("pvp", pvp, "boolean")
    assert(math.isFinite(maxHealth) and maxHealth > 0, "maxHealth must be a positive finite number")
    assert(math.isFinite(maxArmour) and maxArmour >= 0, "maxArmour must be a non-negative finite number")

    return { maxHealth = maxHealth, maxArmour = maxArmour, pvp = pvp }
end

local function normalizeSkin(skin)
    local model = skin.model == nil and DEFAULT_SKIN.model or skin.model
    local components = skin.components == nil and {} or skin.components
    local props = skin.props == nil and {} or skin.props
    local loadout = skin.loadout == nil and {} or skin.loadout

    assertType("skin.model", model, "integer")
    assert(type(components) == "table", "skin.components must be a table")
    assert(type(props) == "table", "skin.props must be a table")
    assert(type(loadout) == "table", "skin.loadout must be a table")

    return {
        model = model,
        components = table.clone(components),
        props = table.clone(props),
        loadout = table.clone(loadout),
    }
end

local function markDirty(self)
    self.dirty = true
    self._dataVersion = self._dataVersion + 1
end

local function readInteger(row, key, default)
    local value = row[key]
    if value == nil then return default end

    assertType(key, value, "integer")
    assert(value >= 0, ("stored %s cannot be negative"):format(key))
    return value
end

-- ─────────────────────────────────────────────────────────
--  Identifier helpers (privati al modulo)
-- ─────────────────────────────────────────────────────────

---Raccoglie tutti gli identifier del source, divisi per tipo.
---@param src integer
---@return table<string, string>
local function collectIdentifiers(src)
    local ids    = {}
    local srcStr = tostring(src)
    local count  = GetNumPlayerIdentifiers(srcStr)

    for i = 0, count - 1 do
        local raw = GetPlayerIdentifier(srcStr, i)
        if raw then
            local prefix, value = raw:match("^([^:]+):(.+)$")
            if prefix and value then
                ids[prefix] = raw
            end
        end
    end

    return ids
end

---Estrae il token primario univoco (license:xxx, poi license2, poi steam).
---Questo è l'ID fisso che non cambia tra reconnect.
---@param identifiers table<string, string>
---@return string? id
local function resolvePrimaryId(identifiers)
    return identifiers["license"]
        or identifiers["license2"]
        or identifiers["steam"]
        or identifiers["discord"]
        or identifiers["fivem"]
end

-- ─────────────────────────────────────────────────────────
--  Player class
-- ─────────────────────────────────────────────────────────

---@class PlayerMeta
---@field id          string               Identificatore fisso univoco (es. "license:abc123")
---@field source      integer              Server source (cambia ad ogni reconnect)
---@field name        string               Nome visualizzato
---@field identifiers table<string,string> Tutti gli identifier (license, steam, discord…)
---@field tokens      string[]             Token hardware del client
---@field joinedAt    integer              os.time() del join corrente
---@field lastSeen    integer              os.time() dell'ultimo aggiornamento

---@class PlayerData
---@field kills          integer
---@field deaths         integer
---@field headshots      integer
---@field matches_played integer
---@field matches_won    integer
---@field elo            integer
---@field coins          integer
---@field xp             integer
---@field level          integer

---@class PlayerSkin
---@field model      integer   Hash del modello ped (joaat)
---@field components table     { [compId]: { drawable, texture, palette } }
---@field props      table     { [propId]: { drawable, texture } }
---@field loadout    WeaponDef[] Armi al respawn

---@class player : classlib
---@field meta   PlayerMeta
---@field data   PlayerData
---@field skin   PlayerSkin
---@field config PlayerConfig
---@field dirty  boolean          True se i dati non sono stati salvati su DB
---@field setConfig fun(self: player, config: PlayerConfig): player
---@field setSkin   fun(self: player, skin: PlayerSkin): player
local player = class("player") --[[@as player]]

_ENV.player = player

-- ─────────────────────────────────────────────────────────
--  Constructor
-- ─────────────────────────────────────────────────────────

---@param src integer    Server source
---@param row? table   Riga dal DB (nil = primo accesso)
---@param cfg?   PlayerConfig  Override configurazione
function player:constructor(src, row, cfg)
    assertType("src", src, "integer")
    assert(src > 0, "player source must be > 0")
    assert(row == nil or type(row) == "table", "row must be a table")
    assert(cfg == nil or type(cfg) == "table", "cfg must be a table")
    row = row or {}

    local srcStr      = tostring(src)
    local identifiers = collectIdentifiers(src)
    local primaryId   = resolvePrimaryId(identifiers)

    assert(primaryId, ("player %d: impossibile determinare un identifier primario"):format(src))

    local tokens     = {}
    local tokenCount = GetNumPlayerTokens(srcStr)
    for i = 0, tokenCount - 1 do
        tokens[i + 1] = GetPlayerToken(srcStr, i)
    end

    -- ── meta ────────────────────────────────────────────
    self.meta = {
        id          = primaryId,
        source      = src,
        name        = GetPlayerName(srcStr),
        identifiers = identifiers,
        tokens      = tokens,
        joinedAt    = os.time(),
        lastSeen    = os.time(),
    }

    self.data = {
        kills          = readInteger(row, "kills", 0),
        deaths         = readInteger(row, "deaths", 0),
        headshots      = readInteger(row, "headshots", 0),
        matches_played = readInteger(row, "matches_played", 0),
        matches_won    = readInteger(row, "matches_won", 0),
        elo            = readInteger(row, "elo", 1000),
        coins          = readInteger(row, "coins", 0),
        xp             = readInteger(row, "xp", 0),
        level          = readInteger(row, "level", 1),
    }

    self.skin = normalizeSkin(decodeTable(row.skin, "skin"))

    -- `settings` is the column created by the resource SQL schema.
    local rawCfg = table.clone(decodeTable(row.settings, "settings"))

    if cfg then
        for k, v in pairs(cfg) do rawCfg[k] = v end
    end

    self.config = normalizeConfig(rawCfg)

    self.dirty = false
    self._dataVersion = 0
end

-- ─────────────────────────────────────────────────────────
--  Meta helpers
-- ─────────────────────────────────────────────────────────

---Restituisce l'ID fisso univoco del giocatore (non il source).
---@return string
function player:getId()
    return self.meta.id
end

---Restituisce il server source attuale.
---@return integer
function player:getSource()
    return self.meta.source
end

---Aggiorna il source dopo una reconnect (stesso license, nuovo source).
---@param newSrc integer
function player:updateSource(newSrc)
    assertType("newSrc", newSrc, "integer")
    self.meta.source   = newSrc
    self.meta.name     = GetPlayerName(tostring(newSrc)) or self.meta.name
    self.meta.lastSeen = os.time()
end

---Restituisce il ping corrente del giocatore.
---@return integer
function player:getPing()
    return GetPlayerPing(tostring(self.meta.source))
end

function player:setConfig(config)
    assertType("config", config, "table")
    self.config = normalizeConfig(config)
    markDirty(self)
    return self
end

function player:setSkin(skin)
    assertType("skin", skin, "table")
    self.skin = normalizeSkin(skin)
    markDirty(self)
    return self
end

---Espelle il giocatore dal server.
---@param reason? string
function player:kick(reason)
    DropPlayer(tostring(self.meta.source), reason or "Kicked")
end

function player:getKd()
    return self.data.kills / math.max(self.data.deaths, 1)
end

function player:syncClient()
    local stats = {}
    for key, value in pairs(self.data) do stats[key] = value end
    stats.kd = self:getKd()
    sendEvent("client", self.meta.source, "player:syncStats", stats)
end

function player:addDeath()
    self.data.deaths = self.data.deaths + 1
    markDirty(self)
    self:syncClient()
end

function player:addKill(isHeadshot)
    self.data.kills = self.data.kills + 1
    if isHeadshot == true then self.data.headshots = self.data.headshots + 1 end
    markDirty(self)
    self:syncClient()
end

function player:addMatchResult(won)
    self.data.matches_played = self.data.matches_played + 1
    if won then self.data.matches_won = self.data.matches_won + 1 end
    markDirty(self)
    self:syncClient()
end

-- Un solo salvataggio per identifier, anche tra disconnessione e riconnessione.
local saving = {}

function player:save()
    if not sql.isReady() then return false end

    local id = self.meta.id
    while saving[id] do Wait(0) end
    if not self.dirty then return true end
    if not sql.isReady() then return false end
    saving[id] = true

    local ok, result = pcall(function()
        local data = self.data
        local version = self._dataVersion
        local settings = json.encode(self.config)
        local skin = json.encode(self.skin)
        assert(type(settings) == "string" and type(skin) == "string", "player data serialization failed")
        local params = {
            self.meta.name, data.kills, data.deaths, data.headshots,
            data.matches_played, data.matches_won, data.elo, data.coins, data.xp, data.level,
            settings, skin, id,
        }
        local affected = sql.update([[
            UPDATE `hzd_users` SET `name` = ?, `kills` = ?, `deaths` = ?,
                `headshots` = ?, `matches_played` = ?, `matches_won` = ?,
                `elo` = ?, `coins` = ?, `xp` = ?, `level` = ?, `settings` = ?, `skin` = ?
            WHERE `identifier` = ?;
        ]], params)
        if affected == nil or affected < 0 then return false end
        if affected == 0 and not sql.single("SELECT `identifier` FROM `hzd_users` WHERE `identifier` = ? LIMIT 1;", { id }) then
            return false
        end

        if self._dataVersion == version and self.meta.name == params[1] and data.kills == params[2]
            and data.deaths == params[3] and data.headshots == params[4]
            and data.matches_played == params[5] and data.matches_won == params[6]
            and data.elo == params[7] and data.coins == params[8]
            and data.xp == params[9] and data.level == params[10]
            and json.encode(self.config) == params[11] and json.encode(self.skin) == params[12] then
            self.dirty = false
        end
        return true
    end)
    saving[id] = nil
    if not ok or not result then
        print.error("[PLAYER] Salvataggio fallito per %s: %s", id, tostring(result))
    end
    return ok and result
end
