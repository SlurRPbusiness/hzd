---@meta

--#region Native Upvalue Optimization

local GetResourceKvpString <const> = GetResourceKvpString
local SetResourceKvp <const>       = SetResourceKvp
local DeleteResourceKvp <const>    = DeleteResourceKvp

--#endregion

---@class kvplib
---@field get fun(key: string, default?: any): any
---@field set fun(key: string, value: any): boolean
---@field delete fun(key: string): boolean
---@field has fun(key: string): boolean
---@field getOrSet fun(key: string, default: any|fun(): any): any
local kvp = {}
_ENV.kvp = kvp

local keyPrefix = ("%s:kvp/"):format(hzd.name)

---@param key string
---@return string
local function getStorageKey(key)
    assertType("key", key, "string")
    assert(key ~= "", "key cannot be empty")
    return keyPrefix .. key
end

---Legge e decodifica un valore JSON salvato nello storage KVP di questa risorsa.
---@param key string
---@param default? any
---@return any
function kvp.get(key, default)
    local encoded = GetResourceKvpString(getStorageKey(key))

    if encoded == nil then
        return default
    end

    local success, value = pcall(json.decode, encoded)

    if not success then
        return default
    end

    return value
end

---Salva un valore JSON serializzabile. Passando nil elimina la chiave.
---@param key string
---@param value any
---@return boolean
function kvp.set(key, value)
    local storageKey = getStorageKey(key)

    if value == nil then
        DeleteResourceKvp(storageKey)
        return true
    end

    local success, encoded = pcall(json.encode, value)

    if not success or type(encoded) ~= "string" then
        error(("value for KVP key '%s' is not JSON serializable"):format(key), 2)
    end

    SetResourceKvp(storageKey, encoded)
    return true
end

---Elimina una chiave persistente.
---@param key string
---@return boolean
function kvp.delete(key)
    DeleteResourceKvp(getStorageKey(key))
    return true
end

---Verifica se una chiave è presente nello storage KVP.
---@param key string
---@return boolean
function kvp.has(key)
    return GetResourceKvpString(getStorageKey(key)) ~= nil
end

---Restituisce il valore persistito oppure crea e salva il valore iniziale.
---@param key string
---@param default any|fun(): any
---@return any
function kvp.getOrSet(key, default)
    local value = kvp.get(key)

    if value ~= nil then
        return value
    end

    if type(default) == "function" then
        value = default()
    else
        value = default
    end

    if value ~= nil then
        kvp.set(key, value)
    end

    return value
end
