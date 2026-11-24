---@meta

--#region Native Upvalue Optimization

local DoesEntityExist <const>                     = DoesEntityExist
local GetEntityType <const>                       = GetEntityType
local GetEntityModel <const>                      = GetEntityModel
local GetEntityCoords <const>                     = GetEntityCoords
local SetEntityCoords <const>                     = SetEntityCoords
local GetEntityHeading <const>                    = GetEntityHeading
local SetEntityHeading <const>                    = SetEntityHeading
local GetEntityHealth <const>                     = GetEntityHealth
local SetEntityHealth <const>                     = SetEntityHealth
local GetEntityMaxHealth <const>                  = GetEntityMaxHealth
local SetEntityMaxHealth <const>                  = SetEntityMaxHealth
local GetEntityVelocity <const>                   = GetEntityVelocity
local SetEntityVelocity <const>                   = SetEntityVelocity
local NetworkGetNetworkIdFromEntity <const>       = NetworkGetNetworkIdFromEntity
local NetworkGetEntityFromNetworkId <const>       = NetworkGetEntityFromNetworkId
local NetworkDoesEntityExistWithNetworkId <const> = NetworkDoesEntityExistWithNetworkId
local DeleteEntity <const>                        = DeleteEntity

--#endregion

---@class Entity
---@field handle integer
---@field new fun(handle: integer): Entity
local Entity                                      = {}
Entity.__index                                    = Entity

local entityModule                                = {}
_ENV.entity                                       = setmetatable(entityModule, {
    __call = function(_, handle)
        return Entity.fromHandle(handle)
    end,
})

--#region Entity Instance Methods

---Crea una nuova istanza Entity dato un handle.
---@param handle integer
---@return Entity?
function Entity.fromHandle(handle)
    if not handle or handle == 0 or not DoesEntityExist(handle) then
        return nil
    end

    local self = setmetatable({}, Entity)
    self.handle = handle
    return self
end

---Recupera un'entità partendo dal Network ID.
---@param netId integer
---@return Entity?
function Entity.fromNetId(netId)
    if not netId or netId <= 0 then return nil end
    if not NetworkDoesEntityExistWithNetworkId(netId) then return nil end

    local handle = NetworkGetEntityFromNetworkId(netId)
    return Entity.fromHandle(handle)
end

---Restituisce l'handle grezzo dell'entità.
---@return integer
function Entity:getHandle()
    return self.handle
end

---Verifica se l'entità esiste ancora nel gioco.
---@return boolean
function Entity:exists()
    return self.handle ~= 0 and DoesEntityExist(self.handle)
end

---Restituisce il tipo di entità: "ped", "vehicle", "object" o "unknown".
---@return "ped" | "vehicle" | "object" | "unknown"
function Entity:getType()
    local t = GetEntityType(self.handle)
    if t == 1 then return "ped" end
    if t == 2 then return "vehicle" end
    if t == 3 then return "object" end
    return "unknown"
end

---Restituisce l'hash del modello 3D.
---@return integer
function Entity:getModel()
    return GetEntityModel(self.handle)
end

---Restituisce le coordinate attuali come vector3.
---@return vector3
function Entity:getCoords()
    return GetEntityCoords(self.handle)
end

---Imposta le coordinate dell'entità.
---@param x number|vector3|vector4|table
---@param y? number
---@param z? number
---@return Entity self
function Entity:setCoords(x, y, z)
    if type(x) == "vector3" or type(x) == "vector4" or type(x) == "table" then
        assert(type(x.x) == "number" and type(x.y) == "number" and type(x.z) == "number",
            "coords must provide numeric x, y and z")
        SetEntityCoords(self.handle, x.x + 0.0, x.y + 0.0, x.z + 0.0, false, false, false, false)
    else
        assertType("x", x, "number")
        assertType("y", y, "number")
        assertType("z", z, "number")
        SetEntityCoords(self.handle, x + 0.0, y + 0.0, z + 0.0, false, false, false, false)
    end
    return self
end

