---@meta

---@class base64lib
---@field encode fun(value: string): string
---@field decode fun(value: string): string?, string?
---@field urlEncode fun(value: string): string
---@field urlDecode fun(value: string): string?, string?

local base64 = {}

local alphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789+/"
local urlAlphabet = "ABCDEFGHIJKLMNOPQRSTUVWXYZabcdefghijklmnopqrstuvwxyz0123456789-_"

local byte, char, concat, rep = string.byte, string.char, table.concat, string.rep

local encodeMap, urlEncodeMap = {}, {}
local decodeMap, urlDecodeMap = {}, {}

for index = 1, 64 do
    local standard = byte(alphabet, index)
    local url = byte(urlAlphabet, index)
    local value = index - 1

    encodeMap[index] = char(standard)
    urlEncodeMap[index] = char(url)

    decodeMap[standard] = value
    urlDecodeMap[url] = value
end

local function encode(value, map, padding)
    assertType("value", value, "string")

    local output = {}
    local outputIndex = 0
    local length = #value

    for index = 1, length, 3 do
        local first, second, third = byte(value, index, index + 2)

        second = second or 0
        third = third or 0

        local block = (first << 16) | (second << 8) | third
        local remaining = length - index

        local a = ((block >> 18) & 0x3f) + 1
        local b = ((block >> 12) & 0x3f) + 1
        local c = ((block >> 6) & 0x3f) + 1
        local d = (block & 0x3f) + 1

        outputIndex = outputIndex + 1
        output[outputIndex] = map[a] .. map[b] ..
            (remaining >= 1 and map[c] or (padding and "=" or "")) ..
            (remaining >= 2 and map[d] or (padding and "=" or ""))
    end

    return concat(output)
end

local function decode(value, map)
    local length = #value

    if length == 0 then
        return ""
    end

    if length % 4 ~= 0 then
        return nil, "Base64 length must be a multiple of four"
    end

    local output = {}
    local outputIndex = 0

    for index = 1, length, 4 do
        local a, b, c, d = byte(value, index, index + 3)

        local first = map[a]
        local second = map[b]
        local third = c == 61 and 0 or map[c]
        local fourth = d == 61 and 0 or map[d]

        if first == nil or second == nil or third == nil or fourth == nil then
            return nil, "Base64 contains invalid characters"
        end

        local last = index + 3 == length

        if c == 61 then
            if not last or d ~= 61 or (second & 0x0f) ~= 0 then
                return nil, "Base64 padding is invalid"
            end
        elseif d == 61 then
            if not last or (third & 0x03) ~= 0 then
                return nil, "Base64 padding is invalid"
            end
        end

        local block = (first << 18) | (second << 12) | (third << 6) | fourth

        outputIndex = outputIndex + 1

        if c == 61 then
            output[outputIndex] = char((block >> 16) & 0xff)
        elseif d == 61 then
            output[outputIndex] = char(
                (block >> 16) & 0xff,
                (block >> 8) & 0xff
            )
        else
            output[outputIndex] = char(
                (block >> 16) & 0xff,
                (block >> 8) & 0xff,
                block & 0xff
            )
        end
    end

    return concat(output)
end

function base64.encode(value)
    return encode(value, encodeMap, true)
end

function base64.decode(value)
    assertType("value", value, "string")
    return decode(value, decodeMap)
end

function base64.urlEncode(value)
    return encode(value, urlEncodeMap, false)
end

function base64.urlDecode(value)
    assertType("value", value, "string")

    local length = #value

    for index = 1, length do
        if urlDecodeMap[byte(value, index)] == nil then
            return nil, "Base64 URL contains invalid characters"
        end
    end

    local remainder = length % 4

    if remainder == 1 then
        return nil, "Base64 URL length is invalid"
    end

    if remainder ~= 0 then
        value = value .. rep("=", 4 - remainder)
    end

    return decode(value, urlDecodeMap)
end

--#endregion

---@class sha256lib
---@field digest fun(value: string): string
---@field hex fun(value: string): string
---@field base64 fun(value: string): string

local sha256 = {}

--#region SHA-256

local mask = 0xffffffff

