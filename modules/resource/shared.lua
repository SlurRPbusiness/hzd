---@meta

---@class resourcelib
---@field onStart fun(handler: fun(resourceName: string): any): EventHandler
---@field onStop fun(handler: fun(resourceName: string): any): EventHandler
---@field onRefresh fun(handler: fun(): any): EventHandler
local resource = {}
_ENV.resource = resource

local isServer = hzd:is("server")
local startEvent = isServer and "onResourceStart" or "onClientResourceStart"
local stopEvent = isServer and "onResourceStop" or "onClientResourceStop"

---Registra una callback per l'avvio di questa risorsa.
---@param handler fun(resourceName: string)
---@return EventHandler handlerId
function resource.onStart(handler)
    assertType("handler", handler, "function")

    return AddEventHandler(startEvent, debug.traceEvent("resource", "onStart", function(resourceName)
        if resourceName == hzd.name then
            handler(resourceName)
        end
    end))
end

onResourceStart = resource.onStart

---Registra una callback prima dell'arresto di questa risorsa.
---@param handler fun(resourceName: string)
---@return EventHandler handlerId
function resource.onStop(handler)
    assertType("handler", handler, "function")

    return AddEventHandler(stopEvent, debug.traceEvent("resource", "onStop", function(resourceName)
        if resourceName == hzd.name then
            handler(resourceName)
        end
    end))
end

onResourceStop = resource.onStop

---Registra una callback dopo il comando server `refresh`.
---@param handler fun()
---@return EventHandler handlerId
function resource.onRefresh(handler)
    assert(hzd:is("server"), "resource.onRefresh is only available server-side")
    assertType("handler", handler, "function")

    return AddEventHandler("onResourceListRefresh", debug.traceEvent("server", "onResourceListRefresh", handler))
end

onResourceListRefresh = resource.onRefresh