---Calcola la distanza tra l'entità e un punto o un'altra entità.
---@param target vector3|table|Entity
---@return number
function Entity:getDistance(target)
    local targetCoords = (type(target) == "table" and target.getCoords) and target:getCoords() or target
    local myCoords = self:getCoords()
    local vTarget = vec3(targetCoords.x, targetCoords.y, targetCoords.z)
    return #(myCoords - vTarget)
end

---Restituisce l'heading (direzione in gradi).
---@return number
function Entity:getHeading()
    return GetEntityHeading(self.handle)
end

---Imposta l'heading.
---@param heading number
---@return Entity self
function Entity:setHeading(heading)
    assertType("heading", heading, "number")
    SetEntityHeading(self.handle, heading + 0.0)
    return self
end

---Restituisce la salute attuale dell'entità.
---@return integer
function Entity:getHealth()
    return GetEntityHealth(self.handle)
end

---Imposta la salute dell'entità.
---@param health number
---@return Entity self
function Entity:setHealth(health)
    assertType("health", health, "number")
    SetEntityHealth(self.handle, math.floor(health))
    return self
end

---Restituisce la salute massima impostata.
---@return integer
function Entity:getMaxHealth()
    return GetEntityMaxHealth(self.handle)
end

---Imposta la salute massima dell'entità.
---@param maxHealth number
---@return Entity self
function Entity:setMaxHealth(maxHealth)
    assertType("maxHealth", maxHealth, "number")
    SetEntityMaxHealth(self.handle, math.floor(maxHealth))
    return self
end

---Restituisce il vettore di velocità lineare.
---@return vector3
function Entity:getVelocity()
    return GetEntityVelocity(self.handle)
end

---Imposta il vettore di velocità lineare.
---@param vel vector3|table
---@return Entity self
function Entity:setVelocity(vel)
    SetEntityVelocity(self.handle, vel.x + 0.0, vel.y + 0.0, vel.z + 0.0)
    return self
end

---Restituisce il Network ID associato all'entità.
---@return integer
function Entity:getNetId()
    return NetworkGetNetworkIdFromEntity(self.handle)
end

---Elimina l'entità dal gioco.
---@return boolean
function Entity:delete()
    if self:exists() then
        DeleteEntity(self.handle)
        self.handle = 0
        return true
    end
    return false
end

--#endregion

--#region Static Module Helpers

entityModule.fromHandle = Entity.fromHandle
entityModule.fromNetId  = Entity.fromNetId
entityModule.__Entity   = Entity   -- usato da entity/client.lua per estendere i metodi

---Verifica rapida se un handle esiste.
---@param handle integer
---@return boolean
function entityModule.exists(handle)
    return handle ~= nil and handle ~= 0 and DoesEntityExist(handle)
end

---Recupera le coordinate dato un handle.
---@param handle integer
---@return vector3
function entityModule.getCoords(handle)
    return GetEntityCoords(handle)
end

---Imposta le coordinate dato un handle.
---@param handle integer
---@param coords vector3|table
function entityModule.setCoords(handle, coords)
    assert(type(coords) == "table" or type(coords) == "vector3" or type(coords) == "vector4",
        "coords must be a vector or table")
    assert(type(coords.x) == "number" and type(coords.y) == "number" and type(coords.z) == "number",
        "coords must provide numeric x, y and z")
    SetEntityCoords(handle, coords.x + 0.0, coords.y + 0.0, coords.z + 0.0, false, false, false, false)
end

---Recupera la salute dato un handle.
---@param handle integer
---@return integer
function entityModule.getHealth(handle)
    return GetEntityHealth(handle)
end

---Imposta la salute dato un handle.
---@param handle integer
---@param health number
function entityModule.setHealth(handle, health)
    assertType("health", health, "number")
    SetEntityHealth(handle, math.floor(health))
end

---Restituisce il Network ID da un handle.
---@param handle integer
---@return integer
function entityModule.getNetId(handle)
    return NetworkGetNetworkIdFromEntity(handle)
end

--#endregion
