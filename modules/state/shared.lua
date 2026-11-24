---@meta

--#region Native Upvalues & Optimization

local AddStateBagChangeHandler    <const> = AddStateBagChangeHandler
local RemoveStateBagChangeHandler <const> = RemoveStateBagChangeHandler
local PlayerId                    <const> = PlayerId
local GetPlayerServerId           <const> = GetPlayerServerId

--#endregion

--#region Types

---@class statelib
---@field player       fun(src: integer): StateBagChangeHandlerResponse
---@field entity       fun(handle: integer): StateBagChangeHandlerResponse
---@field localPlayer  fun(): StateBagChangeHandlerResponse
---@field get          fun(target: integer|"local"|"global", key: string, default?: any): any
---@field set          fun(target: integer|"local"|"global", key: string, value: any, replicated?: boolean): boolean
---@field listen       fun(key: string, bagFilter: string?, handler: fun(value: any, bagName: string, replicated: boolean)): integer
---@field listenPlayer fun(src: integer, key: string, handler: fun(value: any, replicated: boolean)): integer
---@field listenLocal  fun(key: string, handler: fun(value: any, replicated: boolean)): integer
---@field unlisten     fun(cookie: integer): boolean
local state = {}

_ENV.state = state

--#endregion

--#region Target Resolution

---Restituisce lo State Bag associato al target specificato.
---@param target integer | "local" | "global" | StateBagChangeHandlerResponse
---@return StateBagChangeHandlerResponse?
local function resolveBag(target)
    if type(target) == "table" and target.set ~= nil then
        return target
    end

    if target == "global" then
        return GlobalState
    end

    if target == "local" then
        return (not hzd:is("server")) and LocalPlayer.state or nil
    end

    if type(target) == "number" then
        return Player(target).state
    end

    return nil
end

--#endregion

--#region Bag Accessors

---Restituisce lo State Bag di un player dato il suo server source.
---@param src integer
---@return StateBagChangeHandlerResponse
function state.player(src)
    assertType("src", src, "integer")
    return Player(src).state
end

---Restituisce lo State Bag di un'entità (ped, veicolo, object).
---@param handle integer
---@return StateBagChangeHandlerResponse
function state.entity(handle)
    assertType("handle", handle, "integer")
    return Entity(handle).state
end

---Restituisce lo State Bag del player locale (solo client).
---@return StateBagChangeHandlerResponse?
function state.localPlayer()
    if hzd:is("server") then return nil end
    return LocalPlayer.state
end

--#endregion

--#region Read & Write

---Legge un valore dallo State Bag con supporto a fallback predefinito.
---@param target integer | "local" | "global"
---@param key    string
---@param default? any
---@return any
function state.get(target, key, default)
    assertType("key", key, "string")
    local bag = resolveBag(target)
    if not bag then return default end

    local val = bag[key]
    return val ~= nil and val or default
end

---Imposta un valore in uno State Bag con replica automatica opzionale.
---@param target     integer | "local" | "global"
---@param key        string
---@param value      any
---@param replicated? boolean  Default true
---@return boolean
function state.set(target, key, value, replicated)
    assertType("key", key, "string")
    local bag = resolveBag(target)
    if not bag then return false end

    if replicated == nil then
        replicated = true
    end

    bag:set(key, value, replicated)
    return true
end

--#endregion

--#region Listeners

---Registra un listener generico su uno State Bag.
---@param key        string   Chiave da monitorare (o "" per tutte)
---@param bagFilter? string   Filtro bag (es. "player:1", "entity:123", o nil per globale)
---@param handler    fun(value: any, bagName: string, replicated: boolean)
---@return integer cookie   Handle utilizzabile con state.unlisten
function state.listen(key, bagFilter, handler)
    assertType("key", key, "string")
    assertType("handler", handler, "function")

    return AddStateBagChangeHandler(key, bagFilter, function(bagName, _, value, _unused, replicated)
        handler(value, bagName, replicated == true)
    end)
end

---Registra un listener specifico sullo State Bag di un dato player.
---@param src     integer
---@param key     string
---@param handler fun(value: any, replicated: boolean)
---@return integer cookie
function state.listenPlayer(src, key, handler)
    assertType("src", src, "integer")
    assertType("key", key, "string")
    assertType("handler", handler, "function")

    local bagFilter = ("player:%d"):format(src)
    return state.listen(key, bagFilter, function(value, _, replicated)
        handler(value, replicated)
    end)
end

---Registra un listener specifico per il LocalPlayer (solo client).
---@param key     string
---@param handler fun(value: any, replicated: boolean)
---@return integer cookie
function state.listenLocal(key, handler)
    assert(not hzd:is("server"), "state.listenLocal can only be used on client runtime")
    assertType("key", key, "string")
    assertType("handler", handler, "function")

    local mySource = GetPlayerServerId(PlayerId())
    return state.listenPlayer(mySource, key, handler)
end

---Rimuove un listener di stato precedentemente registrato.
---@param cookie integer
---@return boolean
function state.unlisten(cookie)
    assertType("cookie", cookie, "integer")
    RemoveStateBagChangeHandler(cookie)
    return true
end

--#endregion

