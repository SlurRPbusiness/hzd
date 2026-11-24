---@meta

--#region Server Native Upvalue Optimization

local SetEntityRoutingBucket <const>    = SetEntityRoutingBucket
local GetEntityRoutingBucket <const>    = GetEntityRoutingBucket
local NetworkGetEntityOwner <const>     = NetworkGetEntityOwner
local DoesEntityExist <const>           = DoesEntityExist
local DeleteEntity <const>              = DeleteEntity

--#endregion

local entityModule = assert(_ENV.entity, "shared entity module must load before entity/server.lua")

-- Estendiamo la metatabella Entity lato server
local Entity = assert(entityModule.__Entity, "shared Entity class is missing")

--#region Server Instance Methods Extension

---Imposta il routing bucket (dimensione virtuale) dell'entità.
---@param bucket integer
---@return Entity self
function Entity:setRoutingBucket(bucket)
    assertType("bucket", bucket, "integer")
    assert(bucket >= 0, "routing bucket must be greater than or equal to zero")
    SetEntityRoutingBucket(self.handle, bucket)
    return self
end

---Restituisce il routing bucket corrente dell'entità.
---@return integer
function Entity:getRoutingBucket()
    return GetEntityRoutingBucket(self.handle)
end

---Restituisce il Server ID del player che attualmente possiede il controllo di rete dell'entità.
---@return integer
function Entity:getOwner()
    return NetworkGetEntityOwner(self.handle)
end

--#endregion

--#region Static Server Helpers

---Imposta il routing bucket dato l'handle.
---@param handle integer
---@param bucket integer
function entityModule.setRoutingBucket(handle, bucket)
    assertType("handle", handle, "integer")
    assertType("bucket", bucket, "integer")
    assert(bucket >= 0, "routing bucket must be greater than or equal to zero")
    SetEntityRoutingBucket(handle, bucket)
end

---Restituisce il routing bucket dato l'handle.
---@param handle integer
---@return integer
function entityModule.getRoutingBucket(handle)
    return GetEntityRoutingBucket(handle)
end

---Restituisce il proprietario dato l'handle.
---@param handle integer
---@return integer
function entityModule.getOwner(handle)
    return NetworkGetEntityOwner(handle)
end

--#endregion

