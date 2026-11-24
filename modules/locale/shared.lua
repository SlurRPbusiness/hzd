---@meta

---@class localelib
---@field current string
---@field default string
---@field languages table<integer, string>
---@field dateFormats table<integer, string>
---@field init fun(lang?: string, resource?: string): boolean
---@field load fun(lang: string, namespace: string, resource?: string): boolean
---@field set fun(lang: string): boolean
---@field get fun(key: string, ...: any): string
---@field has fun(key: string): boolean
---@field setDictionary fun(lang: string, dictionary: table<string, any>)
---@field export fun(lang?: string): table<string, any>
---@field getGameLanguage fun(): string
---@field getSystemLanguage fun(): integer
---@field getDateFormat fun(): string
---@field getRegion fun(): string?
local locale = {}

local isClient = hzd:is("client")
local dictionaries = {}

_ENV.locale = setmetatable(locale, {
    __call = function(_, key, ...)
        return locale.get(key, ...)
    end,
})

-- GET_CURRENT_LANGUAGE restituisce l'ID della lingua di GTA, non il paese fisico.
local gameLanguages = {
    [0] = "en",
    [1] = "fr",
    [2] = "de",
    [3] = "it",
    [4] = "es",
    [5] = "pt",
    [6] = "pl",
    [7] = "ru",
    [8] = "ko",
    [9] = "zh-tw",
    [10] = "ja",
    [11] = "es-mx",
    [12] = "zh-cn",
}

local dateFormats = {
    [0] = "DD/MM/YYYY",
    [1] = "MM/DD/YYYY",
    [2] = "YYYY/MM/DD",
}

locale.default = "it"
locale.languages = gameLanguages
locale.dateFormats = dateFormats

--#region Helpers

---@param lang string
---@return string
local function normalizeLanguage(lang)
    assertType("lang", lang, "string")

    lang = lang:lower():gsub("_", "-")

    assert(
        lang:match("^[%w%-]+$")
        and lang:sub(1, 1) ~= "-"
        and lang:sub(-1) ~= "-"
        and not lang:find("--", 1, true),
        "lang must be a language code such as 'it' or 'pt-BR'"
    )

    return lang
end

---@param target table
---@param source table
local function mergeTables(target, source)
    for key, value in pairs(source) do
        if type(value) == "table" then
            if type(target[key]) ~= "table" then
                target[key] = {}
            end

            mergeTables(target[key], value)
        else
            target[key] = value
        end
    end
end

---@param dictionary table?
---@param key string
---@return string?
local function resolveKey(dictionary, key)
    if type(dictionary) ~= "table" then
        return nil
    end

    local direct = dictionary[key]

    if type(direct) == "string" then
        return direct
    end

    local current = dictionary

    for _, part in ipairs(string.split(key, ".")) do
        if type(current) ~= "table" then
            return nil
        end

        current = current[part]
    end

    return type(current) == "string" and current or nil
end

---@param key string
---@return string?
local function findTranslation(key)
    local current = locale.current
    local base = current:match("^([%w]+)")
    local value = resolveKey(dictionaries[current], key)

    if value then
        return value
    end

    if base and base ~= current then
        value = resolveKey(dictionaries[base], key)

        if value then
            return value
        end
    end

    if locale.default ~= current and locale.default ~= base then
        return resolveKey(dictionaries[locale.default], key)
    end

    return nil
end

--#endregion

--#region Translation API

---Restituisce una traduzione e formatta eventuali parametri con string.format.
---@param key string
---@param ... any
---@return string
function locale.get(key, ...)
    assertType("key", key, "string")

    local text = findTranslation(key) or key

    if select("#", ...) == 0 then
        return text
    end

    local success, formatted = pcall(string.format, text, ...)
    return success and formatted or text
end

---Controlla se la chiave esiste nella lingua corrente o nei fallback.
---@param key string
---@return boolean
function locale.has(key)
    assertType("key", key, "string")
    return findTranslation(key) ~= nil
end

--#endregion

--#region Dictionary Loading

