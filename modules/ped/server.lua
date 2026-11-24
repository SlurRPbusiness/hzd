---@meta

---@class ped
---@field fromPlayer fun(self: ped, source: integer|string): ped?
---@field getOwner fun(self: ped): integer
---@field getRoutingBucket fun(self: ped): integer
---@field setRoutingBucket fun(self: ped, bucket: integer): ped
---@field setCoords fun(self: ped, coords: vector3|vector4|table, clearArea?: boolean): ped
---@field setFreeze fun(self: ped, toggle: boolean): ped
---@field setInvincibility fun(self: ped, toggle: boolean): ped
---@field setInvincible fun(self: ped, toggle: boolean): ped
---@field setCanRagdoll fun(self: ped, toggle: boolean): ped
---@field delete fun(self: ped): boolean

local function replicateSetting(handle, key, value)
    Entity(handle).state:set(key, value, true)
end

--#region Creation and Lookup

---Crea un ped sul server e replica le impostazioni iniziali ai client nello scope.
---I campi freeze, invincible e canRagdoll vengono sincronizzati tramite state bag.
---@param model string|integer
---@param data pedCreateData
---@return ped
function ped:create(model, data, legacyScriptHostPed)
    if not data or not data.coords then return {} end
    local modelHash, x, y, z, heading, options = self:normalizeSpawn(model, data.coords, data, legacyScriptHostPed)

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

    if handle == 0 then
        error(("failed to create server ped with model %s"):format(tostring(model)), 2)
    end

    local instance = self.new(handle)

    if options.routingBucket ~= nil then
        instance:setRoutingBucket(options.routingBucket)
    end

    replicateSetting(handle, ped.stateKeys.freeze, options.freeze)
    replicateSetting(handle, ped.stateKeys.invincible, options.invincible)
    replicateSetting(handle, ped.stateKeys.canRagdoll, options.canRagdoll)

    FreezeEntityPosition(handle, options.freeze)
    SetPedCanRagdoll(handle, options.canRagdoll)

    if options.health ~= nil then
        instance:setHealth(options.health)
    end

    if options.armour ~= nil then
        instance:setArmour(options.armour)
    end

    return instance
end

---Recupera il ped associato al server ID del player.
---@param source integer|string
---@return ped?
function ped:fromPlayer(source)
    assertType(1, source, "integer|string")

    local playerId = tonumber(source)

    if not playerId then
        return nil
    end

    return self:fromHandle(GetPlayerPed(playerId))
end

---Risolve un network ID nell'entity handle server.
---@param networkId integer
---@return ped?
function ped:fromNetworkId(networkId)
    assertType(1, networkId, "integer")

    if networkId <= 0 then
        return nil
    end

    return self:fromHandle(NetworkGetEntityFromNetworkId(networkId))
end

--#endregion

--#region Server Entity Control

---Restituisce il server ID del client che possiede l'entità; -1 indica un ped senza owner.
---@return integer
function ped:getOwner()
    self:assertValid()
    return NetworkGetEntityOwner(self.handle)
end

---Restituisce il routing bucket del ped.
---@return integer
function ped:getRoutingBucket()
    self:assertValid()
    return GetEntityRoutingBucket(self.handle)
end

---Sposta il ped in un routing bucket.
---@param bucket integer
---@return ped
function ped:setRoutingBucket(bucket)
    assertType("bucket", bucket, "integer")
    assert(bucket >= 0, "routing bucket must be greater than or equal to zero")
    self:assertValid()

    SetEntityRoutingBucket(self.handle, bucket)
    return self
end

---Blocca o sblocca il ped e replica il valore a chi entra nel suo scope.
---@param toggle boolean
---@return ped
function ped:setFreeze(toggle)
    assertType("toggle", toggle, "boolean")
    self:assertValid()

    FreezeEntityPosition(self.handle, toggle)
    replicateSetting(self.handle, ped.stateKeys.freeze, toggle)
    return self
end

---Replica l'invulnerabilità ai client che hanno il ped nello scope.
---@param toggle boolean
---@return ped
function ped:setInvincibility(toggle)
    assertType("toggle", toggle, "boolean")
    self:assertValid()

    replicateSetting(self.handle, ped.stateKeys.invincible, toggle)
    return self
end

---Alias compatibile di setInvincibility.
---@param toggle boolean
---@return ped
function ped:setInvincible(toggle)
    return self:setInvincibility(toggle)
end

---Abilita o disabilita il ragdoll e replica il valore ai client.
---@param toggle boolean
---@return ped
function ped:setCanRagdoll(toggle)
    assertType("toggle", toggle, "boolean")
    self:assertValid()

    SetPedCanRagdoll(self.handle, toggle)
    replicateSetting(self.handle, ped.stateKeys.canRagdoll, toggle)
    return self
end

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

---Elimina il ped dal server e invalida il wrapper.
---@return boolean
function ped:delete()
    self:assertValid()

    local handle = self.handle

    DeleteEntity(handle)

    if DoesEntityExist(handle) then
        return false
    end

    self.handle = 0
    return true
end

--#endregion
