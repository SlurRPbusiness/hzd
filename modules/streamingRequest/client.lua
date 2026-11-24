---@meta

--#region Native Upvalue Optimization

local HasModelLoaded <const>                 = HasModelLoaded
local IsModelValid <const>                   = IsModelValid
local IsModelInCdimage <const>               = IsModelInCdimage
local RequestModel <const>                   = RequestModel
local HasAnimDictLoaded <const>              = HasAnimDictLoaded
local DoesAnimDictExist <const>              = DoesAnimDictExist
local RequestAnimDict <const>                = RequestAnimDict
local HasAnimSetLoaded <const>               = HasAnimSetLoaded
local RequestAnimSet <const>                 = RequestAnimSet
local HasStreamedTextureDictLoaded <const>   = HasStreamedTextureDictLoaded
local RequestStreamedTextureDict <const>     = RequestStreamedTextureDict
local HasNamedPtfxAssetLoaded <const>        = HasNamedPtfxAssetLoaded
local RequestNamedPtfxAsset <const>          = RequestNamedPtfxAsset
local RequestScaleformMovie <const>          = RequestScaleformMovie
local HasScaleformMovieLoaded <const>        = HasScaleformMovieLoaded
local HasWeaponAssetLoaded <const>           = HasWeaponAssetLoaded
local RequestWeaponAsset <const>             = RequestWeaponAsset
local RequestCollisionAtCoord <const>        = RequestCollisionAtCoord
local HasCollisionLoadedAroundEntity <const> = HasCollisionLoadedAroundEntity
local PlayerPedId <const>                    = PlayerPedId
local GetGroundZFor_3dCoord <const>          = GetGroundZFor_3dCoord

--#endregion

---@class streaming
streaming = {}

--#region Core Request Helper

---Invia una richiesta di streaming e attende in modo sicuro fino al caricamento completo dell'asset o al timeout.
---@generic T: string | integer
---@param requestFn fun(asset: T)           funzione nativa per richiedere l'asset (es. RequestModel)
---@param checkFn fun(asset: T): boolean    funzione nativa per verificare se è caricato (es. HasModelLoaded)
---@param assetType string                  nome descrittivo del tipo di asset (per eventuali errori)
---@param asset T                           identificativo o hash dell'asset
---@param timeout? integer                  tempo massimo di attesa in millisecondi (default 10000)
---@return T
function _ENV.streamingRequest(requestFn, checkFn, assetType, asset, timeout)
    timeout = timeout or 10000

    if checkFn(asset) then
        return asset
    end

    requestFn(asset)

    awaitFor(function()
        return checkFn(asset)
    end, ("timed out after %sms while loading %s \"%s\""):format(timeout, assetType, tostring(asset)), timeout)

    return asset
end

streaming.request = _ENV.streamingRequest

--#endregion

--#region Asset Loaders

---Carica un modello 3D in memoria (accetta sia stringa che hash joaat).
---@param model string | integer
---@param timeout? integer
---@return integer
function _ENV.requestModel(model, timeout)
    assertType(1, model, "string|number")

    local hash = (type(model) == "number" and model or joaat(model)) --[[@as integer]]

    if HasModelLoaded(hash) then
        return hash
    end

    if not IsModelValid(hash) or not IsModelInCdimage(hash) then
        error(("attempted to load invalid model \"%s\""):format(tostring(model)), 2)
    end

    streamingRequest(RequestModel, HasModelLoaded, "model", hash, timeout)

    return hash
end

---Carica un dizionario di animazioni.
---@param animDict string
---@param timeout? integer
---@return string
function _ENV.requestAnimDict(animDict, timeout)
    assertType(1, animDict, "string")

    if HasAnimDictLoaded(animDict) then
        return animDict
    end

    if not DoesAnimDictExist(animDict) then
        error(("attempted to load non-existent animDict \"%s\""):format(animDict), 2)
    end

    return streamingRequest(RequestAnimDict, HasAnimDictLoaded, "animDict", animDict, timeout)
