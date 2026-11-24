---@meta

--#region Types

---@alias DiscordInfo { id: string, username: string, avatar: string, banner: string }

---@class ModeStats
---@field kills integer
---@field deaths integer
---@field kd number
---@field elo integer
---@field headshots integer
---@field played integer
---@field wins integer

---@class PlayerMetadata
---@field coins integer
---@field xp integer
---@field level integer
---@field playtime integer
---@field roles string[]
---@field discord DiscordInfo
---@field skin table
---@field pvp ModeStats
---@field match ModeStats
---@field freeroam ModeStats
---@field total ModeStats

---@class Player : classlib
---@field name string
---@field id string
---@field userId integer
---@field source integer
---@field metadata PlayerMetadata
---@field new fun(src?: integer, row?: table): Player
---@field setMetadata fun(key: string, value: any)
local Player = class("Player") --[[@as Player]]

_G.Player    = Player
_G.User      = Player

--#endregion

--#region Helpers

local function defaultStats()
    return {
        kills = 0,
        deaths = 0,
        kd = 0.0,
        elo = 1000,
        headshots = 0,
        played = 0,
        wins = 0,
    }
end

--#endregion

--#region Constructor

function Player:constructor()
    self.name     = ""
    self.id       = ""
    self.userId   = 0
    self.source   = 0
    self.metadata = {
        coins    = 0,
        xp       = 0,
        level    = 1,
        playtime = 0,
        roles    = {},
        discord  = { id = "", username = "", avatar = "", banner = "" },
        skin     = {},
        pvp      = defaultStats(),
        match    = defaultStats(),
        freeroam = defaultStats(),
        total    = defaultStats(),
    }
end

--#endregion

--#region Metadata

function Player:getMetadata(key)
    return key and self.metadata[key] or self.metadata
end

function Player:hasRole(names)
    local roles = self.metadata.roles
    if not roles or #roles == 0 then return false end

    if type(names) == "string" then
        return table.contains(roles, names)
    end

    return table.some(roles, function(role)
        return table.contains(names, role)
    end)
end

function Player:hasPermission(names)
    return self:hasRole(names)
end

function Player:getAvatarUrl(size)
    local discord = self.metadata.discord
    if not discord or string.isBlank(discord.id) or string.isBlank(discord.avatar) then
        return ""
    end
    return string.fmt("https://cdn.discordapp.com/avatars/%s/%s.webp?size=%d", discord.id, discord.avatar, size or 1024)
end

--#endregion

--#region Stats

function Player:getModeStats(mode)
    mode = mode or "pvp"
    if not self.metadata[mode] then
        self.metadata[mode] = defaultStats()
    end
    return self.metadata[mode]
end

function Player:getKd(mode)
    local stats = self:getModeStats(mode)
    return stats.deaths == 0 and stats.kills or math.round(stats.kills / stats.deaths, 1)
end

function Player:updateStats(mode, stats)
    mode = mode or "pvp"
    local target = self:getModeStats(mode)

    if type(stats) == "table" then
        table.each(stats, function(val, key)
            if target[key] and type(val) == "number" then
                target[key] = math.clamp(target[key] + val, 0, math.huge)
            end
        end)
    end

    target.kd = target.deaths == 0 and target.kills or math.round(target.kills / target.deaths, 1)

    local eloDelta = ((stats.kills or 0) * 15) + ((stats.headshots or 0) * 5) - ((stats.deaths or 0) * 12)
    target.elo = math.clamp(target.elo + eloDelta, 100, math.huge)

    if hzd:is("server") and self.setMetadata then
        self:setMetadata(mode, target)
    end

    return target
end

--#endregion
