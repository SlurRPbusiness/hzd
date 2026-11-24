---@meta

local handlers = {}
local pending = {}
local requestSequence = 0

local function nextRequestId()
    repeat
        requestSequence = requestSequence + 1

        if requestSequence > 2147483647 then
            requestSequence = 1
        end
    until pending[requestSequence] == nil

    return requestSequence
end

local function callbackKey(name, direction)
    assertType("name", name, "string")
    assert(name ~= "", "callback name cannot be empty")
    return events.id(("callback:%s:%s"):format(direction, name))
end

local function normalizeTarget(target)
    assertType("target", target, "integer|string")

    if type(target) == "string" then
        target = tonumber(target)
        assert(target and target % 1 == 0, "target must be an integer server ID")
    end

    assert(target > 0, "callback target must be a positive server ID")
    return target
end

createEvent("callback:server:request", function(eventSource, requestId, key, ...)
    if eventSource <= 0 or type(requestId) ~= "number" or requestId % 1 ~= 0 or requestId <= 0 or type(key) ~= "string" then
        return
    end

    local handler = handlers[key]

    if not handler then
        sendEvent("client", eventSource, "callback:server:response", requestId, false, "server callback is not registered")
        return
    end

    local success, value = pcall(handler, eventSource, ...)

    if success then
        sendEvent("client", eventSource, "callback:server:response", requestId, true, { value = value })
    else
        print.error("[CALLBACK] Server handler failed for source %d: %s", eventSource, tostring(value))
        sendEvent("client", eventSource, "callback:server:response", requestId, false, tostring(value))
    end
end)

createEvent("callback:client:response", function(eventSource, requestId, success, payload)
    if type(requestId) ~= "number" or requestId % 1 ~= 0 or requestId <= 0 or type(success) ~= "boolean" then
        return
    end

    local entry = pending[requestId]

    if not entry or entry.target ~= eventSource then
        return
    end

    pending[requestId] = nil

    if success and type(payload) == "table" then
        entry.deferred:resolve(payload.value)
    elseif success then
        entry.deferred:reject("invalid client callback response")
    else
        entry.deferred:reject(tostring(payload or "client callback failed"))
    end
end)

---Registra una callback eseguibile dai client sul server.
---@param name string
---@param handler fun(source: integer, ...: any): any
---@return string callbackId
function callback.registerServer(name, handler)
    assertType("handler", handler, "function")

    local key = callbackKey(name, "server")
    assert(handlers[key] == nil, ("server callback '%s' is already registered"):format(name))
    handlers[key] = debug.traceCallback("server", name, handler)

    return key
end

---Richiede una callback a un client e restituisce una Promise da attendere con await(...).
---@param target integer|string
---@param name string
---@param ... any
---@return Promise<any>
function callback.client(target, name, ...)
    target = normalizeTarget(target)

    local key = callbackKey(name, "client")
    local requestId = nextRequestId()
    local deferred = promise.new()
    local timeout = callback.timeout
    pending[requestId] = {
        deferred = deferred,
        target = target,
    }

    debug.print("callback request server -> client %s (target %s)", name, target)

    SetTimeout(timeout, function()
        local entry = pending[requestId]

        if entry and entry.deferred == deferred then
            pending[requestId] = nil
            deferred:reject(("client callback '%s' timed out after %sms"):format(name, timeout))
        end
    end)

    sendEvent("client", target, "callback:client:request", requestId, key, ...)
    return deferred
end
