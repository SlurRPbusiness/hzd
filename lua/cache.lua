---@meta

---@class Cache : classlib
---@field store    table<any, any>
---@field order    any[]
---@field capacity integer?
---@field hits     integer
---@field misses   integer
---@field new      fun(capacity?: integer): Cache
local Cache = class("Cache") --[[@as Cache]]

--#region Internals

---Rimuove la voce più vecchia per fare spazio (FIFO semplice).
---@param self Cache
local function evict(self)
    local firstKey = table.remove(self.order, 1)

    if firstKey ~= nil then
        self.store[firstKey] = nil
    end
end

--#endregion

--#region Constructor

---@param capacity? integer  numero massimo di voci (nil = illimitato)
function Cache:constructor(capacity)
    if capacity ~= nil then
        assert(type(capacity) == "number" and capacity % 1 == 0 and capacity > 0,
            "capacity must be a positive integer")
    end

    self.store    = {}
    self.order    = {}
    self.capacity = capacity
    self.hits     = 0
    self.misses   = 0
end

--#endregion

--#region Write

---Inserisce o aggiorna una voce.
---@param key any
---@param value any
---@return Cache
function Cache:set(key, value)
    assert(key ~= nil, "key must not be nil")

    if value == nil then
        return self:delete(key)
    end

    if self.capacity ~= nil and self.store[key] == nil then
        if #self.order >= self.capacity then
            evict(self)
        end
        self.order[#self.order + 1] = key
    end

    self.store[key] = value

    return self
end

---Rimuove una voce dalla cache.
---@param key any
---@return Cache
function Cache:delete(key)
    if self.capacity ~= nil and self.store[key] ~= nil then
        for i = 1, #self.order do
            if self.order[i] == key then
                table.remove(self.order, i)
                break
            end
        end
    end

    self.store[key] = nil

    return self
end

---Svuota completamente la cache.
---@return Cache
function Cache:clear()
    self.store  = {}
    self.order  = {}
    self.hits   = 0
    self.misses = 0

    return self
end

--#endregion

--#region Read

---Restituisce il valore associato alla chiave, nil se assente.
---@generic V
---@param key any
---@return V?
function Cache:get(key)
    local value = self.store[key]

    if value == nil then
        self.misses = self.misses + 1
        return nil
    end

    self.hits = self.hits + 1
    return value
end

---Restituisce il valore se presente, altrimenti lo calcola e lo memorizza.
---@generic V
---@param key any
---@param factory fun(): V
---@return V
function Cache:getOrSet(key, factory)
    local value = self:get(key)

    if value ~= nil then
        return value
    end

    value = factory()
    self:set(key, value)

    return value
end

---Controlla se la chiave è presente.
---@param key any
---@return boolean
function Cache:has(key)
    return self.store[key] ~= nil
end

---Restituisce il valore senza aggiornare hit/miss.
---@param key any
---@return any
function Cache:peek(key)
    return self.store[key]
end

--#endregion

--#region Inspection

---Restituisce il numero di voci presenti.
---@return integer
function Cache:size()
    return table.size(self.store)
end

---Controlla se la cache è vuota.
---@return boolean
function Cache:isEmpty()
    return next(self.store) == nil
end

---Restituisce le statistiche di utilizzo.
---@return { hits: integer, misses: integer, ratio: number }
function Cache:stats()
    local total = self.hits + self.misses
    local ratio = total > 0 and (self.hits / total) or 0

    return {
        hits   = self.hits,
        misses = self.misses,
        ratio  = ratio,
    }
end

---Restituisce tutte le chiavi presenti.
---@return any[]
function Cache:keys()
    return table.keys(self.store)
end

---Restituisce tutti i valori presenti.
---@return any[]
function Cache:values()
    return table.values(self.store)
end

--#endregion

--#region Iteration

---Itera su tutte le voci.
---@param callback fun(value: any, key: any)
---@return Cache
function Cache:each(callback)
    table.each(self.store, callback)

    return self
end

--#endregion

--#region Export

---Esporta la cache come tabella semplice (snapshot).
---@return table
function Cache:toTable()
    return table.clone(self.store)
end

--#endregion

---@type table<string, any>
local cacheModule = setmetatable({}, {
    __call = function(_, capacity)
        return Cache.new(capacity)
    end,
})

_ENV.cache = cacheModule

--#region Default System Cache

cache.resource = GetCurrentResourceName()

if not hzd:is("server") then
    local PlayerId <const>                         = PlayerId
    local GetPlayerServerId <const>                = GetPlayerServerId
    local PlayerPedId <const>                      = PlayerPedId
    local GetVehiclePedIsIn <const>                = GetVehiclePedIsIn
    local GetPedInVehicleSeat <const>              = GetPedInVehicleSeat
    local GetVehicleMaxNumberOfPassengers <const>  = GetVehicleMaxNumberOfPassengers

    local function getPedSeat(ped, vehicle)
        if not vehicle or vehicle == 0 then
            return false
        end
        if GetPedInVehicleSeat(vehicle, -1) == ped then
            return -1
        end
        local maxPassengers = GetVehicleMaxNumberOfPassengers(vehicle)
        for seat = 0, maxPassengers - 1 do
            if GetPedInVehicleSeat(vehicle, seat) == ped then
                return seat
            end
        end
        return false
    end

    cache.playerId   = PlayerId()
    cache.serverId   = GetPlayerServerId(cache.playerId)
    cache.ped        = PlayerPedId()
    local initialVeh = GetVehiclePedIsIn(cache.ped, false)
    cache.vehicle    = initialVeh ~= 0 and initialVeh or false
    cache.seat       = initialVeh ~= 0 and getPedSeat(cache.ped, initialVeh) or false

    Citizen.CreateThread(function()
        while true do
            local currentPed = PlayerPedId()
            if currentPed ~= 0 and currentPed ~= cache.ped then
                cache.ped = currentPed
            end

            local inVehicle = GetVehiclePedIsIn(cache.ped, false)
            if inVehicle ~= 0 then
                cache.vehicle = inVehicle
                cache.seat    = getPedSeat(cache.ped, inVehicle)
            else
                cache.vehicle = false
                cache.seat    = false
            end

            Wait(250)
        end
    end)
end

--#endregion
