---@meta

local oldTriggerClientEvent <const> = TriggerClientEvent

---Registra un evento di rete e passa sempre il source come primo argomento.
---@param name string
---@param handler fun(source: integer, ...: any)
---@return EventHandler handlerId
function events.onServer(name, handler)
    return events.createEvent(name, handler, "server")
end

---@deprecated Use createEvent(name, handler)
onServerEvent = events.onServer

---Invia un evento dal server a un client o a tutti i client con target -1.
---@param target integer
---@param name string
---@param ... any
function trigger.client(target, name, ...)
    assertType("target", target, "integer")
    assertType("name", name, "string")

    assert(target == -1 or target > 0, "target must be -1 or a positive server ID")
    oldTriggerClientEvent(events.route(name, "client"), target, ...)
end
