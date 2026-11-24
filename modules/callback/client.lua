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

createEvent("callback:server:response", function(requestId, success, payload)
    if type(requestId) ~= "number" or requestId % 1 ~= 0 or requestId <= 0 or type(success) ~= "boolean" then
        return
    end

    local deferred = pending[requestId]

    if not deferred then
        return
    end

    pending[requestId] = nil

    if success and type(payload) == "table" then
        deferred:resolve(payload.value)
    elseif success then
        deferred:reject("invalid server callback response")
    else
        deferred:reject(tostring(payload or "server callback failed"))
    end
end)

createEvent("callback:client:request", function(requestId, key, ...)
    if type(requestId) ~= "number" or requestId % 1 ~= 0 or requestId <= 0 or type(key) ~= "string" then
        return
    end

    local handler = handlers[key]

    if not handler then
        sendEvent("server", "callback:client:response", requestId, false, "client callback is not registered")
        return
    end

    local success, value = pcall(handler, ...)

    if success then
        sendEvent("server", "callback:client:response", requestId, true, { value = value })
    else
        print.error("[CALLBACK] Client handler failed: %s", tostring(value))
        sendEvent("server", "callback:client:response", requestId, false, tostring(value))
    end
end)

---Registra una callback eseguibile dal server su questo client.
---@param name string
---@param handler fun(...: any): any
---@return string callbackId
function callback.registerClient(name, handler)
    assertType("handler", handler, "function")

    local key = callbackKey(name, "client")
    assert(handlers[key] == nil, ("client callback '%s' is already registered"):format(name))
    handlers[key] = debug.traceCallback("client", name, handler)

    return key
end

---Richiede al server una callback e restituisce una Promise da attendere con await(...).
---@param name string
---@param ... any
---@return Promise<any>
function callback.server(name, ...)
    local key = callbackKey(name, "server")
    local requestId = nextRequestId()
    local deferred = promise.new()
    local timeout = callback.timeout
    pending[requestId] = deferred

    debug.print("callback request client -> server %s", name)

    SetTimeout(timeout, function()
        if pending[requestId] == deferred then
            pending[requestId] = nil
            deferred:reject(("server callback '%s' timed out after %sms"):format(name, timeout))
        end
    end)

    sendEvent("server", "callback:server:request", requestId, key, ...)
    return deferred
end
