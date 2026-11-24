---@meta

local rawPrint = _ENV.print

---@class printlib
local printLib = setmetatable({}, {
    __call = function(_, ...)
        rawPrint(...)
    end,
})

_ENV.print = printLib

--#region Table Inspection

---Converte qualsiasi valore o tabella in una stringa formattata leggibile per il debug.
---@param value any
---@param maxDepth? integer  profondità massima di ricorsione (default 5)
---@param indent? integer    livello di indentazione iniziale (default 0)
---@return string
local function dumpValue(value, maxDepth, indent)
    maxDepth = maxDepth or 5
    indent   = indent or 0

    local valType = type(value)

    if valType == "table" then
        if indent >= maxDepth then
            return "{ ... }"
        end

        local spaces    = string.rep("  ", indent)
        local subSpaces = string.rep("  ", indent + 1)
        local lines     = { "{\n" }

        for k, v in pairs(value) do
            local keyStr      = type(k) == "string" and ("\"" .. k .. "\"") or ("[" .. tostring(k) .. "]")
            lines[#lines + 1] = ("%s%s = %s,\n"):format(subSpaces, keyStr, dumpValue(v, maxDepth, indent + 1))
        end

        lines[#lines + 1] = spaces .. "}"
        return table.concat(lines)
    elseif valType == "string" then
        return ("\"%s\""):format(value)
    else
        return tostring(value)
    end
end

---Esegue un dump formattato a video di una tabella o valore.
---@param value any
---@param maxDepth? integer
function print.dump(value, maxDepth)
    print(dumpValue(value, maxDepth, 0))
end

---Alias per print.dump.
---@param tbl table
---@param maxDepth? integer
function print.table(tbl, maxDepth)
    print.dump(tbl, maxDepth)
end

--#endregion

--#region Formatted Logging

---Stampa un messaggio informativo colorato in verde.
---@param message string
---@param ... any
function print.info(message, ...)
    local text = select("#", ...) > 0 and message:format(...) or message
    print(("^2[INFO]^7 %s"):format(text))
end

---Stampa un avviso colorato in giallo.
---@param message string
---@param ... any
function print.warn(message, ...)
    local text = select("#", ...) > 0 and message:format(...) or message
    print(("^3[WARN]^7 %s"):format(text))
end

---Stampa un errore colorato in rosso.
---@param message string
---@param ... any
function print.error(message, ...)
    local text = select("#", ...) > 0 and message:format(...) or message
    print(("^1[ERROR]^7 %s"):format(text))
end

--#endregion
