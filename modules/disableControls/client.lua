---@meta

--#region Native Upvalue Optimization

local DisableControlAction <const> = DisableControlAction
local DisablePlayerFiring <const>  = DisablePlayerFiring
local PlayerId <const>             = PlayerId

--#endregion

---@alias ControlType integer | string

---@class DisableControlsHandle
---@field active boolean
---@field stop fun(self: DisableControlsHandle)
---@field isRunning fun(self: DisableControlsHandle): boolean
local DisableControlsHandle = {}
DisableControlsHandle.__index = DisableControlsHandle

function DisableControlsHandle:stop()
    self.active = false
end

function DisableControlsHandle:isRunning()
    return self.active == true
end

--#region Named Controls Mapping

---@type table<string, integer>
local namedControls = {
    fire            = 24,
    attack          = 24,
    aim             = 25,
    attack2         = 25,
    vehicle_attack  = 69,
    vehicle_attack2 = 70,
    melee           = 140,
    melee2          = 141,
    jump            = 22,
    sprint          = 21,
    duck            = 36,
    crouch          = 36,
    enter_vehicle   = 23,
    exit_vehicle    = 75,
    reload          = 45,
    weapon_wheel    = 37,
    next_weapon     = 14,
    prev_weapon     = 15,
    move_lr         = 30,
    move_ud         = 31,
    look_lr         = 1,
    look_ud         = 2,
    cover           = 44,
    radar           = 19,
    character_wheel = 19,
    pause           = 199,
}

--#endregion

--#region Internal Resolver

---Risolve un controllo (ID numerico o nome stringa) nel rispettivo intero nativo di GTA 5.
---@param ctrl ControlType
---@return integer
local function resolveControlId(ctrl)
    if type(ctrl) == "number" then
        return math.floor(ctrl)
    elseif type(ctrl) == "string" then
        local found = namedControls[ctrl:lower()]
        if not found then
            error(("unknown control name \"%s\""):format(ctrl), 3)
        end
        return found
    end

    error(("invalid control type \"%s\", expected integer or string"):format(type(ctrl)), 3)
end

---Disabilita un singolo controllo per il frame corrente.
---@param controlId integer
---@param padIndex? integer
local function disableSingleControl(controlId, padIndex)
    padIndex = padIndex or 0
    DisableControlAction(padIndex, controlId, true)

    if controlId == 24 or controlId == 257 or controlId == 140 then
        DisablePlayerFiring(cache.playerId or PlayerId(), true)
    end
end

--#endregion

--#region Module Definition

---@class disableControlslib
---@field names table<string, integer>
---@field loop fun(controls: ControlType[] | ControlType, padIndex?: integer): DisableControlsHandle
---@overload fun(...: ControlType | ControlType[])
local disableControlsModule = {
    names = namedControls,
}

---Disabilita uno o più controlli per il frame corrente.
---Supporta parametri variadici (es. `disableControls(12, 24)`) o array (es. `disableControls({ 12, 24, "fire" })`).
---@param ... ControlType | ControlType[]
local function disableControlsHandler(...)
    local count = select("#", ...)

    for i = 1, count do
        local item = select(i, ...)

        if type(item) == "table" then
            for j = 1, #item do
                local id = resolveControlId(item[j])
                disableSingleControl(id)
            end
        else
            local id = resolveControlId(item)
            disableSingleControl(id)
        end
    end
end

---Avvia un loop in background (Wait 0) che disabilita i controlli specificati finché l'handle non viene fermato.
---@param controls ControlType[] | ControlType
---@param padIndex? integer
---@return DisableControlsHandle
function disableControlsModule.loop(controls, padIndex)
    local items = type(controls) == "table" and controls or { controls }
    local resolved = {}

    for i = 1, #items do
        resolved[#resolved + 1] = resolveControlId(items[i])
    end

    local handle = setmetatable({ active = true }, DisableControlsHandle)

    async(function()
        while handle.active do
            for i = 1, #resolved do
                disableSingleControl(resolved[i], padIndex)
            end
            Wait(0)
        end
    end)

    return handle
end

--#endregion

--#region Metatable

setmetatable(disableControlsModule, {
    __call = function(_, ...)
        return disableControlsHandler(...)
    end,
})

_ENV.disableControls = disableControlsModule
