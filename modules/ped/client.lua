---@meta

--#region Native Upvalue Optimization

local FreezeEntityPosition <const>                  = FreezeEntityPosition
local SetEntityInvincible <const>                   = SetEntityInvincible
local SetPedCanRagdoll <const>                      = SetPedCanRagdoll
local GetEntityFromStateBagName <const>             = GetEntityFromStateBagName
local DoesEntityExist <const>                       = DoesEntityExist
local GetEntityType <const>                         = GetEntityType
local CreatePed <const>                             = CreatePed
local SetModelAsNoLongerNeeded <const>              = SetModelAsNoLongerNeeded
local PlayerPedId <const>                           = PlayerPedId
local GetPlayerPed <const>                          = GetPlayerPed
local NetworkDoesEntityExistWithNetworkId <const>   = NetworkDoesEntityExistWithNetworkId
local NetworkGetEntityFromNetworkId <const>         = NetworkGetEntityFromNetworkId
local NetworkGetPlayerIndexFromPed <const>          = NetworkGetPlayerIndexFromPed
local GetPlayerServerId <const>                     = GetPlayerServerId
local SetEntityCoords <const>                       = SetEntityCoords
local SetPedConfigFlag <const>                      = SetPedConfigFlag
local ClearPedTasksImmediately <const>              = ClearPedTasksImmediately
local ClearPedTasks <const>                         = ClearPedTasks
local TaskPlayAnim <const>                          = TaskPlayAnim
local RemoveAnimDict <const>                        = RemoveAnimDict
local SetPedComponentVariation <const>              = SetPedComponentVariation
local ClearPedProp <const>                          = ClearPedProp
local SetEntityAsMissionEntity <const>              = SetEntityAsMissionEntity
local DeleteEntity <const>                          = DeleteEntity

--#endregion

---@class ped
---@field fromPlayer fun(self: ped, playerIndex?: integer): ped?
---@field getPlayerServerId fun(self: ped): integer?
---@field setCoords fun(self: ped, coords: vector3|vector4|table, clearArea?: boolean): ped
---@field delete fun(self: ped): boolean
---@field setFreeze fun(self: ped, toggle: boolean): ped
---@field setInvincibility fun(self: ped, toggle: boolean): ped
---@field setInvincible fun(self: ped, toggle: boolean): ped
---@field disableTarget fun(self: ped, toggle: boolean): ped
---@field setCanRagdoll fun(self: ped, toggle: boolean): ped
---@field clearTasks fun(self: ped, immediately?: boolean): ped
---@field playAnimation fun(self: ped, dictionary: string, animation: string, duration?: integer, flags?: integer, playbackRate?: number): ped
---@field setComponentVariation fun(self: ped, componentId: integer, drawableId: integer, textureId: integer, paletteId?: integer): ped
---@field clearProp fun(self: ped, propId: integer): ped

--#region Server State Synchronization

local stateHandlers = {
    [ped.stateKeys.freeze] = function(handle, value)
        if type(value) == "boolean" then
            FreezeEntityPosition(handle, value)
        end
    end,
    [ped.stateKeys.invincible] = function(handle, value)
        if type(value) == "boolean" then
            SetEntityInvincible(handle, value)
        end
    end,
    [ped.stateKeys.canRagdoll] = function(handle, value)
        if type(value) == "boolean" then
            SetPedCanRagdoll(handle, value)
        end
    end,
}

for stateKey, apply in pairs(stateHandlers) do
    local applySetting = apply

    AddStateBagChangeHandler(stateKey, nil, function(bagName, _, value)
        Citizen.CreateThread(function()
            local started = GetGameTimer()
            local handle = GetEntityFromStateBagName(bagName)

            while (handle == 0 or not DoesEntityExist(handle)) and GetGameTimer() - started < 10000 do
                Wait(100)
                handle = GetEntityFromStateBagName(bagName)
            end

            if handle == 0 or not DoesEntityExist(handle) or GetEntityType(handle) ~= 1 then
                return
            end

            if Entity(handle).state[stateKey] == value then
                applySetting(handle, value)
            end
        end)
    end)
end

--#endregion

--#region Creation and Lookup

---Crea un ped sul client e applica i valori iniziali di data.
---@param model string|integer
---@param data pedCreateData
---@return ped
function ped:create(model, data, legacyScriptHostPed)
    if not data or not data.coords then return {} end
    local modelHash, x, y, z, heading, options = self:normalizeSpawn(model, data.coords, data, legacyScriptHostPed)

    assert(options.routingBucket == nil, "routingBucket can only be set on the server")

    modelHash = requestModel(modelHash)

    local handle = CreatePed(
        0,
        modelHash,
        x,
        y,
        z,
        heading,
        options.networked,
        options.scriptHostPed
    )

    SetModelAsNoLongerNeeded(modelHash)

    if handle == 0 then
        error(("failed to create ped with model %s"):format(tostring(model)), 2)
    end

    local instance = self.new(handle)

    instance:setFreeze(options.freeze)
    instance:setInvincibility(options.invincible)
    instance:setCanRagdoll(options.canRagdoll)

    if options.health ~= nil then
        instance:setHealth(options.health)
    end

    if options.armour ~= nil then
        instance:setArmour(options.armour)
    end

    return instance
end

