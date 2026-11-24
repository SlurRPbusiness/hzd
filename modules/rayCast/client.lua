---@meta

--#region Native Upvalue Optimization

local PlayerPedId <const>              = PlayerPedId
local StartShapeTestLosProbe <const>   = StartShapeTestLosProbe
local GetShapeTestResult <const>       = GetShapeTestResult
local GetFinalRenderedCamCoord <const> = GetFinalRenderedCamCoord

--#endregion

---@class raycastlib
---@field fromCoords fun(self: raycastlib, origin: vector3|vector4|table, destination: vector3|vector4|table, flags?: integer, ignore?: integer, options?: integer): boolean, vector3, vector3, integer
---@field fromCamera fun(self: raycastlib, destination: number|vector3|vector4|table, flags?: integer, ignore?: integer, options?: integer): boolean, vector3, vector3, integer
local rayCast = {}
_ENV.rayCast = rayCast

local DEFAULT_FLAGS = 511
local DEFAULT_OPTIONS = 7

---@param coords vector3|vector4|table
---@param name string
---@return vector3
local function normalizeCoords(coords, name)
    local coordsType = type(coords)
    assert(
        coordsType == "vector3" or coordsType == "vector4" or coordsType == "table",
        ("%s must be a vector3, vector4 or table"):format(name)
    )

    assertType(name .. ".x", coords.x, "number")
    assertType(name .. ".y", coords.y, "number")
    assertType(name .. ".z", coords.z, "number")

    return vector3(coords.x, coords.y, coords.z)
end

---@param origin vector3|vector4|table
---@param destination vector3|vector4|table
---@param flags? integer
---@param ignore? integer
---@param options? integer
---@return boolean didHit
---@return vector3 endCoords
---@return vector3 surfaceNormal
---@return integer entityHit
function rayCast:fromCoords(origin, destination, flags, ignore, options)
    local startCoords = normalizeCoords(origin, "origin")
    local endCoords = normalizeCoords(destination, "destination")

    flags = flags or DEFAULT_FLAGS
    ignore = ignore or PlayerPedId()
    options = options or DEFAULT_OPTIONS

    assertType("flags", flags, "integer")
    assertType("ignore", ignore, "integer")
    assertType("options", options, "integer")

    local handle = StartShapeTestLosProbe(
        startCoords.x,
        startCoords.y,
        startCoords.z,
        endCoords.x,
        endCoords.y,
        endCoords.z,
        flags,
        ignore,
        options
    )

    local didHit = false
    local hitCoords = endCoords
    local surfaceNormal = vector3(0.0, 0.0, 0.0)
    local entityHit = 0

    if handle ~= 0 then
        local status

        repeat
            status, didHit, hitCoords, surfaceNormal, entityHit = GetShapeTestResult(handle)

            if status == 1 then
                Wait(0)
            end
        until status ~= 1

        if status ~= 2 then
            didHit = false
            hitCoords = endCoords
            surfaceNormal = vector3(0.0, 0.0, 0.0)
            entityHit = 0
        end
    end

    return didHit, hitCoords, surfaceNormal, entityHit
end

---Lancia un raycast dal centro della camera finale renderizzata.
---destination può essere una distanza in unità di gioco o una coordinata finale.
---@param destination number|vector3|vector4|table
---@param flags? integer
---@param ignore? integer
---@param options? integer
---@return boolean didHit
---@return vector3 endCoords
---@return vector3 surfaceNormal
---@return integer entityHit
function rayCast:fromCamera(destination, flags, ignore, options)
    local origin = GetFinalRenderedCamCoord()
    local destinationType = type(destination)

    if destinationType == "number" then
        assert(math.isFinite(destination) and destination > 0, "destination distance must be a positive finite number")

        local direction = math.rotationToDirection(GetFinalRenderedCamRot(2))
        destination = origin + direction * destination
    end

    destination = normalizeCoords(destination, "destination")
    local didHit, hitCoords, surfaceNormal, entityHit = rayCast.fromCoords(
        self,
        origin,
        destination,
        flags,
        ignore,
        options
    )

    return didHit, hitCoords, surfaceNormal, entityHit
end
