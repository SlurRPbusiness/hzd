---@meta

-- ─────────────────────────────────────────────────────────
--  Regex – motore regex Lua minimalista
--  Espone:
--    Regex.new(pattern)        → istanza compilata
--    Regex.escape(str)         → stringa escaped per uso letterale
--    Regex.createList(w, opt)  → RegexList (word-filter, vedi #region RegexList)
-- ─────────────────────────────────────────────────────────

---@class RegexMatch
---@field value  string   Sottostringa catturata
---@field start  integer  Indice iniziale (1-based)
---@field finish integer  Indice finale   (1-based, inclusivo)

---@class Regex : classlib
---@field pattern  string
---@field new      fun(pattern: string): Regex
local Regex = class("Regex") --[[@as Regex]]

_ENV.Regex = Regex

-- ─────────────────────────────────────────────────────────
--  Native upvalue cache (micro-ottimizzazione per hot paths)
-- ─────────────────────────────────────────────────────────

local find   <const> = string.find
local match  <const> = string.match
local gmatch <const> = string.gmatch
local gsub   <const> = string.gsub
local sub    <const> = string.sub
local concat <const> = table.concat

-- ─────────────────────────────────────────────────────────
--  Helpers interni
-- ─────────────────────────────────────────────────────────

---Escapa tutti i caratteri speciali di pattern Lua in una stringa letterale.
---@param str string
---@return string
function Regex.escape(str)
    assertType("str", str, "string")
    return (gsub(str, "([%(%)%.%%%+%-%*%?%[%]%^%$])", "%%%1"))
end

-- ─────────────────────────────────────────────────────────
--  Constructor
-- ─────────────────────────────────────────────────────────

---@param pattern string   Pattern Lua standard (non PCRE).
function Regex:constructor(pattern)
    assertType("pattern", pattern, "string")
    assert(not string.isBlank(pattern), "pattern must not be blank")
    self.pattern = pattern
end

-- ─────────────────────────────────────────────────────────
--  Core API
-- ─────────────────────────────────────────────────────────

---Testa se il pattern ha almeno un match nella stringa.
---@param text string
---@param init? integer   Posizione iniziale (default 1).
---@return boolean
function Regex:test(text, init)
    assertType("text", text, "string")
    return find(text, self.pattern, init or 1) ~= nil
end

---Restituisce il primo match (valore + posizioni).
---@param text string
---@param init? integer
---@return RegexMatch?
function Regex:find(text, init)
    assertType("text", text, "string")
    local s, e = find(text, self.pattern, init or 1)
    if not s then return nil end
    return { value = sub(text, s, e), start = s, finish = e }
end

---Restituisce tutti i match non sovrapposti.
---@param text string
---@return RegexMatch[]
function Regex:findAll(text)
    assertType("text", text, "string")
    local results = {}
    local pos = 1
    while pos <= #text do
        local s, e = find(text, self.pattern, pos)
        if not s then break end
        results[#results + 1] = { value = sub(text, s, e), start = s, finish = e }
        pos = e + 1
    end
    return results
end

---Restituisce solo la sottostringa del primo match.
---@param text string
---@param init? integer
---@return string?
function Regex:match(text, init)
    assertType("text", text, "string")
    return match(text, self.pattern, init or 1)
end

---Restituisce tutti i valori catturati (come gmatch).
---@param text string
---@return string[]
function Regex:matchAll(text)
    assertType("text", text, "string")
    local results = {}
    for m in gmatch(text, self.pattern) do
        results[#results + 1] = m
    end
    return results
end

---Sostituisce ogni match con `replacement` (accetta anche funzione).
---@param text        string
---@param replacement string | fun(match: string): string
---@param maxReplace? integer
---@return string result
---@return integer  count
function Regex:replace(text, replacement, maxReplace)
    assertType("text", text, "string")
    assert(type(replacement) == "string" or type(replacement) == "function",
        "replacement must be a string or function")
    local result, n = gsub(text, self.pattern, replacement, maxReplace)
    return result, n
end

---Divide la stringa in segmenti separati dal pattern.
---@param text string
---@return string[]
function Regex:split(text)
    assertType("text", text, "string")
    local parts = {}
    local pos   = 1
    while pos <= #text do
        local s, e = find(text, self.pattern, pos)
        if not s then
            parts[#parts + 1] = sub(text, pos)
            break
        end
        parts[#parts + 1] = sub(text, pos, s - 1)
        pos = e + 1
    end
    return parts
end

-- ─────────────────────────────────────────────────────────
--  __tostring
-- ─────────────────────────────────────────────────────────

function Regex:__tostring()
    return ("Regex(%q)"):format(self.pattern)
end

-- ─────────────────────────────────────────────────────────
--  matchPattern  (helper globale usato da RegexList)
--  Simula un motore con step-limit: in Lua puro non c'è un
--  vero limite, ma esponiamo l'interfaccia attesa.
-- ─────────────────────────────────────────────────────────

---@param regex   Regex
---@param text    string
---@param init?   integer
---@param opts?   { steps?: integer }
---@return RegexMatch?
function _ENV.matchPattern(regex, text, init, opts)
    assert(Regex.instanceOf(regex, Regex), "regex must be a Regex instance")
    return regex:find(text, init)
end

-- ─────────────────────────────────────────────────────────
--  RegexList  (filtro parole – ex file standalone)
-- ─────────────────────────────────────────────────────────

---@class RegexListMatch
---@field word   string
---@field value  string
---@field start  integer
---@field finish integer

---@class RegexList : classlib
---@field entries table<string, table>
---@field allowed table<string, true>
---@field leet    boolean
---@field spaced  boolean
---@field mask    string
---@field dirty   boolean
---@field byFirst table<string, table[]>
---@field anywhere table[]
---@field new     fun(words: string[], options?: { allow?: string[], leet?: boolean, spaced?: boolean, mask?: string }): RegexList
local RegexList = class("RegexList") --[[@as RegexList]]

local gsub_   <const> = string.gsub
local find_   <const> = string.find
local match_  <const> = string.match
local lower_  <const> = string.lower
local sub_    <const> = string.sub
local format_ <const> = string.format
local byte_   <const> = string.byte

local FILLER           <const> = "\1"
local SEPARATOR        <const> = "[\1._%-]*"
local SEPARATOR_SPACED <const> = "[\\ \1._%-]*"
local GAP              <const> = "[\\ \1._%-]+"

local LEET <const> = {
    ["0"] = "o", ["1"] = "i", ["3"] = "e", ["4"] = "a",
    ["5"] = "s", ["7"] = "t", ["@"] = "a", ["$"] = "s",
}

-- UTF-8 two-byte accent folding (lead byte 0xC3)
local ACCENT_FOLD <const> = {}
local function foldRange(letter, first, last)
    for code = first, last do ACCENT_FOLD[code] = letter end
end
foldRange("a", 128, 133) foldRange("c", 135, 135) foldRange("e", 136, 139)
foldRange("i", 140, 143) foldRange("n", 145, 145) foldRange("o", 146, 150)
foldRange("u", 153, 156) foldRange("a", 160, 165) foldRange("c", 167, 167)
foldRange("e", 168, 171) foldRange("i", 172, 175) foldRange("n", 177, 177)
foldRange("o", 178, 182) foldRange("u", 185, 188)

local function normalize(text, leet)
    text = gsub_(text, "\226\128[\139-\141]", "\1\1\1")
    text = gsub_(text, "\239\187\191",        "\1\1\1")
    text = gsub_(text, "\194\173",            "\1\1")
    text = gsub_(text, "\195([\128-\191])", function(second)
        local letter = ACCENT_FOLD[byte_(second)]
        return letter and (letter .. FILLER) or nil
    end)
    text = lower_(text)
    if leet then
        text = gsub_(text, "[%w@$]+", function(run)
            if not find_(run, "%a") then return nil end
            return (gsub_(run, "[013457@$]", LEET))
        end)
    end
    return text
end

local function isAlnum(v)  return v ~= "" and find_(v, "^%w$") ~= nil end
local function isWordByte(v) return isAlnum(v) or v == FILLER end

local function startsWord(norm, pos)
    local i = pos - 1
    while i >= 1 and sub_(norm, i, i) == FILLER do i = i - 1 end
    return i < 1 or not isAlnum(sub_(norm, i, i))
end

local function tokenAround(norm, first, last)
    local s, e = first, last
    while s > 1 and isWordByte(sub_(norm, s - 1, s - 1)) do s = s - 1 end
    while isWordByte(sub_(norm, e + 1, e + 1)) do e = e + 1 end
    return (gsub_(sub_(norm, s, e), FILLER, ""))
end

local function plain(word, leet)
    return (gsub_(normalize(word, leet), "[\\ \1]", ""))
end

local function buildPattern(parts, spaced)
    local sep = spaced and SEPARATOR_SPACED or SEPARATOR
    local out = {}
    for p = 1, #parts do
        if p > 1 then out[#out + 1] = GAP end
        local part = parts[p]
        for i = 1, #part do
            local c = sub_(part, i, i)
            if find_(c, "^%w$") then
                out[#out + 1] = c .. "+"
            else
                out[#out + 1] = format_("\\x%02x", byte_(c))
            end
            if i < #part then out[#out + 1] = sep end
        end
    end
    out[#out + 1] = "\\x01*"
    return concat(out)
end

local function buildEntry(original, spaced, leet)
    local spec = original
    local prefix, anywhere = false, false
    if sub_(spec, -1) == "*" then prefix  = true; spec = sub_(spec, 1, -2) end
    if sub_(spec,  1, 1) == "*" then anywhere = true; spec = sub_(spec, 2) end

    local parts = {}
    for token in normalize(spec, leet):gmatch("%S+") do
        local clean = gsub_(token, "[^%w\128-\255]", "")
        if clean ~= "" then parts[#parts + 1] = clean end
    end
    if #parts == 0 then return nil end

    return {
        word     = original,
        regex    = Regex.new(buildPattern(parts, spaced)),
        first    = sub_(parts[1], 1, 1),
        prefix   = prefix,
        anywhere = anywhere,
    }
end

local function buildIndex(self)
    if not self.dirty then return end
    local byFirst, anywhere = {}, {}
    for _, entry in pairs(self.entries) do
        if entry.anywhere then
            anywhere[#anywhere + 1] = entry
        else
            local list = byFirst[entry.first]
            if not list then list = {}; byFirst[entry.first] = list end
            list[#list + 1] = entry
        end
    end
    self.byFirst  = byFirst
    self.anywhere = anywhere
    self.dirty    = false
end

local function bestAt(self, norm, text, pos, atWordStart, floor)
    local best

    local function try(entry)
        local m = matchPattern(entry.regex, norm, pos, { steps = 0 })
        if not m then return end
        if not entry.prefix and isAlnum(sub_(norm, m.finish + 1, m.finish + 1)) then return end

        local first, last = m.start, m.finish
        if entry.prefix   then while isWordByte(sub_(norm, last  + 1, last  + 1)) do last  = last  + 1 end end
        if entry.anywhere then while first > floor and isWordByte(sub_(norm, first - 1, first - 1)) do first = first - 1 end end

        if self.allowed[tokenAround(norm, first, last)] then return end

        if not best or (last - first) > (best.finish - best.start) then
            best = { word = entry.word, value = sub_(text, first, last), start = first, finish = last }
        end
    end

    if atWordStart then
        local list = self.byFirst[sub_(norm, pos, pos)]
        if list then for i = 1, #list do try(list[i]) end end
    end
    for i = 1, #self.anywhere do try(self.anywhere[i]) end
    return best
end

local function scan(self, text, firstOnly)
    buildIndex(self)
    local norm    = normalize(text, self.leet)
    local len     = #norm
    local results = {}
    local pos     = 1
    local floor   = 1

    while pos <= len do
        local best
        if isAlnum(sub_(norm, pos, pos)) then
            best = bestAt(self, norm, text, pos, startsWord(norm, pos), floor)
        end
        if best then
            results[#results + 1] = best
            if firstOnly then break end
            floor = best.finish + 1
            pos   = floor
        else
            pos = pos + 1
        end
    end
    return results
end

-- Constructor
---@param words   string[]
---@param options? { allow?: string[], leet?: boolean, spaced?: boolean, mask?: string }
function RegexList:constructor(words, options)
    assertType("words", words, "table")
    options     = options or {}
    self.leet   = options.leet  ~= false
    self.spaced = options.spaced == true
    self.mask   = options.mask  or "*"
    assertType("mask", self.mask, "string")

    self.entries  = {}
    self.allowed  = {}
    self.byFirst  = {}
    self.anywhere = {}
    self.dirty    = false

    local allow = options.allow or {}
    table.eachArray(allow, function(w) self.allowed[plain(w, self.leet)] = true end)
    table.eachArray(words, function(w) self:add(w) end)
end

function RegexList:add(word)
    assertType("word", word, "string")
    local key = lower_(match_(word, "^%s*(.-)%s*$"))
    if key == "" or self.entries[key] then return self end
    local entry = buildEntry(key, self.spaced, self.leet)
    assert(entry, "invalid word: " .. word)
    self.entries[key] = entry
    self.dirty = true
    return self
end

function RegexList:remove(word)
    assertType("word", word, "string")
    local key = lower_(match_(word, "^%s*(.-)%s*$"))
    if self.entries[key] then self.entries[key] = nil; self.dirty = true end
    return self
end

function RegexList:count() return table.size(self.entries) end

function RegexList:test(text)
    assertType("text", text, "string")
    return #scan(self, text, true) > 0
end

function RegexList:find(text)
    assertType("text", text, "string")
    return scan(self, text, true)[1]
end

function RegexList:matches(text)
    assertType("text", text, "string")
    return scan(self, text, false)
end

function RegexList:censor(text, mask)
    assertType("text", text, "string")
    mask = mask or self.mask
    assertType("mask", mask, "string")
    local found = scan(self, text, false)
    if #found == 0 then return text end

    local out, last = {}, 1
    table.eachArray(found, function(m)
        out[#out + 1] = sub_(text, last, m.start - 1)
        out[#out + 1] = (gsub_(sub_(text, m.start, m.finish), "[^\128-\191][\128-\191]*", function() return mask end))
        last = m.finish + 1
    end)
    out[#out + 1] = sub_(text, last)
    return concat(out)
end

---Crea una RegexList. Accetta sia Regex.createList(w, opt) che Regex:createList(w, opt).
---@param words    string[]
---@param options? { allow?: string[], leet?: boolean, spaced?: boolean, mask?: string }
---@param extra?   { allow?: string[], leet?: boolean, spaced?: boolean, mask?: string }
---@return RegexList
function Regex.createList(words, options, extra)
    if type(words) == "table" and words.createList ~= nil then
        words, options = options, extra
    end
    ---@type RegexList
    return RegexList.new(words or {}, options) --[[@as RegexList]]
end

_ENV.RegexList = RegexList
