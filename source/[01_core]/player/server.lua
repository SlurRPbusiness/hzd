---@meta

--#region Upvalues

local GetPlayerName           <const> = GetPlayerName
local GetPlayerPing           <const> = GetPlayerPing
local GetPlayerIdentifier     <const> = GetPlayerIdentifier
local GetNumPlayerIdentifiers <const> = GetNumPlayerIdentifiers
local GetPlayerToken          <const> = GetPlayerToken
local GetNumPlayerTokens      <const> = GetNumPlayerTokens
local DropPlayer              <const> = DropPlayer
local os_time                 <const> = os.time

--#endregion

--#region Helpers

local function collectIdentifiers(src)
    local ids    = {}
    local srcStr = tostring(src)
    for i = 0, GetNumPlayerIdentifiers(srcStr) - 1 do
        local raw = GetPlayerIdentifier(srcStr, i)
        if raw then
            local prefix = raw:match("^([^:]+):")
            if prefix then ids[prefix] = raw end
        end
    end
    return ids
end

local function resolvePrimaryId(ids)
    return ids["license"] or ids["license2"] or ids["steam"] or ids["discord"] or ids["fivem"]
end

local function readInt(row, key, default)
    local v = tonumber(row[key])
    return (v and v >= 0) and math.floor(v) or default
end

local function decodeTable(value)
    if type(value) == "table" then return value end
    if type(value) == "string" then
        local ok, res = pcall(json.decode, value)
        if ok and type(res) == "table" then return res end
    end
    return {}
end

local function loadModeStats(savedData, flatRow)
    savedData = savedData or {}
    flatRow   = flatRow or {}

    local kills  = savedData.kills or readInt(flatRow, "kills", 0)
    local deaths = savedData.deaths or readInt(flatRow, "deaths", 0)

    return {
        kills     = kills,
        deaths    = deaths,
        kd        = deaths == 0 and kills or math.round(kills / deaths, 1),
        elo       = savedData.elo or readInt(flatRow, "elo", 1000),
        headshots = savedData.headshots or readInt(flatRow, "headshots", 0),
        played    = savedData.played or readInt(flatRow, "matches_played", 0),
        wins      = savedData.wins or readInt(flatRow, "matches_won", 0),
    }
end

--#endregion

--#region Types

---@class Player
---@field identifiers table<string, string>
---@field tokens      string[]
---@field joinedAt    integer
---@field dirty       boolean

--#endregion

--#region Constructor

local _baseCtor = Player.constructor

function Player:constructor(src, row)
    _baseCtor(self)

    assertType("src", src, "integer")
    row = row or {}

    local srcStr      = tostring(src)
    local identifiers = collectIdentifiers(src)
    local primaryId   = resolvePrimaryId(identifiers)
    assert(primaryId, string.fmt("player %d: missing primary identifier", src))

    local tokens = {}
    for i = 0, GetNumPlayerTokens(srcStr) - 1 do
        tokens[i + 1] = GetPlayerToken(srcStr, i)
    end

    self.source      = src
    self.id          = primaryId
    self.name        = GetPlayerName(srcStr) or "Unknown"
    self.userId      = readInt(row, "userId", readInt(row, "id", 0))
    self.identifiers = identifiers
    self.tokens      = tokens
    self.joinedAt    = os_time()
    self.dirty       = false

    local discordData = decodeTable(row.discord)
    if not discordData.id and identifiers["discord"] then
        discordData.id = identifiers["discord"]:gsub("^discord:", "")
    end

    local rawSettings = decodeTable(row.settings)
    local rawStats    = decodeTable(row.statistics)

    self.metadata = {
        coins    = readInt(row, "coins", 0),
        xp       = readInt(row, "xp", 0),
        level    = readInt(row, "level", 1),
        playtime = readInt(row, "playtime", 0),
        roles    = decodeTable(row.roles),
        discord  = discordData,
        skin     = decodeTable(row.skin),
        pvp      = loadModeStats(rawStats.pvp or rawSettings.pvp, row),
        match    = loadModeStats(rawStats.match or rawSettings.match, {}),
        freeroam = loadModeStats(rawStats.freeroam or rawSettings.freeroam, {}),
        total    = loadModeStats(rawStats.total or rawSettings.total, row),
    }

    self:syncState()
end

--#endregion

--#region State & Sync

function Player:syncState()
    state.set(self.source, "metadata", self.metadata, true)
    state.set(self.source, "userId", self.userId, true)
    state.set(self.source, "name", self.name, true)
