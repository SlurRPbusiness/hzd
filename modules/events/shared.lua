---@meta

---@class eventslib
---@field route fun(name: string, scope?: "local"|"server"|"client"): string
---@field id fun(name: string): string
---@field createEvent fun(name: string, handler: function, scope?: "shared"|"server"|"client"): EventHandler
---@field sendEvent fun(scope: "shared"|"server"|"client", ...: any)
---@field on fun(name: string, handler: fun(...: any)): EventHandler
---@field off fun(handlerId: EventHandler)
---@field onClient fun(name: string, handler: fun(...: any)): EventHandler
---@field onServer fun(name: string, handler: fun(source: integer, ...: any)): EventHandler
local events = {}
local EVENT_PROTOCOL <const> = "hzd12"

---@class triggerlib
---@field server fun(name: string, ...: any)
---@field client fun(target: integer|string|number, name: string, ...: any)
local trigger = setmetatable({}, {
    __call = function(_, name, ...)
        assertType("name", name, "string")
        TriggerEvent(events.route(name, "local"), ...)
    end,
}) --[[@as triggerlib]]

_ENV.events = events
_ENV.trigger = trigger

local routeCache = cache()

---Restituisce l'identificatore SHA-256 codificato in Base64 URL-safe per un nome logico.
---È deterministica e non autentica chi invia l'evento.
---@param name string
---@return string
function events.id(name)
    assertType("name", name, "string")
    assert(name ~= "", "event name cannot be empty")

    return routeCache:getOrSet(("id:%s"):format(name), function()
        local input = ("%s:%s:%s"):format(hzd.name, hzd.version, name)
        return sha256.base64(input)
    end)
end

---Compone un route HZD12 compatto, distinto per risorsa, versione e direzione.
---HZD12 è un formato di routing: non cifra né autentica i payload.
---@param name string
---@param scope? "local"|"server"|"client"
---@return string
function events.route(name, scope)
    assertType("name", name, "string")
    assert(name ~= "", "event name cannot be empty")
    scope = scope or "local"
    assert(scope == "local" or scope == "server" or scope == "client", "invalid event scope")

    return routeCache:getOrSet(("route:%s:%s"):format(scope, name), function()
        local input = ("%s:%s:%s:%s"):format(hzd.name, hzd.version, scope, name)
        local digest = sha256.base64(input)
        return ("%s:%s"):format(EVENT_PROTOCOL, digest)
    end)
end

---Registra un evento locale usando il route deterministico della risorsa.
---@param name string
---@param handler function
---@return EventHandler handlerId
function events.on(name, handler)
    assertType("name", name, "string")
    assert(name ~= "", "event name cannot be empty")
    assertType("handler", handler, "function")
    return AddEventHandler(events.route(name, "local"), debug.traceEvent(hzd.environment, name, handler))
end

---Registra un evento locale (`shared`) o di rete. Senza scope deduce il runtime corrente.
---@param name string
---@param handler function
---@param scope? "shared"|"server"|"client"
---@return EventHandler handlerId
function events.createEvent(name, handler, scope)
    assertType("name", name, "string")
    assert(name ~= "", "event name cannot be empty")
    assertType("handler", handler, "function")

    if scope == nil then
        if hzd:is("server") then
            scope = "server"
        elseif hzd:is("client") then
            scope = "client"
        else
            error("cannot infer event scope outside client/server runtime", 2)
        end
    end

    assert(scope == "shared" or scope == "server" or scope == "client", "invalid event scope")

    if scope == "shared" then
        return events.on(name, handler)
    end

    local networkScope = scope
    ---@cast networkScope "client"|"server"
    assert(hzd:is(networkScope), ("cannot register a %s event from the %s runtime"):format(networkScope, hzd.environment))

    local route = events.route(name, networkScope)
    RegisterNetEvent(route)

    local dispatch = handler
    if networkScope == "server" then
        dispatch = function(...)
            local eventSource = tonumber(source)
            assert(eventSource and eventSource % 1 == 0 and eventSource > 0, "invalid server event source")
            return handler(eventSource, ...)
        end
    end

    return AddEventHandler(route, debug.traceEvent(networkScope, name, dispatch))
end

_ENV.createEvent = events.createEvent

---Invia un evento locale (`shared`), client → server (`server`) o server → client (`client`).
---Per scope "client", gli argomenti dopo lo scope sono target, nome evento e payload.
---@param scope "shared"|"server"|"client"
---@param ... any
function events.sendEvent(scope, ...)
    assertType("scope", scope, "string")

    if scope == "shared" then
        return trigger(...)
    elseif scope == "server" then
        assert(hzd:is("client"), "server events can only be sent from the client runtime")
        return trigger.server(...)
    elseif scope == "client" then
        assert(hzd:is("server"), "client events can only be sent from the server runtime")
        assert(select("#", ...) >= 2, "client events require a target and event name")

        local target = select(1, ...)
        local name = select(2, ...)
        assertType("target", target, "integer")
        assertType("name", name, "string")
        return trigger.client(target, name, select(3, ...))
    end

    error("scope must be 'shared', 'server' or 'client'", 2)
end

_ENV.sendEvent = events.sendEvent

---Rimuove un handler registrato con events.on, events.onClient o events.onServer.
---@param handlerId EventHandler
function events.off(handlerId)
    RemoveEventHandler(handlerId)
end
