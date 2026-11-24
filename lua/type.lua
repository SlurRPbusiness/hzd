---@meta

--#region Type Validation

local unionCache = {}

local function getUnionTypes(expected)
    local cached = unionCache[expected]
    if cached then return cached end

    local types = {}
    for singleExpected in expected:gmatch("[^|]+") do
        types[#types + 1] = singleExpected
    end
    unionCache[expected] = types
    return types
end

---Verifica se un valore corrisponde a uno o più tipi attesi (supporta unioni come "string|number" o "integer").
---@param var any               il valore da testare
---@param expected string       il tipo o unione di tipi attesi (es. "string", "number", "string|number", "integer", "table|nil")
---@return boolean isValid      true se il tipo è valido
---@return string receivedType  il tipo rilevato
function _ENV.validateType(var, expected)
    local received = type(var)

    if expected == "any" or received == expected then
        return true, received
    end

    -- Supporto per tipi speciali
    if expected == "integer" then
        local isInt = received == "number" and (var % 1 == 0)
        return isInt, isInt and "integer" or received
    end

    -- Controllo unioni con cache: "string|number", "table|nil", etc.
    if expected:find("|", 1, true) then
        local union = getUnionTypes(expected)
        for i = 1, #union do
            local singleExpected = union[i]
            if singleExpected == "integer" then
                if received == "number" and (var % 1 == 0) then
                    return true, "integer"
                end
            elseif received == singleExpected then
                return true, received
            end
        end
    end

    return false, received
end

--#endregion

--#region Type Assertion

---Assicura che un argomento o campo abbia il tipo atteso, lanciando un errore formattato in caso contrario.
---@param id number | string    indice dell'argomento (numero) o nome del parametro/campo (stringa)
---@param var any               valore da controllare
---@param expected string       tipo atteso o unione di tipi (es. "string", "number|string", "function")
---@param level? integer        livello dello stack per la traccia dell'errore (default 2)
---@return boolean
function _ENV.assertType(id, var, expected, level)
    local isValid, received = validateType(var, expected)

    if not isValid then
        level = level or 2

        local label = type(id) == "string" and ("argument \"%s\""):format(id) or ("argument #%s"):format(id)
        error(("expected %s to have type \"%s\" (received %s)"):format(label, expected, received), level + 1)
    end

    return true
end

--#endregion
