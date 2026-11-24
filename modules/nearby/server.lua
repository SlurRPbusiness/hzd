---@meta

--#region Native Upvalue Optimization

local GetPlayerPed <const>            = GetPlayerPed
local DoesEntityExist <const>         = DoesEntityExist
local GetEntityCoords <const>         = GetEntityCoords
local GetPlayerRoutingBucket <const>  = GetPlayerRoutingBucket
local GetAllPeds <const>              = GetAllPeds
local GetAllVehicles <const>          = GetAllVehicles
local GetAllObjects <const>           = GetAllObjects
local GetPlayers <const>              = GetPlayers

--#endregion

---@class nearbylib
---@field players fun(centerOrRadius: vector3|vector4|table|number, radiusOrOptions?: number|nearbyOptions, options?: nearbyOptions): nearbyPlayer[]
---@field entities fun(centerOrRadius: vector3|vector4|table|number, radiusOrOptions?: number|nearbyOptions, options?: nearbyOptions): nearbyEntity[]
---@field peds fun(centerOrRadius: vector3|vector4|table|number, radiusOrOptions?: number|nearbyOptions, options?: nearbyOptions): nearbyEntity[]
---@field vehicles fun(centerOrRadius: vector3|vector4|table|number, radiusOrOptions?: number|nearbyOptions, options?: nearbyOptions): nearbyEntity[]
---@field objects fun(centerOrRadius: vector3|vector4|table|number, radiusOrOptions?: number|nearbyOptions, options?: nearbyOptions): nearbyEntity[]

local function getCallerServerId()
    local playerId = tonumber(source)

    if playerId and playerId > 0 then
        return playerId
    end

    return nil
end

local function resolveSearch(centerOrRadius, radiusOrOptions, options)
    local center
    local radius
    local rawOptions
    local callerServerId = getCallerServerId()
    local callerPed = callerServerId and GetPlayerPed(callerServerId) or nil

    if callerPed == 0 then
        callerPed = nil
    end

    local excludedPed = callerPed
    local excludedPlayerId = callerServerId
    local centerPlayerId = callerServerId

    if type(centerOrRadius) == "number" then
        radius = centerOrRadius
        rawOptions = radiusOrOptions

        local normalizedOptions = nearby._normalizeOptions(rawOptions)
        local centerPlayer = normalizedOptions.centerPlayer or callerServerId

        if not centerPlayer then
            error("a server search needs explicit coordinates or a player source", 3)
        end

        local centerPed = GetPlayerPed(centerPlayer)

        if centerPed == 0 or not DoesEntityExist(centerPed) then
            return nil, nil, nil, radius, normalizedOptions, callerPed, callerServerId
        end

        center = GetEntityCoords(centerPed)
        excludedPed = centerPed
        excludedPlayerId = centerPlayer
        centerPlayerId = centerPlayer
    else
        center = centerOrRadius
        radius = radiusOrOptions
        rawOptions = options
    end

    local x, y, z, normalizedRadius, normalizedOptions =
        nearby._normalize(center, radius, rawOptions)
    local routingBucket = normalizedOptions.routingBucket

    if routingBucket == nil and centerPlayerId then
        routingBucket = GetPlayerRoutingBucket(centerPlayerId)
    end

    return x, y, z, normalizedRadius, normalizedOptions, excludedPed, excludedPlayerId, routingBucket
end

