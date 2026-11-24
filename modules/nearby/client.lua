---@meta

--#region Native Upvalue Optimization

local PlayerPedId <const>           = PlayerPedId
local PlayerId <const>              = PlayerId
local GetPlayerServerId <const>     = GetPlayerServerId
local GetPlayerFromServerId <const> = GetPlayerFromServerId
local GetPlayerPed <const>          = GetPlayerPed
local DoesEntityExist <const>       = DoesEntityExist
local GetEntityCoords <const>       = GetEntityCoords
local GetGamePool <const>           = GetGamePool
local GetActivePlayers <const>      = GetActivePlayers

--#endregion

---@class nearbylib
---@field players fun(centerOrRadius: vector3|vector4|table|number, radiusOrOptions?: number|nearbyOptions, options?: nearbyOptions): nearbyPlayer[]
---@field entities fun(centerOrRadius: vector3|vector4|table|number, radiusOrOptions?: number|nearbyOptions, options?: nearbyOptions): nearbyEntity[]
---@field peds fun(centerOrRadius: vector3|vector4|table|number, radiusOrOptions?: number|nearbyOptions, options?: nearbyOptions): nearbyEntity[]
---@field vehicles fun(centerOrRadius: vector3|vector4|table|number, radiusOrOptions?: number|nearbyOptions, options?: nearbyOptions): nearbyEntity[]
---@field objects fun(centerOrRadius: vector3|vector4|table|number, radiusOrOptions?: number|nearbyOptions, options?: nearbyOptions): nearbyEntity[]

local function resolveSearch(centerOrRadius, radiusOrOptions, options)
    local center
    local radius
    local rawOptions
    local callerPed = PlayerPedId()
    local callerServerId = GetPlayerServerId(PlayerId())

    if callerPed == 0 then
        callerPed = nil
    end

    if callerServerId <= 0 then
        callerServerId = nil
    end

    local excludedPed = callerPed
    local excludedPlayerId = callerServerId

    if type(centerOrRadius) == "number" then
        radius = centerOrRadius
        rawOptions = radiusOrOptions

        local normalizedOptions = nearby._normalizeOptions(rawOptions)
        assert(normalizedOptions.routingBucket == nil, "routingBucket filtering is only available on the server")
        local playerIndex = PlayerId()

        if normalizedOptions.centerPlayer ~= nil then
            playerIndex = GetPlayerFromServerId(normalizedOptions.centerPlayer)
            excludedPlayerId = normalizedOptions.centerPlayer
        end

        if playerIndex == -1 then
            return nil, nil, nil, radius, normalizedOptions, callerPed, callerServerId
        end

        local centerPed = GetPlayerPed(playerIndex)

        if centerPed == 0 or not DoesEntityExist(centerPed) then
            return nil, nil, nil, radius, normalizedOptions, callerPed, callerServerId
        end

        center = GetEntityCoords(centerPed)
        excludedPed = centerPed
        if normalizedOptions.centerPlayer == nil then
            excludedPlayerId = callerServerId
        end
    else
        center = centerOrRadius
        radius = radiusOrOptions
        rawOptions = options
    end

    local x, y, z, normalizedRadius, normalizedOptions =
        nearby._normalize(center, radius, rawOptions)
    assert(normalizedOptions.routingBucket == nil, "routingBucket filtering is only available on the server")

    return x, y, z, normalizedRadius, normalizedOptions, excludedPed, excludedPlayerId
end

local function collectEntities(kind, centerOrRadius, radiusOrOptions, options)
    local x, y, z, radius, normalizedOptions, callerPed =
        resolveSearch(centerOrRadius, radiusOrOptions, options)

    if x == nil then
        return {}
    end

    if normalizedOptions.maxResults == 0 then
        return {}
    end

    local handles

    if kind == "ped" then
        handles = GetGamePool("CPed")
    elseif kind == "vehicle" then
        handles = GetGamePool("CVehicle")
    elseif kind == "object" then
        handles = GetGamePool("CObject")
    else
        handles = {}

        for _, handle in ipairs(GetGamePool("CPed")) do
            handles[#handles + 1] = handle
        end

        for _, handle in ipairs(GetGamePool("CVehicle")) do
            handles[#handles + 1] = handle
        end

        for _, handle in ipairs(GetGamePool("CObject")) do
            handles[#handles + 1] = handle
        end
    end

    local excludedPed

    if not normalizedOptions.includeSelf then
        excludedPed = callerPed
    end

    return nearby._collect(handles, kind == "all" and "all" or kind, x, y, z, radius, normalizedOptions, excludedPed)
end

---Trova i player vicini. Con un solo numero usa il player locale come centro.
---@param centerOrRadius vector3|vector4|table|number
---@param radiusOrOptions? number|nearbyOptions
---@param options? nearbyOptions
---@return nearbyPlayer[]
function nearby.players(centerOrRadius, radiusOrOptions, options)
    local x, y, z, radius, normalizedOptions, _, excludedPlayerId =
        resolveSearch(centerOrRadius, radiusOrOptions, options)

    if x == nil or y == nil or z == nil or normalizedOptions.maxResults == 0 then
        return {}
    end

    local results = {}
    local maximum = normalizedOptions.maxResults

    for _, player in ipairs(GetActivePlayers()) do
        local serverId = GetPlayerServerId(player)

        if serverId > 0
            and serverId ~= normalizedOptions.excludePlayer
            and (normalizedOptions.includeSelf or serverId ~= excludedPlayerId)
        then
            local handle = GetPlayerPed(player)
            local coords, distance = nearby._measure(handle, x, y, z, radius)

            if coords and distance then
                results[#results + 1] = {
                    id = serverId,
                    ped = handle,
                    playerIndex = player,
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
