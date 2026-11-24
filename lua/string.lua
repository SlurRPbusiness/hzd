---@meta

---@class string: stringlib
string = string

---Rimuove gli spazi bianchi a inizio e fine stringa.
---@param value string
---@return string
function string.trim(value)
    assert(type(value) == "string", "value must be a string")
    return (value:gsub("^%s*(.-)%s*$", "%1"))
end

---Controlla se una stringa contiene solo spazi bianchi o è vuota.
---@param value any
---@return boolean
function string.isBlank(value)
    assert(type(value) == "string", "value must be a string")
    return string.trim(value) == ""
end

function string.replace(s, str1, str2)
    if type(str1) == "table" then
        local handler = type(str2) == "function" and str2 or function(k) return table.concat({ "$", k }, "") end
        for k, v in pairs(str1) do
            s = table.concat(string.split(s, handler(k)), v)
        end
    elseif str1 == "" then
        local parts = { str2 }
        for i = 1, #s do
            parts[#parts + 1] = s:sub(i, i)
            parts[#parts + 1] = str2
        end
        s = table.concat(parts)
    else
        s = table.concat(string.split(s, str1), str2)
    end

    return s
end

---Controlla se una stringa inizia con il prefisso indicato.
---@param value string
---@param prefix string
---@return boolean
function string.startsWith(value, prefix)
    assert(type(value) == "string", "value must be a string")
    assert(type(prefix) == "string", "prefix must be a string")
    return value:sub(1, #prefix) == prefix
end

---Controlla se una stringa termina con il suffisso indicato.
---@param value string
---@param suffix string
---@return boolean
function string.endsWith(value, suffix)
    assert(type(value) == "string", "value must be a string")
    assert(type(suffix) == "string", "suffix must be a string")

    if suffix == "" then
        return true
    end

    return value:sub(- #suffix) == suffix
end

---Cerca una sottostringa senza interpretare pattern Lua.
---@param value string
---@param needle string
---@return boolean
function string.contains(value, needle)
    return string.find(value, needle, 1, true) ~= nil
end

---Divide una stringa usando un separatore letterale e conserva i campi vuoti.
---@param value string
---@param separator string
---@return string[]
function string.split(value, separator)
    assert(type(value) == "string", "value must be a string")
    assert(type(separator) == "string" and separator ~= "", "separator must be a non-empty string")

    local result = {}
    local startIndex = 1

    while true do
        local first, last = value:find(separator, startIndex, true)

        if not first then
            result[#result + 1] = value:sub(startIndex)
            break
        end

        result[#result + 1] = value:sub(startIndex, first - 1)
        startIndex = last + 1
    end

    return result
end

---Unisce una sequenza di valori in una stringa.
---@param values any[]
---@param separator? string
---@return string
function string.join(values, separator)
    return table.concat(values, separator or "")
end

--#region Generation

local random = math.random
local concat = table.concat

local function randomNumber()
    return tostring(random(0, 9))
end

local function randomUpper()
    return string.char(random(65, 90))
end

local function randomLower()
    return string.char(random(97, 122))
end

local function randomAlphaNumeric()
    return random(0, 1) == 1 and randomUpper() or randomNumber()
end

local randomPatterns = {
    ['1'] = randomNumber,
    ['A'] = randomUpper,
    ['a'] = randomLower,
    ['.'] = randomAlphaNumeric
}

---Genera una stringa casuale usando un pattern.
---1 = numero, A = maiuscola, a = minuscola, . = alfanumerico.
---^ rende letterale il carattere successivo.
---@param pattern string
---@param length? integer
---@return string
function string.random(pattern, length)
    assert(type(pattern) == 'string', 'pattern must be a string')
    assert(pattern ~= '', 'pattern must not be empty')

    if length ~= nil then
        assert(type(length) == 'number' and length >= 0 and length % 1 == 0,
            'length must be a non-negative integer')
    end

    local result = {}
    local patternLength = #pattern
    local outputLength = length or patternLength
    local index = 1

    while #result < outputLength do
        if index > patternLength then
            result[#result + 1] = " "
        else
            local current = pattern:sub(index, index)

            if current == "^" then
                index = index + 1
                current = pattern:sub(index, index)

                assert(current ~= "", "pattern cannot end with ^")
            else
                local generator = randomPatterns[current]
                current = generator and generator() or current
            end

            result[#result + 1] = current
            index = index + 1
        end
    end

    return concat(result)
end

--#endregion

--#region Transformation

---Converte il primo carattere in maiuscolo e il resto in minuscolo.
---@param value string
---@return string
function string.capitalize(value)
    assert(type(value) == "string", "value must be a string")

    if value == "" then
        return value
    end

    return value:sub(1, 1):upper() .. value:sub(2):lower()
end

---Converte la prima lettera di ogni parola in maiuscolo.
---@param value string
---@return string
function string.titleCase(value)
    assert(type(value) == "string", "value must be a string")

    local tc = value:gsub("(%a)([%w_']*)", function(first, rest)
        return first:upper() .. rest:lower()
    end)

    return tc
end

---Rimuove gli spazi a sinistra.
---@param value string
---@return string
function string.trimStart(value)
    assert(type(value) == "string", "value must be a string")
    return value:match("^%s*(.*)")
end

---Rimuove gli spazi a destra.
---@param value string
---@return string
function string.trimEnd(value)
    assert(type(value) == "string", "value must be a string")
    return value:match("(.-)%s*$")
end

---Ripete la stringa n volte con un separatore opzionale.
---@param value string
---@param n integer
---@param separator? string
---@return string
function string.repeat_(value, n, separator)
    assert(type(value) == "string", "value must be a string")
    assert(type(n) == "number" and n % 1 == 0 and n >= 0, "n must be a non-negative integer")

    separator = separator or ""

    if n == 0 then
        return ""
    end

    local parts = {}

    for i = 1, n do
        parts[i] = value
    end

    return table.concat(parts, separator)
end

---Allinea a destra riempiendo con un carattere a sinistra.
---@param value string
---@param width integer
---@param char? string
---@return string
function string.padStart(value, width, char)
    assert(type(value) == "string", "value must be a string")
    assert(type(width) == "number" and width % 1 == 0, "width must be an integer")

    char = char or " "
    assert(type(char) == "string" and #char > 0, "char must be a non-empty string")
    local padding = width - #value

    if padding <= 0 then
        return value
    end

    return string.repeat_(char, padding) .. value
end

---Allinea a sinistra riempiendo con un carattere a destra.
---@param value string
---@param width integer
---@param char? string
---@return string
function string.padEnd(value, width, char)
    assert(type(value) == "string", "value must be a string")
    assert(type(width) == "number" and width % 1 == 0, "width must be an integer")

    char = char or " "
    assert(type(char) == "string" and #char > 0, "char must be a non-empty string")
    local pad = width - #value

    if pad <= 0 then
        return value
    end

    return value .. char:rep(pad)
end

--#endregion

--#region Conversion

---Converte la stringa in un array di caratteri.
---@param value string
---@return string[]
function string.toArray(value)
    assert(type(value) == "string", "value must be a string")

    local result = {}

    for char in value:gmatch(".") do
        result[#result + 1] = char
    end

    return result
end

---Converte la stringa in numero, restituisce nil se non valida.
---@param value string
---@return number?
function string.toNumber(value)
    assert(type(value) == "string", "value must be a string")
    return tonumber(value)
end

---Converte la stringa in booleano ("true" / "1" → true, tutto il resto → false).
---@param value string
---@return boolean
function string.toBoolean(value)
    assert(type(value) == "string", "value must be a string")
    return value == "true" or value == "1"
end

--#endregion

--#region Formatting

---Formatta una stringa con string.format.
---@param value string
---@param ... any
---@return string
function string.fmt(value, ...)
    assert(type(value) == "string", "value must be a string")
    return value:format(...)
end

--#endregion
