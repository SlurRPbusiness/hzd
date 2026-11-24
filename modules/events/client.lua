---@meta

local oldTriggerServerEvent <const> = TriggerServerEvent

---Registra un handler raggiungibile anche dal server.
---@param name string
---@param handler function
---@return EventHandler handlerId
function events.onClient(name, handler)
    return events.createEvent(name, handler, "client")
end

---@deprecated Use createEvent(name, handler)
onClientEvent = events.onClient

---Invia un evento dal client al server usando il route generato dalla risorsa.
---@param name string
---@param ... any
function trigger.server(name, ...)
    oldTriggerServerEvent(events.route(name, "server"), ...)
end
