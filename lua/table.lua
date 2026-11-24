---@meta

---@class tablelib: table
table = table

--#region Internal / Iterators

-- Primitive privata: unico punto di accesso a pairs.
---@param tbl table
---@return function, table, any
local function _pairs(tbl)
    return pairs(tbl)
end

-- Primitive privata: unico punto di accesso a ipairs.
---@param tbl table
---@return function, table, integer
local function _ipairs(tbl)
    return ipairs(tbl)
end

--#endregion

--#region Iteration

---Restituisce tutti i valori presenti nella tabella.
---@generic V
---@param tbl table<any, V>
---@return V[]
function table.values(tbl)
    local result = {}

    table.each(tbl, function(value)
        result[#result + 1] = value
    end)

    return result
end

---Itera su tutti gli elementi di una tabella.
---@generic K, V
---@param tbl table<K, V>
---@param callback fun(value: V, key: K)
---@return table<K, V>
function table.each(tbl, callback)
    for key, value in _pairs(tbl) do
        callback(value, key)
    end

    return tbl
end

---Itera esclusivamente sugli indici sequenziali.
---@generic T
---@param tbl T[]
---@param callback fun(value: T, index: integer)
---@return T[]
function table.eachArray(tbl, callback)
    for index, value in _ipairs(tbl) do
        callback(value, index)
    end

    return tbl
end

--#endregion

--#region Inspection

---Conta gli elementi della tabella.
---@param tbl table
---@return integer
function table.size(tbl)
    local count = 0

    for _ in pairs(tbl) do
        count = count + 1
    end

    return count
end

---Controlla se la tabella è vuota.
---@param tbl table
---@return boolean
function table.isEmpty(tbl)
    return next(tbl) == nil
end

---Restituisce tutte le chiavi.
---@param tbl table
---@return any[]
function table.keys(tbl)
    local result = {}

    table.each(tbl, function(_, key)
        result[#result + 1] = key
    end)

    return result
end

---Controlla se una chiave esiste.
---@param tbl table
---@param key any
---@return boolean
function table.hasKey(tbl, key)
    return rawget(tbl, key) ~= nil
end

---Restituisce il primo elemento.
---@generic T
---@param tbl T[]
---@return T?
function table.first(tbl)
    return tbl[1]
end

---Restituisce l'ultimo elemento.
---@generic T
---@param tbl T[]
---@return T?
function table.last(tbl)
    return tbl[#tbl]
end

--#endregion

--#region Transformation

---Trasforma gli elementi preservando le chiavi.
---@generic K, T, R
---@param tbl table<K, T>
---@param callback fun(value: T, key: K): R
---@return table<K, R>
function table.map(tbl, callback)
    local result = {}

    table.each(tbl, function(value, key)
        result[key] = callback(value, key)
    end)

    return result
end

---Trasforma un array mantenendo la sequenza.
---@generic T, R
---@param tbl T[]
---@param callback fun(value: T, index: integer): R
---@return R[]
function table.mapArray(tbl, callback)
    local result = {}

    table.eachArray(tbl, function(value, index)
        result[#result + 1] = callback(value, index)
    end)

    return result
end

---Riduce una tabella a un singolo valore.
---@generic K, T, R
---@param tbl table<K, T>
---@param callback fun(accumulator: R, value: T, key: K): R
---@param initial R
---@return R
function table.reduce(tbl, callback, initial)
    local accumulator = initial

    table.each(tbl, function(value, key)
        accumulator = callback(accumulator, value, key)
    end)

    return accumulator
end

---Riduce un array sequenziale.
---@generic T, R
---@param tbl T[]
---@param callback fun(accumulator: R, value: T, index: integer): R
---@param initial R
---@return R
function table.reduceArray(tbl, callback, initial)
    local accumulator = initial

    table.eachArray(tbl, function(value, index)
        accumulator = callback(accumulator, value, index)
    end)

    return accumulator
end

---Filtra mantenendo le chiavi originali.
---@generic K, T
---@param tbl table<K, T>
---@param callback fun(value: T, key: K): boolean
---@return table<K, T>
function table.filter(tbl, callback)
    local result = {}

    table.each(tbl, function(value, key)
        if callback(value, key) then
            result[key] = value
        end
    end)

    return result
end

---Filtra un array e ricompatta gli indici.
---@generic T
---@param tbl T[]
---@param callback fun(value: T, index: integer): boolean
---@return T[]
function table.filterArray(tbl, callback)
    local result = {}

    table.eachArray(tbl, function(value, index)
        if callback(value, index) then
            result[#result + 1] = value
        end
    end)

    return result
end

---Appiattisce i risultati di una callback.
---@generic T, R
---@param tbl T[]
---@param callback fun(value: T, index: integer): R[]
---@return R[]
function table.flatMap(tbl, callback)
    return table.reduceArray(tbl, function(result, value, index)
        table.eachArray(callback(value, index), function(mapped)
            result[#result + 1] = mapped
        end)

        return result
    end, {})
end

---Estrae una proprietà dagli oggetti.
---@generic T, R
---@param tbl T[]
---@param key string|number
---@return R[]
function table.pluck(tbl, key)
    return table.mapArray(tbl, function(value)
        return value[key]
    end)
end

---Raggruppa gli elementi in base a una chiave.
---@generic T, K
---@param tbl T[]
---@param callback fun(value: T, index: integer): K
---@return table<K, T[]>
function table.groupBy(tbl, callback)
    return table.reduceArray(tbl, function(result, value, index)
        local key = callback(value, index)

        result[key] = result[key] or {}
        result[key][#result[key] + 1] = value

        return result
    end, {})
end

--#endregion

--#region Search

---Trova il primo elemento che soddisfa una condizione.
---@generic K, T
---@param tbl table<K, T>
---@param callback fun(value: T, key: K): boolean
---@return T?, K?
function table.find(tbl, callback)
    for key, value in pairs(tbl) do
        if callback(value, key) then
            return value, key
        end
    end
end

---Controlla se un elemento soddisfa una condizione.
---@param tbl table
---@param callback fun(value: any, key: any): boolean
---@return boolean
function table.some(tbl, callback)
    return table.find(tbl, callback) ~= nil
end

---Controlla se tutti gli elementi soddisfano una condizione.
---@param tbl table
---@param callback fun(value: any, key: any): boolean
---@return boolean
function table.every(tbl, callback)
    return not table.some(tbl, function(value, key)
        return not callback(value, key)
    end)
end

---Cerca una chiave attraverso il suo valore.
---@param tbl table
---@param searched any
---@return any?
function table.keyOf(tbl, searched)
    local _, key = table.find(tbl, function(value)
        return value == searched
    end)

    return key
end

---Controlla se un valore è presente.
---@param tbl table
---@param searched any
---@return boolean
function table.contains(tbl, searched)
    return table.keyOf(tbl, searched) ~= nil
end

--#endregion

--#region Collection

---Divide un array in gruppi di dimensione fissa.
---@generic T
---@param tbl T[]
---@param size integer
---@return T[][]
function table.chunk(tbl, size)
    local result = {}

    if size <= 0 then
        return result
    end

    table.eachArray(tbl, function(value, index)
        local chunk = math.ceil(index / size)

        result[chunk] = result[chunk] or {}
        result[chunk][#result[chunk] + 1] = value
    end)

    return result
end

---Rimuove i duplicati.
---@generic T
---@param tbl T[]
---@return T[]
function table.unique(tbl)
    local seen = {}

    return table.filterArray(tbl, function(value)
        if seen[value] then
            return false
        end

        seen[value] = true
        return true
    end)
end

---Rimuove valori false e stringhe vuote.
---@generic T
---@param tbl T[]
---@return T[]
function table.compact(tbl)
    return table.filterArray(tbl, function(value)
        return value ~= false and value ~= ""
    end)
end

---Divide gli elementi in due gruppi.
---@generic T
---@param tbl T[]
---@param callback fun(value: T, index: integer): boolean
---@return T[] passed
---@return T[] failed
function table.partition(tbl, callback)
    local passed, failed = {}, {}

    table.eachArray(tbl, function(value, index)
        local target = callback(value, index) and passed or failed
        target[#target + 1] = value
    end)

    return passed, failed
end

---Unisce più tabelle.
---@param ... table
---@return table
function table.merge(...)
    local result = {}

    for index = 1, select("#", ...) do
        table.each(select(index, ...), function(value, key)
            result[key] = value
        end)
    end

    return result
end

---Crea un set.
---@param tbl any[]
---@return table
function table.toSet(tbl)
    return table.reduceArray(tbl, function(result, value)
        result[value] = true
        return result
    end, {})
end

--#endregion

--#region Clone

---Copia superficialmente una tabella.
---@generic T: table
---@param tbl T
---@return T
function table.clone(tbl)
    local result = {}

    table.each(tbl, function(value, key)
        result[key] = value
    end)

    local metatable = getmetatable(tbl)

    if type(metatable) == 'table' then
        setmetatable(result, metatable)
    end

    return result
end

---Copia profondamente una tabella, anche con riferimenti ciclici.
---@generic T: table
---@param tbl T
---@param seen? table
---@return T
function table.deepClone(tbl, seen)
    if type(tbl) ~= "table" then
        return tbl
    end

    seen = seen or {}

    if seen[tbl] then
        return seen[tbl]
    end

    local result = {}
    seen[tbl] = result

    table.each(tbl, function(value, key)
        result[table.deepClone(key, seen)] =
            table.deepClone(value, seen)
    end)

    local metatable = getmetatable(tbl)

    if type(metatable) == 'table' then
        setmetatable(result, metatable)
    end

    return result
end

--#endregion

--#region Comparison

---Confronta due tabelle superficialmente.
---@param first table
---@param second table
---@return boolean
function table.equals(first, second)
    if first == second then
        return true
    end

    if type(first) ~= "table" or type(second) ~= "table" then
        return false
    end

    return table.size(first) == table.size(second)
        and table.every(first, function(value, key)
            return second[key] == value
        end)
end

---Confronta ricorsivamente due tabelle.
---@param first table
---@param second table
---@param seen? table
---@return boolean
function table.deepEquals(first, second, seen)
    if first == second then
        return true
    end

    if type(first) ~= "table" or type(second) ~= "table" then
        return false
    end

    seen = seen or {}

    if seen[first] ~= nil then
        return seen[first] == second
    end

    seen[first] = second

    local firstCount = 0

    for key, value in next, first do
        firstCount = firstCount + 1
        local otherValue = rawget(second, key)

        if otherValue == nil or not table.deepEquals(value, otherValue, seen) then
            return false
        end
    end

    local secondCount = 0

    for _ in next, second do
        secondCount = secondCount + 1
    end

    return firstCount == secondCount
end

--#endregion
