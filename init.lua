---@meta

---@class hzd : classlib
---@field name        string
---@field version     string
---@field environment "client" | "server"
---@field devMode     boolean
---@field core        table
---@field new         fun(): hzd
local hzd = class("hzd") --[[@as hzd]]

--#region Constructor

function hzd:constructor()
    self.name        = GetCurrentResourceName()
    self.version     = GetResourceMetadata(self.name, "version", 0)
    assert(type(self.version) == "string" and self.version ~= "", "resource version is missing from fxmanifest.lua")
    self.environment = IsDuplicityVersion() and "server" or "client"
    self.devMode     = self.environment == "server"
        and GetConvarBool(("%s:devMode"):format(self.name), false)
        or false
    self.core        = {}
end

--#endregion

--#region Methods

---Verifica se il framework è in esecuzione nell'ambiente specificato ("client" o "server").
---@param env "client" | "server"
---@return boolean
function hzd:is(env)
    return self.environment == env
end

---Imposta lo stato della modalità sviluppatore a runtime.
---@param state boolean
function hzd:setDevMode(state)
    assertType("state", state, "boolean")
    self.devMode = state
end

---Restituisce true se la modalità sviluppatore è attualmente attiva.
---@return boolean
function hzd:isDevMode()
    return self.devMode == true
end

--#endregion

_ENV.hzd = hzd.new()
