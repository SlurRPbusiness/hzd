---@meta

---@class Interval : classlib
---@field id     integer | boolean
---@field ms     integer
---@field active boolean
---@field new    fun(ms: integer, callback: fun()): Interval
local Interval = class("Interval") --[[@as Interval]]

--#region Constructor

---@param ms integer       intervallo in millisecondi
---@param callback fun()   funzione eseguita ad ogni tick
function Interval:constructor(ms, callback)
    assertType(1, ms, "number")
    assertType(2, callback, "function")
    assert(ms > 0, "ms must be a positive number")

    self.ms     = ms
    self.active = true

    self.id = Citizen.SetInterval(function()
        if self.active then
            callback()
        end
    end, ms)
end

--#endregion

--#region Control

---Ferma l'intervallo.
---@return Interval
function Interval:stop()
    if self.active then
        self.active = false
        Citizen.ClearInterval(self.id)
    end

    return self
end

---Riavvia l'intervallo con lo stesso delay.
---@param callback fun()
---@return Interval
function Interval:restart(callback)
    self:stop()

    self.active = true

    self.id = Citizen.SetInterval(function()
        if self.active then
            callback()
        end
    end, self.ms)

    return self
end

---Controlla se l'intervallo è attivo.
---@return boolean
function Interval:isActive()
    return self.active
end

--#endregion

---Crea un nuovo intervallo ricorrente.
---@param ms integer
---@param callback fun()
---@return Interval
function _ENV.interval(ms, callback)
    return Interval.new(ms, callback)
end

