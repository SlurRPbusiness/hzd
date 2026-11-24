---@meta

--#region Client Native Upvalue Optimization

local SetEntityInvincible <const>       = SetEntityInvincible
local FreezeEntityPosition <const>      = FreezeEntityPosition
local SetEntityAlpha <const>            = SetEntityAlpha
local ResetEntityAlpha <const>          = ResetEntityAlpha
local SetEntityVisible <const>          = SetEntityVisible
local SetEntityCollision <const>        = SetEntityCollision
local IsEntityDead <const>              = IsEntityDead
local GetEntitySpeed <const>            = GetEntitySpeed
local SetPedArmour <const>              = SetPedArmour
local GetPedArmour <const>              = GetPedArmour
local SetEntityAsMissionEntity <const>  = SetEntityAsMissionEntity
local SetEntityCoordsNoOffset <const>   = SetEntityCoordsNoOffset
local IsPedAPlayer <const>              = IsPedAPlayer
local NetworkGetPlayerIndexFromPed <const> = NetworkGetPlayerIndexFromPed
local GetPlayerServerId <const>         = GetPlayerServerId
local ClearPedTasksImmediately <const>  = ClearPedTasksImmediately
local ClearPedBloodDamage <const>       = ClearPedBloodDamage
local ResetPedVisibleDamage <const>     = ResetPedVisibleDamage
local ClearPedLastWeaponDamage <const>  = ClearPedLastWeaponDamage

--#endregion

local entityModule = assert(_ENV.entity, "shared entity module must load before entity/client.lua")

-- Recupera la metatabella Entity esposta da shared.lua tramite chiave interna __Entity
---@class Entity
local Entity = assert(entityModule.__Entity, "shared Entity class is missing")

--#region Client Instance Methods Extension

---Imposta o disattiva l'invincibilità dell'entità.
---@param toggle boolean
---@return Entity self
function Entity:setInvincible(toggle)
    SetEntityInvincible(self.handle, toggle == true)
    return self
end

---Blocca o sblocca la posizione fisica dell'entità.
---@param toggle boolean
---@return Entity self
function Entity:setFreeze(toggle)
    FreezeEntityPosition(self.handle, toggle == true)
    return self
end

---Imposta la trasparenza visiva (0 - 255).
---@param alpha integer
---@return Entity self
function Entity:setAlpha(alpha)
    if not alpha or alpha >= 255 then
        ResetEntityAlpha(self.handle)
    else
        SetEntityAlpha(self.handle, math.clamp(alpha, 0, 255), false)
    end
    return self
end

---Imposta la visibilità dell'entità nel mondo.
---@param toggle boolean
---@return Entity self
function Entity:setVisible(toggle)
    SetEntityVisible(self.handle, toggle == true, false)
    return self
end

---Abilita o disabilita le collisioni fisiche.
---@param toggle boolean
---@param keepPhysics? boolean
---@return Entity self
function Entity:setCollision(toggle, keepPhysics)
    SetEntityCollision(self.handle, toggle == true, keepPhysics ~= false)
    return self
end

---Verifica se l'entità è morta o distrutta.
---@return boolean
function Entity:isDead()
    return IsEntityDead(self.handle)
end

---Restituisce la velocità lineare attuale.
---@param inKmh? boolean Se true restituisce km/h, altrimenti m/s (default: false)
---@return number
function Entity:getSpeed(inKmh)
    local speed = GetEntitySpeed(self.handle)
    return inKmh and (speed * 3.6) or speed
end

---Restituisce l'armatura (se l'entità è un ped).
---@return integer
function Entity:getArmour()
    return GetPedArmour(self.handle)
end

---Imposta l'armatura (se l'entità è un ped).
---@param armour integer
---@return Entity self
function Entity:setArmour(armour)
    assertType("armour", armour, "number")
    SetPedArmour(self.handle, math.clamp(armour, 0, 100))
    return self
end

---Imposta le coordinate senza offset di collisione.
---@param x number|vector3|table
---@param y? number
---@param z? number
---@return Entity self
function Entity:setCoordsNoOffset(x, y, z)
    if type(x) == "vector3" or type(x) == "table" then
        assert(type(x.x) == "number" and type(x.y) == "number" and type(x.z) == "number",
            "coords must provide numeric x, y and z")
        SetEntityCoordsNoOffset(self.handle, x.x + 0.0, x.y + 0.0, x.z + 0.0, true, true, true)
    else
        assertType("x", x, "number")
        assertType("y", y, "number")
        assertType("z", z, "number")
        SetEntityCoordsNoOffset(self.handle, x + 0.0, y + 0.0, z + 0.0, true, true, true)
    end
    return self
end

---Controlla se l'entità è il ped di un giocatore online e ne restituisce il server ID.
---@return boolean isPlayer, integer? serverId
function Entity:isPlayer()
    if not IsPedAPlayer(self.handle) then
        return false, nil
    end

    local pIndex = NetworkGetPlayerIndexFromPed(self.handle)
    if pIndex == -1 then
        return true, nil
    end

    return true, GetPlayerServerId(pIndex)
end

---Marchia l'entità come mission entity per evitare che il gioco la cancelli.
---@return Entity self
function Entity:asMissionEntity()
    SetEntityAsMissionEntity(self.handle, true, true)
    return self
end

---Ripulisce compiti, sangue e danni visivi dal ped.
---@return Entity self
function Entity:clean()
    ClearPedTasksImmediately(self.handle)
    ClearPedBloodDamage(self.handle)
    ResetPedVisibleDamage(self.handle)
    ClearPedLastWeaponDamage(self.handle)
    return self
end

---Alias per clean().
---@return Entity self
function Entity:clear()
    return self:clean()
end

--#endregion

--#region Static Client Helpers

---Imposta l'invincibilità direttamente dall'handle.
---@param handle integer
---@param toggle boolean
function entityModule.setInvincible(handle, toggle)
    SetEntityInvincible(handle, toggle == true)
end

---Blocca/sblocca l'entità direttamente dall'handle.
---@param handle integer
---@param toggle boolean
function entityModule.setFreeze(handle, toggle)
    FreezeEntityPosition(handle, toggle == true)
end

---Imposta salute e armatura direttamente dall'handle.
---@param handle integer
---@param health number
---@param armour? number
function entityModule.setVitals(handle, health, armour)
    assertType("health", health, "number")
    SetEntityHealth(handle, math.floor(health))
    if armour ~= nil then
        SetPedArmour(handle, math.clamp(armour, 0, 100))
    end
end

---Verifica se l'entità è morta dato l'handle.
---@param handle integer
---@return boolean
function entityModule.isDead(handle)
    return IsEntityDead(handle)
end

--#endregion

