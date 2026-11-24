---@meta

---@class Morse : classlib
---@field separator string
---@field wordSeparator string
---@field new fun(separator?: string, wordSeparator?: string): Morse
local Morse = class("Morse") --[[@as Morse]]

--#region Internals

local MORSE = {
    A = ".-",
    B = "-...",
    C = "-.-.",
    D = "-..",
    E = ".",
    F = "..-.",
    G = "--.",
    H = "....",
    I = "..",
    J = ".---",
    K = "-.-",
    L = ".-..",
    M = "--",
    N = "-.",
    O = "---",
    P = ".--.",
    Q = "--.-",
    R = ".-.",
    S = "...",
    T = "-",
    U = "..-",
    V = "...-",
    W = ".--",
    X = "-..-",
    Y = "-.--",
    Z = "--..",

    ["0"] = "-----",
    ["1"] = ".----",
    ["2"] = "..---",
    ["3"] = "...--",
    ["4"] = "....-",
    ["5"] = ".....",
    ["6"] = "-....",
    ["7"] = "--...",
    ["8"] = "---..",
    ["9"] = "----.",

    ["."] = ".-.-.-",
    [","] = "--..--",
    ["?"] = "..--..",
    ["'"] = ".----.",
    ["!"] = "-.-.--",
    ["/"] = "-..-.",
    ["("] = "-.--.",
    [")"] = "-.--.-",
    ["&"] = ".-...",
    [":"] = "---...",
    [";"] = "-.-.-.",
    ["="] = "-...-",
    ["+"] = ".-.-.",
    ["-"] = "-....-",
    ["_"] = "..--.-",
    ['"'] = ".-..-.",
    ["$"] = "...-..-",
    ["@"] = ".--.-.",
}

local REVERSE = {}

for char, code in pairs(MORSE) do
    REVERSE[code] = char
end

--#endregion

--#region Constructor

---@param separator? string separatore tra caratteri
---@param wordSeparator? string separatore tra parole
function Morse:constructor(separator, wordSeparator)
    self.separator     = separator or " "
    self.wordSeparator = wordSeparator or " / "
end

--#endregion

--#region Encode

---Converte una stringa in codice Morse.
---@param text string
---@return string
function Morse:encode(text)
    assert(type(text) == "string", "text must be a string")

    local result = {}

    for word in text:upper():gmatch("%S+") do
        local encoded = {}

        for i = 1, #word do
            local char = word:sub(i, i)
            local code = MORSE[char]

            if code then
                encoded[#encoded + 1] = code
            end
        end

        if #encoded > 0 then
            result[#result + 1] = table.concat(encoded, self.separator)
        end
    end

    return table.concat(result, self.wordSeparator)
end

--#endregion

--#region Decode

---Converte il codice Morse in una stringa.
---@param text string
---@return string
function Morse:decode(text)
    assert(type(text) == "string", "text must be a string")

    local result = {}

    for word in text:gmatch("[^/]+") do
        local decoded = {}

        for code in word:gmatch("%S+") do
            local char = REVERSE[code]

            if char then
                decoded[#decoded + 1] = char
            end
        end

        result[#result + 1] = table.concat(decoded)
    end

    return table.concat(result, " ")
end

--#endregion

---@type table<string, any>
local morseModule = setmetatable({}, {
    __call = function(_, separator, wordSeparator)
        return Morse.new(separator, wordSeparator)
    end,
})

_ENV.morse = morseModule
