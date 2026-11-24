---@meta

---@class native
local native = {}
_ENV.native = native

--#region Lookup

---Restituisce la funzione nativa dal nome globale di FiveM.
---@param name string
---@return function?
function native.get(name)
    local fn = _G[name]
    if type(fn) == "function" then
        return fn
    end
    return nil
end

---Controlla se una nativa esiste nel runtime corrente.
---@param name string
---@return boolean
function native.exist(name)
    return native.get(name) ~= nil
end

--#endregion

