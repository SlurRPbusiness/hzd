---@meta

local rawLoad = _ENV.load

---@class loadlib
load = {}

--#region Helpers

---Aggiunge l'estensione al percorso se non è già presente.
---@param path string
---@param ext string
---@return string
local function ensureExtension(path, ext)
    if not string.endsWith(path, ext) then
        return path .. ext
    end

    return path
end

---Normalizza gli argomenti: (path) -> (resource, path) oppure (resource, path).
---@param arg1 string
---@param arg2? string
---@return string resource
---@return string path
local function parsePath(arg1, arg2)
    assertType(1, arg1, "string")

    if arg2 then
        assertType(2, arg2, "string")
        return arg1, arg2
    end

    return GetCurrentResourceName(), arg1
end

--#endregion

--#region File Loaders

---Legge il contenuto testuale grezzo di un file dalla risorsa specificata o corrente.
---@param resourceOrPath string  nome risorsa oppure percorso se passato come unico argomento
---@param path? string           percorso del file
---@return string? content
function load.file(resourceOrPath, path)
    local res, targetPath = parsePath(resourceOrPath, path)
    return LoadResourceFile(res, targetPath)
end

---Carica e deserializza un file JSON. Aggiunge automaticamente l'estensione ".json" se omessa.
---@param resourceOrPath string  nome risorsa o percorso file (es. "config" o "config.json")
---@param path? string           percorso file se il primo argomento è la risorsa
---@return table?
function load.json(resourceOrPath, path)
    local res, targetPath = parsePath(resourceOrPath, path)
    targetPath = ensureExtension(targetPath, ".json")

    local content = LoadResourceFile(res, targetPath)

    if not content then
        return nil
    end

    local success, parsed = pcall(json.decode, content)
    if not success then
        error(("invalid JSON in '%s' (resource '%s'): %s"):format(targetPath, res, tostring(parsed)), 2)
    end

    return parsed
end

---Carica ed esegue un file Lua in modo sicuro. Aggiunge automaticamente l'estensione ".lua" se omessa.
---@param resourceOrPath string  nome risorsa o percorso file (es. "shared/config" o "config.lua")
---@param path? string           percorso file se il primo argomento è la risorsa
---@param env? table             ambiente di esecuzione opzionale (default _ENV)
---@return any ...               valore restituito dall'esecuzione del file Lua
function load.lua(resourceOrPath, path, env)
    local res, targetPath = parsePath(resourceOrPath, path)
    targetPath = ensureExtension(targetPath, ".lua")

    local content = LoadResourceFile(res, targetPath)

    if not content then
        error(("unable to read Lua file \"%s\" in resource \"%s\""):format(targetPath, res), 2)
    end

    local chunk, err = rawLoad(content, ("@%s/%s"):format(res, targetPath), "t", env or _ENV)

    if not chunk then
        error(("syntax error in \"%s\": %s"):format(targetPath, tostring(err)), 2)
    end

    return chunk()
end

--#endregion

--#region Smart Loader

---Rileva l'estensione o carica il file appropriato.
---@param resourceOrPath string
---@param path? string
---@return any
function load.auto(resourceOrPath, path)
    local res, targetPath = parsePath(resourceOrPath, path)

    if string.endsWith(targetPath, ".json") then
        return load.json(res, targetPath)
    elseif string.endsWith(targetPath, ".lua") then
        return load.lua(res, targetPath)
    end

    return load.file(res, targetPath)
end

--#endregion

--#region Metatable

setmetatable(load, {
    __call = function(_, arg1, ...)
        if type(arg1) == "string" and (arg1:find("%.%w+$") or LoadResourceFile(GetCurrentResourceName(), arg1)) then
            return load.auto(arg1, ...)
        end
        return rawLoad(arg1, ...)
    end,
})

_ENV.load = load

--#endregion
