---@meta

createEvent("dev:syncState", function(enabled)
    assertType("enabled", enabled, "boolean")
    hzd:setDevMode(enabled)
    nui.send("setDevMode", { enabled = enabled })
end)

AddEventHandler("onClientResourceStart", function(resourceName)
    if resourceName == GetCurrentResourceName() then
        sendEvent("server", "dev:syncRequest")
    end
end)
