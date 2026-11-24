---@meta

---@class debuglib : table
---@field isEnabled fun(): boolean
---@field enable fun()
---@field disable fun()
---@field toggle fun(): boolean
---@field print fun(message: string, ...: any)
---@field warn fun(message: string, ...: any)
---@field dump fun(value: any, maxDepth?: integer)
---@field command fun(name: string, handler: fun(source: integer, args: string[], rawCommand: string), restricted?: boolean): commandHandle
---@field event fun(name: string, handler: fun(...: any)): EventHandler
---@field eventClient fun(name: string, handler: fun(...: any)): EventHandler
---@field eventServer fun(name: string, handler: fun(source: integer, ...: any)): EventHandler
---@field callback fun(name: string, handler: fun(...: any): any): string
---@field traceEvent fun(scope: string, name: string, handler: function): function
---@field traceCallback fun(scope: string, name: string, handler: function): function
---@field traceCommand fun(name: string, handler: function): function
local debug = _ENV.debug or {}
_ENV.debug = debug

--#region State Control

---Controlla se la modalità sviluppatore è attiva.
---@return boolean
function debug.isEnabled()
    return hzd and hzd.devMode == true
end

---Abilita la modalità sviluppatore sul server e sincronizza i client.
function debug.enable()
    if hzd:is("server") then
        hzd:setDevMode(true)
        sendEvent("client", -1, "dev:syncState", true)
    else
        sendEvent("server", "dev:syncRequest")
    end
    debug.print("modalità sviluppatore ABILITATA via codice")
end

---Disabilita la modalità sviluppatore sul server e sincronizza i client.
function debug.disable()
    if hzd:is("server") then
        hzd:setDevMode(false)
        sendEvent("client", -1, "dev:syncState", false)
    else
        sendEvent("server", "dev:syncRequest")
    end
end

---Inverte lo stato della modalità sviluppatore e restituisce il nuovo stato.
---@return boolean
function debug.toggle()
    if hzd:is("client") then
        sendEvent("server", "dev:syncRequest")
        return debug.isEnabled()
    end

    local newState = not debug.isEnabled()
    if newState then
        debug.enable()
    else
        debug.disable()
    end
    return newState
end

--#endregion

--#region Logging

---Scrive un messaggio formattato solo quando la modalità sviluppo è attiva.
---@param message string
---@param ... any
function debug.print(message, ...)
    if not debug.isEnabled() then
        return
    end

    assertType("message", message, "string")

    local text = message

    if select("#", ...) > 0 then
        local success, formatted = pcall(string.format, message, ...)
        text = success and formatted or message
    end

    print(("^6[DEBUG]^7 %s"):format(text))
end

---Scrive un avviso formattato solo quando la modalità sviluppo è attiva.
---@param message string
---@param ... any
function debug.warn(message, ...)
    if not debug.isEnabled() then
        return
    end

    assertType("message", message, "string")

    local text = message

    if select("#", ...) > 0 then
        local success, formatted = pcall(string.format, message, ...)
        text = success and formatted or message
    end

    print(("^3[DEBUG:WARN]^7 %s"):format(text))
end

---Esegue il dump a schermo di un valore o tabella solo se la modalità sviluppo è attiva.
---@param value any
---@param maxDepth? integer
function debug.dump(value, maxDepth)
    if not debug.isEnabled() then
        return
    end

    if print.dump then
        print.dump(value, maxDepth)
    else
        print(tostring(value))
    end
end

--#endregion

--#region Tracing Helpers (Internal per framework)

---Aggiunge log di sviluppo a un handler evento senza alterarne gli argomenti o i return.
---@param scope string
---@param name string
---@param handler function
---@return function
function debug.traceEvent(scope, name, handler)
    assertType("scope", scope, "string")
    assertType("name", name, "string")
    assertType("handler", handler, "function")

    if not debug.isEnabled() then
        return handler
    end

    debug.print("register event [%s] %s", scope, name)

    return function(...)
        debug.print("event [%s] %s", scope, name)
        return handler(...)
    end
end

---Aggiunge log di registrazione ed esecuzione a una callback standard.
---@param scope string
---@param name string
---@param handler function
---@return function
function debug.traceCallback(scope, name, handler)
    assertType("scope", scope, "string")
    assertType("name", name, "string")
    assertType("handler", handler, "function")

    if not debug.isEnabled() then
        return handler
    end

    debug.print("register callback [%s] %s", scope, name)

    return function(...)
        debug.print("callback [%s] %s", scope, name)
        return handler(...)
    end
end

---Aggiunge log di esecuzione a un comando standard.
---@param name string
---@param handler function
---@return function
function debug.traceCommand(name, handler)
    assertType("name", name, "string")
    assertType("handler", handler, "function")

    if not debug.isEnabled() then
        return handler
    end

    debug.print("register command /%s", name)

    return function(source, args, rawCommand)
        debug.print("command /%s executed by source %s", name, tostring(source))
        return handler(source, args, rawCommand)
    end
end

--#endregion

--#region Debug Registrations (Dedicate alla creazione di comandi ed eventi di debug)

---Registra un comando di debug che viene eseguito SOLO se la modalità sviluppo è attiva.
---@param name string
---@param handler fun(source: integer, args: string[], rawCommand: string)
---@param restricted? boolean
---@return commandHandle
function debug.command(name, handler, restricted)
    assertType("name", name, "string")
    assertType("handler", handler, "function")

    return command:create(name, function(source, args, rawCommand)
        if not debug.isEnabled() then
            return
        end

        return handler(source, args, rawCommand)
    end, restricted)
end

---Registra un evento locale di debug che viene eseguito SOLO se la modalità sviluppo è attiva.
---@param name string
---@param handler fun(...: any)
---@return EventHandler
function debug.event(name, handler)
    assertType("name", name, "string")
    assertType("handler", handler, "function")

    return events.createEvent(name, function(...)
        if not debug.isEnabled() then
            return
        end

        return handler(...)
    end, "shared")
end

---Registra un evento client di debug che risponde al server SOLO se la modalità sviluppo è attiva.
---@param name string
---@param handler fun(...: any)
---@return EventHandler
function debug.eventClient(name, handler)
    assertType("name", name, "string")
    assertType("handler", handler, "function")

    return events.createEvent(name, function(...)
        if not debug.isEnabled() then
            return
        end

        return handler(...)
    end, "client")
end

---Registra un evento server di debug che risponde dal client SOLO se la modalità sviluppo è attiva.
---@param name string
---@param handler fun(source: integer, ...: any)
---@return EventHandler
function debug.eventServer(name, handler)
    assertType("name", name, "string")
    assertType("handler", handler, "function")

    return events.createEvent(name, function(source, ...)
        if not debug.isEnabled() then
            return
        end

        return handler(source, ...)
    end, "server")
end

---Registra una callback di debug che risponde SOLO se la modalità sviluppo è attiva.
---@param name string
---@param handler fun(...: any): any
---@return string
function debug.callback(name, handler)
    assertType("name", name, "string")
    assertType("handler", handler, "function")

    local registerFn = hzd:is("server") and callback.registerServer or callback.registerClient

    return registerFn(name, function(...)
        if not debug.isEnabled() then
            return nil
        end

        return handler(...)
    end)
end

--#endregion