end

---Carica un set di animazioni (clipset).
---@param animSet string
---@param timeout? integer
---@return string
function _ENV.requestAnimSet(animSet, timeout)
    assertType(1, animSet, "string")

    if HasAnimSetLoaded(animSet) then
        return animSet
    end

    return streamingRequest(RequestAnimSet, HasAnimSetLoaded, "animSet", animSet, timeout)
end

---Carica un dizionario di texture in streaming.
---@param textureDict string
---@param timeout? integer
---@return string
function _ENV.requestStreamedTextureDict(textureDict, timeout)
    assertType(1, textureDict, "string")

    if HasStreamedTextureDictLoaded(textureDict) then
        return textureDict
    end

    return streamingRequest(RequestStreamedTextureDict, HasStreamedTextureDictLoaded, "textureDict", textureDict, timeout)
end

---Carica un asset di effetti particellari nominati (PTFX).
---@param ptfx string
---@param timeout? integer
---@return string
function _ENV.requestNamedPtfxAsset(ptfx, timeout)
    assertType(1, ptfx, "string")

    if HasNamedPtfxAssetLoaded(ptfx) then
        return ptfx
    end

    return streamingRequest(RequestNamedPtfxAsset, HasNamedPtfxAssetLoaded, "ptfx", ptfx, timeout)
end

---Carica un filmato scaleform e ne restituisce l'handle.
---@param scaleform string
---@param timeout? integer
---@return integer handle
function _ENV.requestScaleformMovie(scaleform, timeout)
    assertType(1, scaleform, "string")

    local handle = RequestScaleformMovie(scaleform)

    if HasScaleformMovieLoaded(handle) then
        return handle
    end

    return streamingRequest(function() end, HasScaleformMovieLoaded, "scaleform", handle, timeout)
end

---Carica le risorse grafiche di un'arma.
---@param weapon string | integer
---@param timeout? integer
---@return integer
function _ENV.requestWeaponAsset(weapon, timeout)
    assertType(1, weapon, "string|number")

    local hash = (type(weapon) == "number" and weapon or joaat(weapon)) --[[@as integer]]

    if HasWeaponAssetLoaded(hash) then
        return hash
    end

    streamingRequest(RequestWeaponAsset, HasWeaponAssetLoaded, "weapon", hash, timeout)

    return hash
end

---Richiede il caricamento delle collisioni in una coordinata e attende che siano disponibili.
---@param x number
---@param y number
---@param z number
---@param timeout? integer
---@return vector3
function _ENV.requestCollisionAtCoord(x, y, z, timeout)
    assertType(1, x, "number")
    assertType(2, y, "number")
    assertType(3, z, "number")

    timeout = timeout or 10000

    RequestCollisionAtCoord(x, y, z)

    awaitFor(function()
            return HasCollisionLoadedAroundEntity(PlayerPedId())
        end, ("timed out after %sms while loading collision at coords (%s, %s, %s)")
        :format(timeout, x, y, z), timeout)

    return vec3(x, y, z)
end

---Carica le collisioni dell'area e cerca la quota Z del terreno.
---@param x number
---@param y number
---@param timeout? integer
---@return number
function _ENV.requestGroundZ(x, y, timeout)
    assertType(1, x, "number")
    assertType(2, y, "number")

    timeout = timeout or 10000

    local heights = { 1000.0, 750.0, 500.0, 250.0, 100.0, 50.0, 0.0 }

    for i = 1, #heights do
        local height = heights[i]

        requestCollisionAtCoord(x, y, height, timeout)

        local found, groundZ = GetGroundZFor_3dCoord(x, y, height, false)

        if found then
            return groundZ + 1.0
        end
    end

    error(("unable to resolve ground collision at (%s, %s)"):format(x, y), 2)
end
