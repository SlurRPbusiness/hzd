---@meta

---@diagnostic disable: invisible

---@class classlib
---@field __name       string
---@field __index      classlib
---@field constructor? fun(self: classlib, ...: any)
---@field super?       fun(self: classlib, ...: any)
---@field new          fun(...: any): classlib
---@field isClass      fun(self: classlib, cls: classlib): boolean
---@field instanceOf   fun(self: classlib, cls: classlib): boolean

local getinfo      = debug.getinfo

--#region Internals

local weakkeys     = { __mode = "k" }

---@type { [classlib]: { [function]: true } }
local classes      = setmetatable({}, weakkeys)
local constructors = setmetatable({}, weakkeys)

---Verifica il tipo di un argomento o campo, lanciando un errore se non corrisponde.
---@param id number | string
---@param var any
---@param expected type
local function assertType(id, var, expected)
    local received = type(var)

    if received ~= expected then
        error(("expected %s %s to have type \"%s\" (received %s)")
            :format(type(id) == "string" and "field" or "argument", id, expected, received), 3)
    end

    if expected == "table" and table.type(var) ~= "hash" then
        error(("expected argument %s to have table.type \"hash\" (received %s)")
            :format(id, table.type(var)), 3)
    end

    return true
end

---Rimuove il costruttore dalla classe e lo salva in cache.
---@param cls classlib
local function getConstructor(cls)
    local constructor = constructors[cls] or cls.constructor

    if cls.constructor then
        constructors[cls] = cls.constructor
        cls.constructor   = nil
    end

    return constructor
end

local function void() return "" end

---Verifica che la chiamata provenga da un metodo della classe o delle sue superclassi.
---@param cls classlib
---@return boolean
local function validatePrivateAccess(cls)
    local level = 3

    while true do
        local di = getinfo(level, "f")

        if not di or not di.func then
            return false
        end

        local current = cls

        while current do
            local classMethods = classes[current]
            local method       = classMethods and classMethods[di.func]

            if classMethods and not method then
                for _, v in pairs(current) do
                    if v == di.func then
                        method = v
                        classMethods[method] = true
                        break
                    end
                end
            end

            if method then
                return true
            end

            current = getmetatable(current)
        end

        level += 1
    end
end

---Crea una nuova istanza della classe fornita.
---@generic T : classlib
---@param cls T
---@return T
local function createInstance(cls, ...)
    local constructor = getConstructor(cls)
    local private     = {}
    local obj         = setmetatable({ private = private }, cls)

    if constructor then
        local parent = cls

        rawset(obj, "super", function(self, ...)
            parent      = getmetatable(parent)
            constructor = getConstructor(parent)

            if constructor then
                return constructor(self, ...)
            end
        end)

        constructor(obj, ...)
    end

    rawset(obj, "super", nil)

    if private ~= obj.private or next(obj.private) then
        private = table.clone(obj.private)

        table.wipe(obj.private)
        setmetatable(obj.private, {
            __metatable = "private",
            __tostring  = void,
            __index     = function(_, index)
                if not validatePrivateAccess(cls) then
                    return
                end

                return private[index]
            end,
            __newindex  = function(_, index, value)
                if not validatePrivateAccess(cls) then
                    error(("cannot set value of private field \"%s\""):format(index), 2)
                end

                private[index] = value
            end,
        })
    else
        obj.private = nil
    end

    return obj
end

---Controlla se l'oggetto è un'istanza diretta della classe fornita.
---@param cls classlib
---@return boolean
local function isClass(self, cls)
    return getmetatable(self) == cls
end

---Controlla se l'oggetto è un'istanza o derivato della classe fornita.
---@param cls classlib
---@return boolean
local function instanceOf(self, cls)
    local mt = getmetatable(self)

    while mt do
        if mt == cls then
            return true
        end

        mt = getmetatable(mt)
    end

    return false
end

--#endregion

--#region Factory

---Crea una nuova classe con ereditarietà e campi privati opzionali.
---@generic S : classlib
---@generic T : string
---@param name `T`
---@param super? S
---@return T
function _ENV.class(name, super)
    assertType(1, name, "string")

    local cls      = {}

    cls.__name     = name
    cls.__index    = cls
    cls.isClass    = isClass
    cls.instanceOf = instanceOf

    function cls.new(...)
        return createInstance(cls, ...)
    end

    if super then
        assertType("super", super, "table")
        setmetatable(cls, super)
    end

    classes[cls] = setmetatable({}, weakkeys)

    return cls
end

--#endregion
