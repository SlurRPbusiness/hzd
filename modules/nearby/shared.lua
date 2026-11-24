---@meta

--#region Native Upvalue Optimization

local DoesEntityExist <const> = DoesEntityExist
local GetEntityType <const>   = GetEntityType
local GetEntityCoords <const> = GetEntityCoords

--#endregion

---@alias nearbyEntityKind "ped"|"vehicle"|"object"
---@alias nearbySearchKind nearbyEntityKind|"all"

---@class nearbyOptions
---@field centerPlayer? integer       Server ID used as the center when only a radius is passed.
---@field excludePlayer? integer      Server ID to omit from a player search.
---@field excludeEntity? integer      Entity handle to omit from an entity search.
---@field includeSelf? boolean        Include the caller or selected center player in results.
---@field sortByDistance? boolean     Sort results from nearest to farthest.
---@field maxResults? integer         Maximum number of results to return.
---@field routingBucket? integer      Server-side bucket filter; defaults to the caller or center player's bucket.

---@class nearbyResult
---@field coords vector3
---@field distance number

---@class nearbyEntity : nearbyResult
---@field handle integer
---@field kind nearbyEntityKind

---@class nearbyPlayer : nearbyResult
---@field id integer
---@field ped integer
---@field playerIndex? integer

---@class nearbylib
---@field players fun(centerOrRadius: vector3|vector4|table|number, radiusOrOptions?: number|nearbyOptions, options?: nearbyOptions): nearbyPlayer[]
---@field entities fun(centerOrRadius: vector3|vector4|table|number, radiusOrOptions?: number|nearbyOptions, options?: nearbyOptions): nearbyEntity[]
---@field peds fun(centerOrRadius: vector3|vector4|table|number, radiusOrOptions?: number|nearbyOptions, options?: nearbyOptions): nearbyEntity[]
---@field vehicles fun(centerOrRadius: vector3|vector4|table|number, radiusOrOptions?: number|nearbyOptions, options?: nearbyOptions): nearbyEntity[]
---@field objects fun(centerOrRadius: vector3|vector4|table|number, radiusOrOptions?: number|nearbyOptions, options?: nearbyOptions): nearbyEntity[]
---@field _normalize fun(center: vector3|vector4|table, radius: number, options?: nearbyOptions): number, number, number, number, nearbyOptions
---@field _normalizeOptions fun(options?: nearbyOptions): nearbyOptions
---@field _measure fun(handle: integer, x: number, y: number, z: number, radius: number): vector3?, number?
---@field _finalize fun<T>(results: T[], options: nearbyOptions): T[]
---@field _getEntityKind fun(handle: integer): nearbyEntityKind?
---@field _collect fun(handles: integer[], kind: nearbySearchKind, x: number, y: number, z: number, radius: number, options: nearbyOptions, excludeHandle?: integer): nearbyEntity[]

local nearby = {}
_ENV.nearby = nearby

--#region Shared Search Helpers

---Valida e copia le opzioni di ricerca.
---@param options? nearbyOptions
---@return nearbyOptions
function nearby._normalizeOptions(options)
    if options == nil then
        options = {}
    else
        assertType("options", options, "table")
    end

    local normalized = {
        centerPlayer = options.centerPlayer,
        excludePlayer = options.excludePlayer,
        excludeEntity = options.excludeEntity,
        includeSelf = options.includeSelf,
        sortByDistance = options.sortByDistance,
        maxResults = options.maxResults,
        routingBucket = options.routingBucket,
    }

    if normalized.centerPlayer ~= nil then
        assertType("centerPlayer", normalized.centerPlayer, "integer")
        assert(normalized.centerPlayer > 0, "centerPlayer must be greater than zero")
    end

    if normalized.excludePlayer ~= nil then
        assertType("excludePlayer", normalized.excludePlayer, "integer")
        assert(normalized.excludePlayer > 0, "excludePlayer must be greater than zero")
    end

    if normalized.excludeEntity ~= nil then
        assertType("excludeEntity", normalized.excludeEntity, "integer")
        assert(normalized.excludeEntity > 0, "excludeEntity must be greater than zero")
    end

    if normalized.includeSelf == nil then
        normalized.includeSelf = false
    else
        assertType("includeSelf", normalized.includeSelf, "boolean")
    end

    if normalized.sortByDistance == nil then
        normalized.sortByDistance = false
    else
        assertType("sortByDistance", normalized.sortByDistance, "boolean")
    end

    if normalized.maxResults ~= nil then
        assertType("maxResults", normalized.maxResults, "integer")
        assert(normalized.maxResults >= 0, "maxResults must be greater than or equal to zero")
    end

    if normalized.routingBucket ~= nil then
        assertType("routingBucket", normalized.routingBucket, "integer")
        assert(normalized.routingBucket >= 0, "routingBucket must be greater than or equal to zero")
    end

    return normalized
