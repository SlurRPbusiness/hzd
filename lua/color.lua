---@meta

---@class Color : classlib
---@field red number
---@field green number
---@field blue number
---@field alpha number
---@field hasAlpha boolean
---@field toHex fun(self: Color): string
---@field toRGB fun(self: Color): integer, integer, integer
local Color = class("Color") --[[@as Color : classlib ]]

---@class Colors
---@field White Color
---@field Black Color
---@field Grey Color
---@field LightGrey Color
---@field DarkGrey Color
---@field Gray Color
---@field LightGray Color
---@field DarkGray Color
---@field Red Color
---@field Green Color
---@field Blue Color
---@field LightRed Color
---@field LightGreen Color
---@field LightBlue Color
---@field DarkRed Color
---@field DarkGreen Color
---@field DarkBlue Color
---@field Cyan Color
---@field Magenta Color
---@field Yellow Color
---@field LightCyan Color
---@field LightMagenta Color
---@field LightYellow Color
---@field DarkCyan Color
---@field DarkMagenta Color
---@field DarkYellow Color
---@field Invisible Color
---@field SeeThrough Color
---@field MISSING_COLOR Color
local Colors

local floor = math.floor
local clamp = math.clamp
local format = string.format

--#region Internals

local function normalize(value)
    return floor(clamp(value, 0, 255))
end

local function validate(...)
    for i = 1, select("#", ...) do
        local value = select(i, ...)

        if value ~= nil and type(value) ~= "number" then
            error(format("Color: expected argument %d to be a number (received %s)", i, type(value)), 3)
        end
    end
end

--#endregion

--#region Constructor

---@param red? number
---@param green? number
---@param blue? number
---@param alpha? number
function Color:constructor(red, green, blue, alpha)
    validate(red, green, blue, alpha)

    if red == nil then
        assert(green == nil and blue == nil and alpha == nil, "RGB components must be provided together")
        local missing = Colors.MISSING_COLOR

        self.red      = missing.red
        self.green    = missing.green
        self.blue     = missing.blue
        self.alpha    = missing.alpha
        self.hasAlpha = missing.hasAlpha

        return
    end

    assert(green ~= nil and blue ~= nil, "red, green and blue components are required")

    self.red      = normalize(red)
    self.green    = normalize(green)
    self.blue     = normalize(blue)
    self.hasAlpha = alpha ~= nil
    self.alpha    = alpha == nil and 255 or normalize(alpha)
end

--#endregion

--#region Methods

---Restituisce un nuovo colore con alpha differente.
---@param alpha number
---@return Color
function Color:setAlpha(alpha)
    validate(alpha)
    assert(alpha ~= nil, "alpha is required")

    local red, green, blue = self:toRGB()
    return Color(red, green, blue, alpha)
end

---Restituisce una copia del colore.
---@return Color
function Color:clone()
    local red, green, blue = self:toRGB()

    if self.hasAlpha then
        return Color(red, green, blue, self.alpha)
    end

    return Color(red, green, blue)
end

---Restituisce i componenti RGBA.
---@return number, number, number, number
function Color:unpack()
    local red, green, blue = self:toRGB()
    return red, green, blue, self.alpha
end

---Restituisce i componenti RGB come tre valori Lua.
---@return integer red
---@return integer green
---@return integer blue
function Color:toRGB()
    return self.red, self.green, self.blue
end

---Restituisce il colore in formato CSS #RRGGBB o #RRGGBBAA se l'alpha è stato fornito.
---@return string
function Color:toHex()
    local red, green, blue = self:toRGB()

    if self.hasAlpha then
        return format("#%02X%02X%02X%02X", red, green, blue, self.alpha)
    end

    return format("#%02X%02X%02X", red, green, blue)
end

---Confronta due colori.
---@param other Color
---@return boolean
function Color:equals(other)
    return Color.instanceOf(other, Color)
        and self.red == other.red
        and self.green == other.green
        and self.blue == other.blue
        and self.alpha == other.alpha
end

---Restituisce la rappresentazione testuale.
---@return string
function Color:__tostring()
    return format("Color(%d, %d, %d, %d)", self.red, self.green, self.blue, self.alpha)
end

--#endregion

--#region Presets

Colors = setmetatable({
    White         = Color(255, 255, 255),
    Black         = Color(0, 0, 0),

    -- Grayscale
    Grey          = Color(60, 64, 67),
    LightGrey     = Color(75, 76, 79),
    DarkGrey      = Color(41, 42, 45),

    Gray          = Color(60, 64, 67),
    LightGray     = Color(75, 76, 79),
    DarkGray      = Color(41, 42, 45),

    -- RGB
    Red           = Color(255, 0, 0),
    Green         = Color(0, 255, 0),
    Blue          = Color(0, 0, 255),

    LightRed      = Color(127, 127, 127),
    LightGreen    = Color(127, 255, 127),
    LightBlue     = Color(127, 127, 255),

    DarkRed       = Color(127, 0, 0),
    DarkGreen     = Color(0, 127, 0),
    DarkBlue      = Color(0, 0, 127),

    -- CMY
    Cyan          = Color(0, 255, 255),
    Magenta       = Color(255, 0, 255),
    Yellow        = Color(255, 255, 0),

    LightCyan     = Color(127, 255, 255),
    LightMagenta  = Color(255, 127, 255),
    LightYellow   = Color(255, 255, 127),

    DarkCyan      = Color(0, 127, 127),
    DarkMagenta   = Color(127, 0, 127),
    DarkYellow    = Color(127, 127, 0),

    -- Transparency
    Invisible     = Color(0, 0, 0, 0),
    SeeThrough    = Color(0, 0, 0, 0),

    -- Missing
    MISSING_COLOR = Color(255, 0, 255)
}, {
    __index = function(self)
        return rawget(self, "MISSING_COLOR")
    end
})

_ENV.Color = Color
_ENV.Colors = Colors

--#endregion

return Color, Colors
