---@meta

---@class commandHandle
---@field name string
---@field restricted boolean
---@field enabled boolean
---@field handler fun(source: integer, args: string[], rawCommand: string)
---@field enable fun(self: commandHandle): commandHandle
---@field disable fun(self: commandHandle): commandHandle
---@field isEnabled fun(self: commandHandle): boolean

---@class commandlib
---@field create fun(self: commandlib, name: string, handler: fun(source: integer, args: string[], rawCommand: string), restricted?: boolean): commandHandle
---@field get fun(self: commandlib, name: string): commandHandle?
local command = {}
local commandHandle = {}
commandHandle.__index = commandHandle

local registered = {}
_ENV.command = command

--#region Command Handle

---@return commandHandle
function commandHandle:enable()
    self.enabled = true
    return self
end

---@return commandHandle
function commandHandle:disable()
    self.enabled = false
    return self
end

---@return boolean
function commandHandle:isEnabled()
    return self.enabled
end

--#endregion

--#region Registry

---Crea e registra un comando con un handler obbligatorio.
---@param name string
---@param handler fun(source: integer, args: string[], rawCommand: string)
---@param restricted? boolean
---@return commandHandle
function command:create(name, handler, restricted)
    assertType("name", name, "string")
    assert(name:match("^[%w_%-]+$"), "command name must contain only letters, numbers, '_' or '-'")
    assert(registered[name] == nil, ("command '%s' is already registered through command:create"):format(name))
    assertType("handler", handler, "function")

    if restricted == nil then
        restricted = false
    end

    assertType("restricted", restricted, "boolean")

    local entry = setmetatable({
        name = name,
        restricted = restricted,
        enabled = true,
        handler = handler,
    }, commandHandle)

    local function dispatch(source, args, rawCommand)
        if not entry.enabled then
            return
        end

        return entry.handler(source, args, rawCommand)
    end

    RegisterCommand(name, debug.traceCommand(name, dispatch), restricted)
    registered[name] = entry

    return entry
end

---Restituisce un comando creato da questo modulo.
---@param name string
---@return commandHandle?
function command:get(name)
    assertType("name", name, "string")
    return registered[name]
end

--#endregion
