---@meta

--#region Upvalues

local PlayerPedId                 <const> = PlayerPedId
local PlayerId                    <const> = PlayerId
local GetPlayerServerId           <const> = GetPlayerServerId
local GetCurrentPedWeapon         <const> = GetCurrentPedWeapon
local GetVehiclePedIsIn           <const> = GetVehiclePedIsIn
local NetworkGetEntityIsNetworked <const> = NetworkGetEntityIsNetworked
local SetEntityAsMissionEntity    <const> = SetEntityAsMissionEntity
local DeleteVehicle               <const> = DeleteVehicle
local SetPedConfigFlag            <const> = SetPedConfigFlag
local SetPedCanBeTargetted        <const> = SetPedCanBeTargetted
local SetPedDiesInWater           <const> = SetPedDiesInWater
local SetPedDropsWeaponsWhenDead  <const> = SetPedDropsWeaponsWhenDead
local SetWeaponsNoAutoswap        <const> = SetWeaponsNoAutoswap
local SetPedAccuracy              <const> = SetPedAccuracy
local SetAimCooldown              <const> = SetAimCooldown
local StatSetInt                  <const> = StatSetInt
local joaat                       <const> = joaat
local GetEntityCoords             <const> = GetEntityCoords
local GetWorldPositionOfEntityBone <const> = GetWorldPositionOfEntityBone
local GetPedBoneIndex             <const> = GetPedBoneIndex
local IsPedFalling                <const> = IsPedFalling
local IsEntityPlayingAnim         <const> = IsEntityPlayingAnim
local IsPedOnFoot                 <const> = IsPedOnFoot
local GetPedMovementClipset       <const> = GetPedMovementClipset
local SetDiscordAppId             <const> = SetDiscordAppId
local SetDiscordRichPresenceAsset <const> = SetDiscordRichPresenceAsset
local SetRichPresence             <const> = SetRichPresence
local SetDiscordRichPresenceAction <const> = SetDiscordRichPresenceAction

local DISCORD_APP_ID <const> = "1335624385138266174"
local HASH_CROUCHED  <const> = `move_ped_crouched`

--#endregion

--#region Types

---@class Player
---@field ped         integer
---@field playerId    integer
---@field tick        Interval?
---@field weapon      integer | false
---@field inSSControl boolean

--#endregion

--#region Constructor

local _baseCtor = Player.constructor

function Player:constructor()
    _baseCtor(self)

    self.playerId    = PlayerId()
    self.source      = GetPlayerServerId(self.playerId)
    self.ped         = PlayerPedId()
    self.weapon      = false
    self.inSSControl = false
    self.tick        = nil

    local initialMeta = state.get("local", "metadata")
    if initialMeta then
        self.metadata = table.clone(initialMeta)
    end
    self.name   = state.get("local", "name", self.name)
    self.userId = state.get("local", "userId", self.userId)

    self:startTick()
end

--#endregion

--#region State Synchronization

state.listenLocal("metadata", function(newMeta)
    if type(newMeta) == "table" and _G.LocalPlayer then
        _G.LocalPlayer.metadata = table.clone(newMeta)
    end
end)

state.listenLocal("userId", function(newId)
    if newId and _G.LocalPlayer then
        _G.LocalPlayer.userId = newId
    end
end)

--#endregion

--#region Tick

function Player:startTick()
    if self.tick and self.tick:isActive() then return end

    self.tick = interval(250, function()
        self.ped = PlayerPedId()

        local hasWeapon, currentWeapon = GetCurrentPedWeapon(self.ped, true)
        self.weapon = hasWeapon and currentWeapon or false

        local vehicle = GetVehiclePedIsIn(self.ped, false)
        if vehicle ~= 0 and not NetworkGetEntityIsNetworked(vehicle) then
            SetEntityAsMissionEntity(vehicle, true, true)
            DeleteVehicle(vehicle)
        end
    end)
end

function Player:stopTick()
    if self.tick then
        self.tick:stop()
        self.tick = nil
    end
end

--#endregion

--#region Ped

function Player:updatePed()
    self.ped = PlayerPedId()

    SetPedConfigFlag(self.ped, 153, true)
    SetPedConfigFlag(self.ped, 427, true)
    SetPedCanBeTargetted(self.ped, false)
    SetPedDiesInWater(self.ped, false)
    SetPedDropsWeaponsWhenDead(self.ped, false)
    SetWeaponsNoAutoswap(true)

    StatSetInt(`MP0_STAMINA`, 100, true)
    StatSetInt(`MP0_SHOOTING_ABILITY`, 100, true)

    for i = 0, 3 do
        StatSetInt(joaat(string.fmt("mp%d_shooting_ability", i)), 100, true)
        StatSetInt(joaat(string.fmt("sp%d_shooting_ability", i)), 100, true)
    end

    SetPedAccuracy(self.ped, 100)
    SetAimCooldown(0)
end

function Player:isInRolas()
    local ped = self.ped
    return GetEntityCoords(ped).z
            > GetWorldPositionOfEntityBone(ped, GetPedBoneIndex(ped, 31086)).z
        and not IsPedFalling(ped)
        and not IsEntityPlayingAnim(ped, "core", "base", 3)
        and IsPedOnFoot(ped)
        and GetPedConfigFlag(ped, 78)
        and GetPedMovementClipset(ped) ~= HASH_CROUCHED
end

--#endregion

--#region SS Control

function Player:openSSControl()
    self.inSSControl = true
    nui.setFocus(true, true)
    nui.send("controlRequest:open", {
        myName = string.fmt("%s#%d", self.name, self.userId)
    })
    NetworkStartSoloTutorialSession()
end

function Player:closeSSControl()
    self.inSSControl = false
    nui.removeFocus()
    nui.send("controlRequest:close")
    NetworkEndTutorialSession()
end

--#endregion

--#region Presence

function Player:setPresence(presenceKey)
    assertType("presenceKey", presenceKey, "string")
    SetDiscordAppId(DISCORD_APP_ID)
    SetDiscordRichPresenceAsset("fmlpvp")
    SetRichPresence(locale.get(presenceKey))
    SetDiscordRichPresenceAction(0, locale.get("richpresence_button_1"), "https://discord.gg/fmlpvp")
    SetDiscordRichPresenceAction(1, locale.get("richpresence_button_2"), "https://cfx.re/join/djkpgd")
end

--#endregion

--#region Info

function Player:getUserInfo(mode)
    local meta = self.metadata
    local currentStats = self:getModeStats(mode or "pvp")

    return {
        id       = self.userId,
        name     = self.name,
        avatar   = self:getAvatarUrl(),
        coins    = meta.coins,
        xp       = meta.xp,
        level    = meta.level,
        roles    = table.clone(meta.roles),
        playtime = meta.playtime,
        kills    = currentStats.kills,
        deaths   = currentStats.deaths,
        kd       = self:getKd(mode),
        elo      = currentStats.elo,
        language = locale.current,
        stats    = {
            pvp      = meta.pvp,
            match    = meta.match,
            freeroam = meta.freeroam,
            total    = meta.total,
        },
    }
end

--#endregion

--#region Events

createEvent("player:openSSControl", function()
    LocalPlayer:openSSControl()
end)

createEvent("player:closeSSControl", function()
    LocalPlayer:closeSSControl()
end)

createEvent("player:refreshInfo", function()
    nui.send("menu:setData", { myInfo = LocalPlayer:getUserInfo() })
end)

--#endregion

--#region Singleton

---@type Player
_G.LocalPlayer = Player.new()
_G.LocalUser   = _G.LocalPlayer

--#endregion