---Carica un dizionario da locales/{lingua}/{namespace}.json.
---@param lang string
---@param namespace string
---@param resource? string
---@return boolean
function locale.load(lang, namespace, resource)
    lang = normalizeLanguage(lang)
    assertType("namespace", namespace, "string")
    assert(namespace:match("^[%w_%-]+$"), "namespace must be a simple file name")

    resource = resource or GetCurrentResourceName()
    assertType("resource", resource, "string")

    local path = ("locales/%s/%s.json"):format(lang, namespace)
    local dictionary = load.json(resource, path)

    if type(dictionary) ~= "table" then
        return false
    end

    local target = dictionaries[lang] or {}
    mergeTables(target, dictionary)
    dictionaries[lang] = target
    return true
end

---Carica tutti i JSON dichiarati nel manifest per la lingua richiesta.
---@param lang? string
---@param resource? string
---@return boolean loaded
function locale.init(lang, resource)
    lang = normalizeLanguage(lang or locale.current)
    resource = resource or GetCurrentResourceName()
    assertType("resource", resource, "string")

    local prefix = ("locales/%s/"):format(lang)
    local loaded = false
    local fileCount = GetNumResourceMetadata(resource, "file")

    for index = 0, fileCount - 1 do
        local path = GetResourceMetadata(resource, "file", index)

        if type(path) == "string" and path:sub(1, #prefix) == prefix then
            local namespace = path:sub(#prefix + 1):match("^([%w_%-]+)%.json$")

            if namespace and locale.load(lang, namespace, resource) then
                loaded = true
            end
        end
    end

    return loaded
end

---Registra un dizionario già disponibile in memoria.
---@param lang string
---@param dictionary table<string, any>
function locale.setDictionary(lang, dictionary)
    lang = normalizeLanguage(lang)
    assert(type(dictionary) == "table", "dictionary must be a table")
    dictionaries[lang] = dictionary
end

---Esporta un dizionario autonomo per UI e sistemi esterni, applicando le stesse precedenze di locale.get.
---@param lang? string
---@return table<string, any>
function locale.export(lang)
    lang = normalizeLanguage(lang or locale.current)

    local exported = {}
    local base = lang:match("^([%w]+)")

    if dictionaries[locale.default] then
        mergeTables(exported, dictionaries[locale.default])
    end

    if base and base ~= locale.default and dictionaries[base] then
        mergeTables(exported, dictionaries[base])
    end

    if dictionaries[lang] then
        mergeTables(exported, dictionaries[lang])
    end

    return exported
end

---Imposta la lingua e carica i file della lingua e della sua variante base.
---@param lang string
---@return boolean loaded
function locale.set(lang)
    lang = normalizeLanguage(lang)
    locale.current = lang

    local loaded = dictionaries[lang] ~= nil or locale.init(lang)
    local base = lang:match("^([%w]+)")

    if base and base ~= lang and not dictionaries[base] then
        loaded = locale.init(base) or loaded
    end

    if isClient and nui and nui.send then
        nui.send("setLocale", {
            language = lang,
            translations = locale.export(lang),
        })
    end

    return loaded
end

--#endregion

--#region Native Language and Date Information

---Restituisce il codice lingua rilevato dalla native client GET_CURRENT_LANGUAGE.
---FiveM espone la lingua del gioco, non la provenienza geografica dell'utente.
---@return string
function locale.getGameLanguage()
    if not isClient then
        return locale.default
    end

    return gameLanguages[GetCurrentLanguage()] or locale.default
end

---Restituisce l'ID lingua nativo del client; sul server restituisce 0.
---@return integer
function locale.getSystemLanguage()
    if not isClient then
        return 0
    end

    return LocalizationGetSystemLanguage()
end

---Restituisce la regione presente nel codice selezionato, se disponibile.
---La regione deriva dalla lingua (es. es-MX), non dalla posizione GPS/IP.
---@return string?
function locale.getRegion()
    local region = locale.current:match("^[%w]+%-([%w]+)$")
    return region and region:upper() or nil
end

---Restituisce il formato data configurato nel client GTA V.
---@return string
function locale.getDateFormat()
    if not isClient then
        return dateFormats[0]
    end

    return dateFormats[LocalizationGetSystemDateFormat()] or dateFormats[0]
end

--#endregion

--#region Initialization

local convarName = ("%s:locale"):format(hzd.name)
local configuredLanguage = GetConvar(convarName, "")
local detectedLanguage = isClient and locale.getGameLanguage() or locale.default

locale.current = normalizeLanguage(configuredLanguage ~= "" and configuredLanguage or detectedLanguage)
locale.set(locale.current)

if locale.default ~= locale.current then
    locale.init(locale.default)
end

--#endregion
