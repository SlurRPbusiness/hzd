---@meta

--#region Native Upvalue Optimization

local DoesEntityExist <const>               = DoesEntityExist
local GetEntityType <const>                 = GetEntityType
local GetEntityModel <const>                = GetEntityModel
local GetEntityCoords <const>               = GetEntityCoords
local GetEntityHeading <const>              = GetEntityHeading
local SetEntityHeading <const>              = SetEntityHeading
local GetEntityHealth <const>               = GetEntityHealth
local SetEntityHealth <const>               = SetEntityHealth
local GetPedArmour <const>                  = GetPedArmour
local SetPedArmour <const>                  = SetPedArmour
local NetworkGetNetworkIdFromEntity <const> = NetworkGetNetworkIdFromEntity
local joaat <const>                         = joaat

--#endregion

---@class pedCreateData
---@field coords vector3|vector4|table
---@field networked? boolean
---@field scriptHostPed? boolean
---@field heading? number
---@field freeze? boolean
---@field invincible? boolean
---@field canRagdoll? boolean
---@field health? number
---@field armour? number
---@field routingBucket? integer

---@class ped : classlib
---@field handle integer
---@field stateKeys { freeze: string, invincible: string, canRagdoll: string }
---@field new fun(handle: integer): ped
---@field fromHandle fun(self: ped, handle: integer): ped?
---@field fromNetworkId fun(self: ped, networkId: integer): ped?
---@field create fun(self: ped, model: string|integer, data: pedCreateData): ped
---@field fromPlayer fun(self: ped, source?: integer|string): ped?
---@field getPlayerServerId fun(self: ped): integer?
---@field getOwner fun(self: ped): integer
---@field getRoutingBucket fun(self: ped): integer
---@field setRoutingBucket fun(self: ped, bucket: integer): ped
---@field setCoords fun(self: ped, coords: vector3|vector4|table, clearArea?: boolean): ped
---@field setFreeze fun(self: ped, toggle: boolean): ped
---@field setInvincibility fun(self: ped, toggle: boolean): ped
---@field setInvincible fun(self: ped, toggle: boolean): ped
---@field setCanRagdoll fun(self: ped, toggle: boolean): ped
---@field getModel fun(self: ped): integer
---@field getCoords fun(self: ped): vector3
---@field getHeading fun(self: ped): number
---@field setHeading fun(self: ped, heading: number): ped
---@field getHealth fun(self: ped): integer
---@field setHealth fun(self: ped, health: number): ped
---@field getArmour fun(self: ped): integer
---@field setArmour fun(self: ped, amount: number): ped
---@field getNetworkId fun(self: ped): integer
---@field getHandle fun(self: ped): integer
---@field isValid fun(self: ped): boolean
---@field assertValid fun(self: ped): ped
---@field normalizeCoords fun(self: ped, coords: vector3|vector4|table): number, number, number
---@field normalizeSpawn fun(self: ped, model: string|integer, coords: vector3|vector4|table, data?: pedCreateData|boolean, legacyScriptHostPed?: boolean): integer, number, number, number, number, pedCreateData
---@field delete fun(self: ped): boolean
---@field clearTasks fun(self: ped, immediately?: boolean): ped
---@field playAnimation fun(self: ped, dictionary: string, animation: string, duration?: integer, flags?: integer, playbackRate?: number): ped
---@field setComponentVariation fun(self: ped, componentId: integer, drawableId: integer, textureId: integer, paletteId?: integer): ped
---@field clearProp fun(self: ped, propId: integer): ped
local ped                                   = class("ped") --[[@as ped]]
_ENV.ped                                    = ped

ped.stateKeys                               = {
    freeze = "hzd:ped:freeze",
    invincible = "hzd:ped:invincible",
    canRagdoll = "hzd:ped:canRagdoll",
}

--#region Construction and Validation

---@param handle integer
function ped:constructor(handle)
    assertType("handle", handle, "integer")
    assert(handle > 0, "ped handle must be greater than zero")
    assert(DoesEntityExist(handle), "ped handle does not exist")
    assert(GetEntityType(handle) == 1, "entity handle is not a ped")

    self.handle = handle
end

---Crea un wrapper solo se l'handle è ancora valido.
---@param handle integer
---@return ped?
function ped:fromHandle(handle)
    assertType(1, handle, "integer")

    if handle <= 0 or not DoesEntityExist(handle) or GetEntityType(handle) ~= 1 then
        return nil
    end

    return self.new(handle)
end

---Restituisce l'handle locale del ped.
---@return integer
function ped:getHandle()
    return self.handle
end

---Restituisce il wrapper Entity associato a questo ped.
---@return Entity?
function ped:toEntity()
    return entity(self.handle)
end

---Controlla se l'entità esiste ancora nel runtime corrente.
---@return boolean
function ped:isValid()
    return self.handle > 0 and DoesEntityExist(self.handle)
end

---Interrompe l'operazione con un errore chiaro se il ped non esiste più.
---@return ped
function ped:assertValid()
    if not self:isValid() then
        error(("ped handle %s is no longer valid"):format(self.handle), 2)
    end

    return self
end

--#endregion

--#region Shared Coordinates