end

function Player:setMetadata(key, value)
    assertType("key", key, "string")
    self.metadata[key] = value
    self.dirty = true
    state.set(self.source, "metadata", self.metadata, true)
end

function Player:updateMetadata(updates)
    assertType("updates", updates, "table")
    table.each(updates, function(v, k)
        self.metadata[k] = v
    end)
    self.dirty = true
    state.set(self.source, "metadata", self.metadata, true)
end

--#endregion

--#region Actions

function Player:addCoins(amount)
    assertType("amount", amount, "integer")
    self:setMetadata("coins", math.clamp(self.metadata.coins + amount, 0, math.huge))
end

function Player:addXp(amount)
    assertType("amount", amount, "integer")
    self:setMetadata("xp", math.clamp(self.metadata.xp + amount, 0, math.huge))
end

function Player:addKill(mode, isHeadshot)
    self:updateStats(mode or "pvp", {
        kills     = 1,
        headshots = isHeadshot and 1 or 0,
    })
end

function Player:addDeath(mode)
    self:updateStats(mode or "pvp", { deaths = 1 })
end

function Player:addMatchResult(mode, won)
    self:updateStats(mode or "match", {
        played = 1,
        wins   = won and 1 or 0,
    })
end

function Player:setRoles(roles)
    assertType("roles", roles, "table")
    self:setMetadata("roles", table.clone(roles))
end

function Player:getPing()
    return GetPlayerPing(tostring(self.source))
end

function Player:kick(reason)
    DropPlayer(tostring(self.source), reason or "Kicked")
end

--#endregion

--#region Save

local _saving = {}

function Player:save()
    if not sql.isReady() then return false end

    local id = self.id
    while _saving[id] do Wait(0) end
    if not self.dirty then return true end
    if not sql.isReady() then return false end
    _saving[id] = true

    local ok, result = pcall(function()
        local m = self.metadata
        local total = m.total or m.pvp

        local affected = sql.update([[
            UPDATE `hzd_users`
               SET `name`           = ?,
                   `coins`          = ?,
                   `xp`             = ?,
                   `level`          = ?,
                   `playtime`       = ?,
                   `kills`          = ?,
                   `deaths`         = ?,
                   `headshots`      = ?,
                   `matches_played` = ?,
                   `matches_won`    = ?,
                   `elo`            = ?,
                   `skin`           = ?,
                   `settings`       = ?
             WHERE `identifier`     = ?;
        ]], {
            self.name,
            m.coins,
            m.xp,
            m.level,
            m.playtime,
            total.kills,
            total.deaths,
            total.headshots,
            total.played,
            total.wins,
            total.elo,
            json.encode(m.skin),
            json.encode({
                roles    = m.roles,
                discord  = m.discord,
                pvp      = m.pvp,
                match    = m.match,
                freeroam = m.freeroam,
                total    = m.total,
            }),
            id,
        })

        if not affected or affected < 0 then return false end
        self.dirty = false
        return true
    end)

    _saving[id] = nil
    if not ok or not result then
        print.error("[Player] Save failed for %s: %s", id, tostring(result))
    end
    return ok and result
end

--#endregion

--#region Registry

local _registry = {}

_G.Players = {}
_G.Users   = _G.Players

function Players.get(src) return _registry[src] end
function Players.all() return _registry end

function Players.add(src, row)
    local p = Player.new(src, row) --[[@as Player]]
    _registry[src] = p
    print.info("[Players] Initialized %s (%d)", p.name, src)
    return p
end

function Players.remove(src)
    local p = _registry[src]
    if p then
        _registry[src] = nil
    end
    return p
end

function Players.find(cb)
    return table.find(_registry, cb)
end

function Players.count()
    return table.size(_registry)
end

--#endregion

--#region Events & Callbacks

AddEventHandler("playerDropped", function()
    local src = source ---@diagnostic disable-line
    local p   = Players.get(src)
    if p then p:save() end
    Players.remove(src)
end)

local _actions = {
    getInfo = function(_, p, mode)
        return p:getMetadata(mode)
    end,

    hasPermission = function(_, p, names)
        return p:hasRole(names)
    end,

    updateStats = function(_, p, mode, stats)
        return p:updateStats(mode, stats)
    end,
}

callback.registerServer("player", function(src, action, ...)
    assertType("action", action, "string")
    local p = Players.get(src)
    if not p then return nil end

    local handler = _actions[action]
    if not handler then return nil end

    return handler(src, p, ...)
end)

--#endregion