end

---Valida il centro, il raggio e le opzioni.
---@param center vector3|vector4|table
---@param radius number
---@param options? nearbyOptions
---@return number x
---@return number y
---@return number z
---@return number radius
---@return nearbyOptions options
function nearby._normalize(center, radius, options)
    local centerType = type(center)

    assert(
        centerType == "table" or centerType == "vector3" or centerType == "vector4",
        "center must be a table, vector3 or vector4"
    )

    assertType("center.x", center.x, "number")
    assertType("center.y", center.y, "number")
    assertType("center.z", center.z, "number")
    assertType("radius", radius, "number")
    assert(radius >= 0, "radius must be greater than or equal to zero")

    local normalized = nearby._normalizeOptions(options)

    return center.x, center.y, center.z, radius, normalized
end

---Determina il tipo di un'entità.
---@param handle integer
---@return nearbyEntityKind?
function nearby._getEntityKind(handle)
    local entityType = GetEntityType(handle)

    if entityType == 1 then
        return "ped"
    elseif entityType == 2 then
        return "vehicle"
    elseif entityType == 3 then
        return "object"
    end

    return nil
end

---Restituisce posizione e distanza se l'entità rientra nel raggio.
---@param handle integer
---@param x number
---@param y number
---@param z number
---@param radius number
---@return vector3? coords
---@return number? distance
function nearby._measure(handle, x, y, z, radius)
    if handle == 0 or not DoesEntityExist(handle) then
        return nil
    end

    local coords = GetEntityCoords(handle)

    local dx = coords.x - x
    local dy = coords.y - y
    local dz = coords.z - z

    local distanceSquared = dx * dx + dy * dy + dz * dz

    if distanceSquared > radius * radius then
        return nil
    end

    return coords, math.sqrt(distanceSquared)
end

---Ordina e limita i risultati secondo le opzioni.
---@generic T: nearbyResult
---@param results T[]
---@param options nearbyOptions
---@return T[]
function nearby._finalize(results, options)
    if options.sortByDistance then
        table.sort(results, function(a, b)
            return a.distance < b.distance
        end)
    end

    local maxResults = options.maxResults

    if maxResults and #results > maxResults then
        for i = #results, maxResults + 1, -1 do
            results[i] = nil
        end
    end

    return results
end

---@param results nearbyEntity[]
---@param handle integer
---@param kind nearbySearchKind
---@param x number
---@param y number
---@param z number
---@param radius number
---@param options nearbyOptions
---@param excludeHandle? integer
---@return boolean added
function nearby._appendEntity(results, handle, kind, x, y, z, radius, options, excludeHandle)
    if handle == 0 or handle == excludeHandle or handle == options.excludeEntity then
        return false
    end

    ---@type nearbyEntityKind|nil
    local entityKind

    if kind == "all" then
        entityKind = nearby._getEntityKind(handle)
    elseif kind == "ped" then
        entityKind = "ped"
    elseif kind == "vehicle" then
        entityKind = "vehicle"
    elseif kind == "object" then
        entityKind = "object"
    end

    if not entityKind then
        return false
    end

    local coords, distance = nearby._measure(handle, x, y, z, radius)

    if not coords or not distance then
        return false
    end

    results[#results + 1] = {
        handle = handle,
        kind = entityKind,
        coords = coords,
        distance = distance,
    }

    return true
end

---Raccoglie le entità che corrispondono ai criteri di ricerca.
---@param handles integer[]
---@param kind nearbySearchKind
---@param x number
---@param y number
---@param z number
---@param radius number
---@param options nearbyOptions
---@param excludeHandle? integer
---@return nearbyEntity[]
function nearby._collect(handles, kind, x, y, z, radius, options, excludeHandle)
    local results = {}
    local maxResults = options.maxResults
    local sortByDistance = options.sortByDistance

    if maxResults == 0 then
        return results
    end

    for i = 1, #handles do
        local added = nearby._appendEntity(results, handles[i], kind, x, y, z, radius, options, excludeHandle)

        if added and maxResults and not sortByDistance then
            if #results >= maxResults then
                break
            end
        end
    end

    return nearby._finalize(results, options)
end

--#endregion