---@param coords vector3|vector4|table
---@return number x
---@return number y
---@return number z
function ped:normalizeCoords(coords)
    local coordsType = type(coords)

    assert(
        coordsType == "table" or coordsType == "vector3" or coordsType == "vector4",
        "coords must be a table, vector3 or vector4"
    )

    assertType("coords.x", coords.x, "number")
    assertType("coords.y", coords.y, "number")
    assertType("coords.z", coords.z, "number")

    return coords.x, coords.y, coords.z
end

---Valida e normalizza gli argomenti per lo spawn.
---@param model string|integer
---@param coords vector3|vector4|table
---@param data? pedCreateData|boolean
---@param legacyScriptHostPed? boolean
---@return integer modelHash
---@return number x
---@return number y
---@return number z
---@return number heading
---@return pedCreateData data
function ped:normalizeSpawn(model, coords, data, legacyScriptHostPed)
    assertType("model", model, "string|number")

    if type(model) == "string" then
        assert(model ~= "", "model cannot be empty")
        model = joaat(model)
    end

    local options

    if type(data) == "boolean" then
        options = {
            networked = data,
            scriptHostPed = legacyScriptHostPed,
        }
    elseif data == nil then
        options = {
            scriptHostPed = legacyScriptHostPed,
        }
    else
        assertType("data", data, "table")
        assert(legacyScriptHostPed == nil, "legacyScriptHostPed cannot be used with a data table")
        options = {
            networked = data.networked,
            scriptHostPed = data.scriptHostPed,
            heading = data.heading,
            freeze = data.freeze,
            invincible = data.invincible,
            canRagdoll = data.canRagdoll,
            health = data.health,
            armour = data.armour,
            routingBucket = data.routingBucket,
        }
    end

    local x, y, z = self:normalizeCoords(coords)
    local coordsType = type(coords)
    local heading = options.heading

    if heading == nil then
        if coordsType == "vector4" then
            heading = coords.w
        elseif coordsType == "table" then
            heading = coords.heading or coords.h or coords.w
        end
    end

    heading = heading or 0.0

    if options.networked == nil then
        options.networked = true
    end

    if options.scriptHostPed == nil then
        options.scriptHostPed = true
    end

    if options.freeze == nil then
        options.freeze = false
    end

    if options.invincible == nil then
        options.invincible = false
    end

    if options.canRagdoll == nil then
        options.canRagdoll = true
    end

    assertType("heading", heading, "number")
    assertType("networked", options.networked, "boolean")
    assertType("scriptHostPed", options.scriptHostPed, "boolean")
    assertType("freeze", options.freeze, "boolean")
    assertType("invincible", options.invincible, "boolean")
    assertType("canRagdoll", options.canRagdoll, "boolean")

    if options.health ~= nil then
        assertType("health", options.health, "number")
        assert(options.health >= 0, "health must be greater than or equal to zero")
    end

    if options.armour ~= nil then
        assertType("armour", options.armour, "number")
        assert(options.armour >= 0, "armour must be greater than or equal to zero")
    end

    if options.routingBucket ~= nil then
        assertType("routingBucket", options.routingBucket, "integer")
        assert(options.routingBucket >= 0, "routingBucket must be greater than or equal to zero")
    end

    return model, x, y, z, heading, options
end

--#endregion

--#region Shared Native Accessors

---Restituisce il model hash corrente.
---@return integer
function ped:getModel()
    self:assertValid()
    return GetEntityModel(self.handle)
end

---Restituisce le coordinate correnti.
---@return vector3
function ped:getCoords()
    self:assertValid()
    return GetEntityCoords(self.handle)
end

---Restituisce la direzione del ped in gradi.
---@return number
function ped:getHeading()
    self:assertValid()
    return GetEntityHeading(self.handle)
end

---Imposta la direzione del ped in gradi.
---@param heading number
---@return ped
function ped:setHeading(heading)
    assertType("heading", heading, "number")
    self:assertValid()

    SetEntityHeading(self.handle, heading)
    return self
end

---Restituisce la salute corrente.
---@return integer
function ped:getHealth()
    self:assertValid()
    return GetEntityHealth(self.handle)
end

---Imposta la salute.
---@param health number
---@return ped
function ped:setHealth(health)
    assertType("health", health, "number")
    assert(health >= 0, "health must be greater than or equal to zero")
    self:assertValid()

    SetEntityHealth(self.handle, math.floor(health))
    return self
end

---Resetta il ped da morte, blood damage, visibile damage, weapon damage
---@return ped
function ped:clear()
    ClearPedTasksImmediately(self.handle)
    ClearPedBloodDamage(self.handle)
    ResetPedVisibleDamage(self.handle)
    ClearPedLastWeaponDamage(self.handle)

    return self
end

---Restituisce l'armatura corrente.
---@return integer
function ped:getArmour()
    self:assertValid()
    return GetPedArmour(self.handle)
end

---Imposta l'armatura.
---@param amount number
---@return ped
function ped:setArmour(amount)
    assertType("amount", amount, "number")
    assert(amount >= 0, "armour must be greater than or equal to zero")
    self:assertValid()

    SetPedArmour(self.handle, math.floor(amount))
    return self
end

---Restituisce il network ID, utilizzabile per identificare l'entità tra client e server.
---@return integer
function ped:getNetworkId()
    self:assertValid()
    return NetworkGetNetworkIdFromEntity(self.handle)
end

--#endregion