local function getEntityPool(kind, routingBucket)
    local handles

    if kind == "ped" then
        handles = GetAllPeds()
    elseif kind == "vehicle" then
        handles = GetAllVehicles()
    elseif kind == "object" then
        handles = GetAllObjects()
    else
        handles = {}

        for _, handle in ipairs(GetAllPeds()) do
            handles[#handles + 1] = handle
        end

        for _, handle in ipairs(GetAllVehicles()) do
            handles[#handles + 1] = handle
        end

        for _, handle in ipairs(GetAllObjects()) do
            handles[#handles + 1] = handle
        end
    end

    if routingBucket == nil then
        return handles
    end

    local filtered = {}

    for _, handle in ipairs(handles) do
        if GetEntityRoutingBucket(handle) == routingBucket then
            filtered[#filtered + 1] = handle
        end
    end

    return filtered
end

local function collectEntities(kind, centerOrRadius, radiusOrOptions, options)
    local x, y, z, radius, normalizedOptions, callerPed, _, routingBucket =
        resolveSearch(centerOrRadius, radiusOrOptions, options)

    if x == nil then
        return {}
    end

    if normalizedOptions.maxResults == 0 then
        return {}
    end

    local excludedPed

    if not normalizedOptions.includeSelf then
        excludedPed = callerPed
    end

    return nearby._collect(
        getEntityPool(kind, routingBucket),
        kind == "all" and "all" or kind,
        x,
        y,
        z,
        radius,
        normalizedOptions,
        excludedPed
    )
end

---Trova i player vicini. Con un solo numero usa il source evento come centro.
---@param centerOrRadius vector3|vector4|table|number
---@param radiusOrOptions? number|nearbyOptions
---@param options? nearbyOptions
---@return nearbyPlayer[]
function nearby.players(centerOrRadius, radiusOrOptions, options)
    local x, y, z, radius, normalizedOptions, _, excludedPlayerId, routingBucket = resolveSearch(centerOrRadius,
        radiusOrOptions, options)

    if x == nil or y == nil or z == nil or normalizedOptions.maxResults == 0 then
        return {}
    end

    local results = {}
    local maximum = normalizedOptions.maxResults

    for _, player in ipairs(GetPlayers()) do
        local serverId = tonumber(player)

        if serverId
            and serverId ~= normalizedOptions.excludePlayer
            and (normalizedOptions.includeSelf or serverId ~= excludedPlayerId)
            and (routingBucket == nil or GetPlayerRoutingBucket(serverId) == routingBucket)
        then
            local handle = GetPlayerPed(serverId)
            local coords, distance = nearby._measure(handle, x, y, z, radius)

            if coords and distance then
                results[#results + 1] = {
                    id = serverId,
                    ped = handle,
                    coords = coords,
                    distance = distance,
                }

                if maximum and not normalizedOptions.sortByDistance and #results >= maximum then
                    break
                end
            end
        end
    end

    return nearby._finalize(results, normalizedOptions)
end

---Trova peds vicini, inclusi i peds dei player.
---@param centerOrRadius vector3|vector4|table|number
---@param radiusOrOptions? number|nearbyOptions
---@param options? nearbyOptions
---@return nearbyEntity[]
function nearby.peds(centerOrRadius, radiusOrOptions, options)
    return collectEntities("ped", centerOrRadius, radiusOrOptions, options)
end

---Trova veicoli vicini.
---@param centerOrRadius vector3|vector4|table|number
---@param radiusOrOptions? number|nearbyOptions
---@param options? nearbyOptions
---@return nearbyEntity[]
function nearby.vehicles(centerOrRadius, radiusOrOptions, options)
    return collectEntities("vehicle", centerOrRadius, radiusOrOptions, options)
end

---Trova oggetti vicini.
---@param centerOrRadius vector3|vector4|table|number
---@param radiusOrOptions? number|nearbyOptions
---@param options? nearbyOptions
---@return nearbyEntity[]
function nearby.objects(centerOrRadius, radiusOrOptions, options)
    return collectEntities("object", centerOrRadius, radiusOrOptions, options)
end

---Trova peds, veicoli e oggetti vicini.
---@param centerOrRadius vector3|vector4|table|number
---@param radiusOrOptions? number|nearbyOptions
---@param options? nearbyOptions
---@return nearbyEntity[]
function nearby.entities(centerOrRadius, radiusOrOptions, options)
    return collectEntities("all", centerOrRadius, radiusOrOptions, options)
end