local constants <const> = {
    0x428a2f98, 0x71374491, 0xb5c0fbcf, 0xe9b5dba5, 0x3956c25b, 0x59f111f1, 0x923f82a4, 0xab1c5ed5,
    0xd807aa98, 0x12835b01, 0x243185be, 0x550c7dc3, 0x72be5d74, 0x80deb1fe, 0x9bdc06a7, 0xc19bf174,
    0xe49b69c1, 0xefbe4786, 0x0fc19dc6, 0x240ca1cc, 0x2de92c6f, 0x4a7484aa, 0x5cb0a9dc, 0x76f988da,
    0x983e5152, 0xa831c66d, 0xb00327c8, 0xbf597fc7, 0xc6e00bf3, 0xd5a79147, 0x06ca6351, 0x14292967,
    0x27b70a85, 0x2e1b2138, 0x4d2c6dfc, 0x53380d13, 0x650a7354, 0x766a0abb, 0x81c2c92e, 0x92722c85,
    0xa2bfe8a1, 0xa81a664b, 0xc24b8b70, 0xc76c51a3, 0xd192e819, 0xd6990624, 0xf40e3585, 0x106aa070,
    0x19a4c116, 0x1e376c08, 0x2748774c, 0x34b0bcb5, 0x391c0cb3, 0x4ed8aa4a, 0x5b9cca4f, 0x682e6ff3,
    0x748f82ee, 0x78a5636f, 0x84c87814, 0x8cc70208, 0x90befffa, 0xa4506ceb, 0xbef9a3f7, 0xc67178f2,
}

local byte, char, concat, rep = string.byte, string.char, table.concat, string.rep

local function rotateRight(value, amount)
    return ((value >> amount) | (value << (32 - amount))) & mask
end

local function wordBytes(value)
    return char(
        (value >> 24) & 0xff,
        (value >> 16) & 0xff,
        (value >> 8) & 0xff,
        value & 0xff
    )
end

local hexMap = {}
local hexAlphabet = "0123456789abcdef"

for value = 0, 255 do
    hexMap[value] = char(
        byte(hexAlphabet, (value >> 4) + 1),
        byte(hexAlphabet, (value & 0x0f) + 1)
    )
end

function sha256.digest(value)
    assertType("value", value, "string")

    local bitLength = #value * 8
    local padded = value .. char(0x80)

    padded = padded .. rep("\0", (56 - (#padded % 64)) % 64)
    padded = padded .. wordBytes((bitLength >> 32) & mask) .. wordBytes(bitLength & mask)

    local hash = {
        0x6a09e667, 0xbb67ae85, 0x3c6ef372, 0xa54ff53a,
        0x510e527f, 0x9b05688c, 0x1f83d9ab, 0x5be0cd19,
    }

    local schedule = {}

    for offset = 1, #padded, 64 do
        for index = 1, 16 do
            local position = offset + (index - 1) * 4
            local a, b, c, d = byte(padded, position, position + 3)

            schedule[index] = ((a << 24) | (b << 16) | (c << 8) | d) & mask
        end

        for index = 17, 64 do
            local previous15 = schedule[index - 15]
            local previous2 = schedule[index - 2]

            local sigma0 = rotateRight(previous15, 7) ~ rotateRight(previous15, 18) ~ (previous15 >> 3)
            local sigma1 = rotateRight(previous2, 17) ~ rotateRight(previous2, 19) ~ (previous2 >> 10)

            schedule[index] = (schedule[index - 16] + sigma0 + schedule[index - 7] + sigma1) & mask
        end

        local a, b, c, d = hash[1], hash[2], hash[3], hash[4]
        local e, f, g, h = hash[5], hash[6], hash[7], hash[8]

        for index = 1, 64 do
            local sum1 = rotateRight(e, 6)
                ~ rotateRight(e, 11)
                ~ rotateRight(e, 25)

            local choose = (e & f) ~ ((~e) & g)
            local temp1 = (h + sum1 + choose + constants[index] + schedule[index]) & mask

            local sum0 = rotateRight(a, 2) ~ rotateRight(a, 13) ~ rotateRight(a, 22)

            local majority = (a & b) ~ (a & c) ~ (b & c)
            local temp2 = (sum0 + majority) & mask

            h = g
            g = f
            f = e
            e = (d + temp1) & mask
            d = c
            c = b
            b = a
            a = (temp1 + temp2) & mask
        end

        hash[1] = (hash[1] + a) & mask
        hash[2] = (hash[2] + b) & mask
        hash[3] = (hash[3] + c) & mask
        hash[4] = (hash[4] + d) & mask
        hash[5] = (hash[5] + e) & mask
        hash[6] = (hash[6] + f) & mask
        hash[7] = (hash[7] + g) & mask
        hash[8] = (hash[8] + h) & mask
    end

    local digest = {}

    for index = 1, 8 do
        digest[index] = wordBytes(hash[index])
    end

    return concat(digest)
end

function sha256.hex(value)
    local digest = sha256.digest(value)
    local output = {}

    for index = 1, #digest do
        output[index] = hexMap[byte(digest, index)]
    end

    return concat(output)
end

function sha256.base64(value)
    return base64.urlEncode(sha256.digest(value))
end

--#endregion

---@class cryptolib
---@field base64 base64lib
---@field sha256 sha256lib

local crypto = {
    base64 = base64,
    sha256 = sha256
}

_ENV.base64 = base64
_ENV.sha256 = sha256
_ENV.crypto = crypto