---Recupera il ped di un player index client; senza argomenti restituisce il player locale.
---@param playerIndex? integer
---@return ped?
function ped:fromPlayer(playerIndex)
    local handle

    if playerIndex == nil then
        handle = PlayerPedId()
    else
        assertType(1, playerIndex, "integer")
        handle = GetPlayerPed(playerIndex)
    end

    return self:fromHandle(handle)
end

---Recupera un ped dal network ID se l'entità è nello scope di questo client.
---@param networkId integer
---@return ped?
function ped:fromNetworkId(networkId)
    assertType(1, networkId, "integer")

    if networkId <= 0 or not NetworkDoesEntityExistWithNetworkId(networkId) then
        return nil
    end

    return self:fromHandle(NetworkGetEntityFromNetworkId(networkId))
end

---Restituisce il server ID del player associato al ped, oppure nil se non è un player.
---@return integer?
function ped:getPlayerServerId()
    self:assertValid()

    local playerIndex = NetworkGetPlayerIndexFromPed(self.handle)

    if playerIndex == -1 then
        return nil
    end

    return GetPlayerServerId(playerIndex)
end

--#endregion

--#region Client Entity Control

---Sposta il ped alle coordinate specificate.
---@param coords vector3|vector4|table
---@param clearArea? boolean
---@return ped
function ped:setCoords(coords, clearArea)
    local x, y, z = self:normalizeCoords(coords)
    self:assertValid()

    if clearArea == nil then
        clearArea = false
    end

    assertType("clearArea", clearArea, "boolean")
    SetEntityCoords(self.handle, x, y, z, false, false, false, clearArea)

    return self
end

---Blocca o sblocca il ped.
---@param toggle boolean
---@return ped
function ped:setFreeze(toggle)
    assertType("toggle", toggle, "boolean")
    self:assertValid()

    FreezeEntityPosition(self.handle, toggle)
    return self
end

---Imposta o rimuove l'invulnerabilità.
---@param toggle boolean
---@return ped
function ped:setInvincibility(toggle)
    assertType("toggle", toggle, "boolean")
    self:assertValid()

    SetEntityInvincible(self.handle, toggle)
    return self
end

---Alias compatibile di setInvincibility.
---@param toggle boolean
---@return ped
function ped:setInvincible(toggle)
    return self:setInvincibility(toggle)
end

function ped:disableTarget(toggle)
    SetPedConfigFlag(self.handle, 9, toggle)
    SetPedConfigFlag(self.handle, 214, toggle)
    SetPedConfigFlag(self.handle, 1, toggle)

    return self
end

---Abilita o disabilita il ragdoll.
---@param toggle boolean
---@return ped
function ped:setCanRagdoll(toggle)
    assertType("toggle", toggle, "boolean")
    self:assertValid()

    SetPedCanRagdoll(self.handle, toggle)
    return self
end

---Rimuove i task attivi.
---@param immediately? boolean
---@return ped
function ped:clearTasks(immediately)
    if immediately == nil then
        immediately = false
    end

    assertType("immediately", immediately, "boolean")
    self:assertValid()

    if immediately then
        ClearPedTasksImmediately(self.handle)
    else
        ClearPedTasks(self.handle)
    end

    return self
end

---Riproduce un'animazione dopo aver caricato il dizionario richiesto.
---@param dictionary string
---@param animation string
---@param duration? integer
---@param flags? integer
---@param playbackRate? number
---@return ped
function ped:playAnimation(dictionary, animation, duration, flags, playbackRate)
    assertType("dictionary", dictionary, "string")
    assertType("animation", animation, "string")
    self:assertValid()

    duration = duration or -1
    flags = flags or 0
    playbackRate = playbackRate or 1.0

    assertType("duration", duration, "integer")
    assertType("flags", flags, "integer")
    assertType("playbackRate", playbackRate, "number")

    requestAnimDict(dictionary)

    TaskPlayAnim(
        self.handle,
        dictionary,
        animation,
        8.0,
        -8.0,
        duration,
        flags,
        playbackRate,
        false,
        false,
        false
    )

    RemoveAnimDict(dictionary)
    return self
end

---Imposta un componente di abbigliamento.
---@param componentId integer
---@param drawableId integer
---@param textureId integer
---@param paletteId? integer
---@return ped
function ped:setComponentVariation(componentId, drawableId, textureId, paletteId)
    assertType("componentId", componentId, "integer")
    assertType("drawableId", drawableId, "integer")
    assertType("textureId", textureId, "integer")
    paletteId = paletteId or 0
    assertType("paletteId", paletteId, "integer")
    self:assertValid()

    SetPedComponentVariation(self.handle, componentId, drawableId, textureId, paletteId)
    return self
end

---Rimuove un prop dal ped.
---@param propId integer
---@return ped
function ped:clearProp(propId)
    assertType("propId", propId, "integer")
    self:assertValid()

    ClearPedProp(self.handle, propId)
    return self
end

---Elimina il ped dal client e invalida il wrapper.
---@return boolean
function ped:delete()
    self:assertValid()

    local handle = self.handle

    SetEntityAsMissionEntity(handle, true, true)
    DeleteEntity(handle)

    if DoesEntityExist(handle) then
        return false
    end

    self.handle = 0
    return true
end

--#endregion
