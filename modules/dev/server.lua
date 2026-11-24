---@meta

createEvent("dev:syncRequest", function(playerSource)
    sendEvent("client", playerSource, "dev:syncState", hzd:isDevMode())
end)
