---@meta

--#region Native Upvalue Optimization

local ScaleformMovieMethodAddParamPlayerNameString <const> = ScaleformMovieMethodAddParamPlayerNameString
local ScaleformMovieMethodAddParamInt <const>              = ScaleformMovieMethodAddParamInt
local ScaleformMovieMethodAddParamFloat <const>            = ScaleformMovieMethodAddParamFloat
local ScaleformMovieMethodAddParamBool <const>             = ScaleformMovieMethodAddParamBool
local EndScaleformMovieMethodReturnValue <const>           = EndScaleformMovieMethodReturnValue
local IsScaleformMovieMethodReturnValueReady <const>       = IsScaleformMovieMethodReturnValueReady
local GetScaleformMovieFunctionReturnBool <const>          = GetScaleformMovieFunctionReturnBool
local GetScaleformMovieFunctionReturnInt <const>           = GetScaleformMovieFunctionReturnInt
local GetScaleformMovieFunctionReturnString <const>        = GetScaleformMovieFunctionReturnString
local RequestScaleformMovie <const>                        = RequestScaleformMovie
local HasScaleformMovieLoaded <const>                      = HasScaleformMovieLoaded
local SetScaleformMovieAsNoLongerNeeded <const>            = SetScaleformMovieAsNoLongerNeeded
local DrawScaleformMovieFullscreen <const>                 = DrawScaleformMovieFullscreen
local DrawScaleformMovie <const>                           = DrawScaleformMovie
local BeginScaleformMovieMethod <const>                    = BeginScaleformMovieMethod
local EndScaleformMovieMethod <const>                      = EndScaleformMovieMethod

--#endregion

---@class renderTargetTable
---@field name string
---@field model string | integer

---@class detailsTable
---@field name string
---@field fullScreen? boolean
---@field x? number
---@field y? number
---@field width? number
---@field height? number
---@field renderTarget? renderTargetTable

---@class Scaleform : classlib
---@field sfHandle? integer
---@field target? integer
---@field targetName? string
---@field fullScreen boolean
---@field x number
---@field y number
---@field width number
---@field height number
---@field isDrawingActive boolean
---@field new fun(details: detailsTable | string): Scaleform
---@field callMethod fun(self: Scaleform, name: string, args?: (number | string | boolean)[], returnValue?: "boolean" | "integer" | "string"): any
---@field setFullScreen fun(self: Scaleform, isFullscreen: boolean)
---@field setProperties fun(self: Scaleform, x: number, y: number, width: number, height: number)
---@field setRenderTarget fun(self: Scaleform, name: string, model: string | integer)
---@field draw fun(self: Scaleform)
---@field isDrawing fun(self: Scaleform): boolean
---@field startDrawing fun(self: Scaleform)
---@field stopDrawing fun(self: Scaleform)
---@field dispose fun(self: Scaleform)
---@field setInstructionalButtons fun(self: Scaleform, buttons: table[])
local Scaleform = class("Scaleform") --[[@as Scaleform]]

--#region Argument Helpers

---Converte gli argomenti Lua nei parametri nativi compatibili con lo scaleform.
---@param argsTable (number | string | boolean)[]
local function convertArgs(argsTable)
    for i = 1, #argsTable do
        local arg = argsTable[i]
        local argType = type(arg)

        if argType == "string" then
            ScaleformMovieMethodAddParamPlayerNameString(arg)
        elseif argType == "number" then
            if math.type(arg) == "integer" then
                ScaleformMovieMethodAddParamInt(arg)
            else
                ScaleformMovieMethodAddParamFloat(arg)
            end
        elseif argType == "boolean" then
            ScaleformMovieMethodAddParamBool(arg)
        else
            error(("unsupported parameter type \"%s\" in scaleform method"):format(argType), 2)
        end
    end
end

---Attende e recupera il valore di ritorno di un metodo scaleform.
---@param expectedType "boolean" | "integer" | "string"
---@return boolean | integer | string
local function retrieveReturnValue(expectedType)
    local result = EndScaleformMovieMethodReturnValue()

    awaitFor(function()
        return IsScaleformMovieMethodReturnValueReady(result)
    end, "failed to retrieve scaleform return value", 1000)

    if expectedType == "integer" then
        return GetScaleformMovieMethodReturnValueInt(result)
    elseif expectedType == "boolean" then
        return GetScaleformMovieMethodReturnValueBool(result)
    end

    return GetScaleformMovieMethodReturnValueString(result)
end

--#endregion

--#region Constructor

---@param details detailsTable | string
function Scaleform:constructor(details)
    local config = type(details) == "table" and details or { name = details }

    assertType(1, config.name, "string")

    self.sfHandle        = requestScaleformMovie(config.name)
    self.isDrawingActive = false

    self.fullScreen      = config.fullScreen or false
    self.x               = config.x or 0
    self.y               = config.y or 0
    self.width           = config.width or 0
    self.height          = config.height or 0

    if config.renderTarget then
        self:setRenderTarget(config.renderTarget.name, config.renderTarget.model)
    end
end

--#endregion

--#region Methods

---Esegue un metodo ActionScript sullo scaleform con argomenti opzionali.
---@param name string
---@param args? (number | string | boolean)[]
---@param returnValue? "boolean" | "integer" | "string"
---@return any
function Scaleform:callMethod(name, args, returnValue)
    if not self.sfHandle then
        error("attempted to call method on invalid scaleform handle", 2)
    end

    BeginScaleformMovieMethod(self.sfHandle, name)

    if args and type(args) == "table" then
        convertArgs(args)
    end

    if returnValue then
        return retrieveReturnValue(returnValue)
    end

    EndScaleformMovieMethod()
end

---Imposta o rimuove la modalità a schermo intero.
---@param isFullscreen boolean
function Scaleform:setFullScreen(isFullscreen)
    assertType(1, isFullscreen, "boolean")
    self.fullScreen = isFullscreen
end

---Imposta coordinate e dimensioni per il disegno non fullscreen.
---@param x number
---@param y number
---@param width number
---@param height number
function Scaleform:setProperties(x, y, width, height)
    if self.fullScreen then
        debug.warn("cannot set scaleform properties when fullScreen is enabled")
        return
    end

    self.x      = x
    self.y      = y
    self.width  = width
    self.height = height
end

---Assegna uno scaleform a un render target (es. schermi di veicoli, monitor).
---@param name string
---@param model string | integer
function Scaleform:setRenderTarget(name, model)
    assertType(1, name, "string")
    assertType(2, model, "string|number")

    if self.target then
        ReleaseNamedRendertarget(self.targetName)
    end

    local modelHash = type(model) == "number" and model or joaat(model)

    if not IsNamedRendertargetRegistered(name) then
        RegisterNamedRendertarget(name, false)

        if not IsNamedRendertargetLinked(modelHash) then
            LinkNamedRendertarget(modelHash)
        end

        self.target     = GetNamedRendertargetRenderId(name)
        self.targetName = name
    end
end

---Disegna lo scaleform per un singolo frame.
function Scaleform:draw()
    if not self.sfHandle then
        return
    end

    if self.target then
        SetTextRenderId(self.target)
        SetScriptGfxDrawOrder(4)
        SetScriptGfxDrawBehindPausemenu(true)
        SetScaleformFitRendertarget(self.sfHandle, true)
    end

    if self.fullScreen then
        DrawScaleformMovieFullscreen(self.sfHandle, 255, 255, 255, 255, 0)
    else
        DrawScaleformMovie(self.sfHandle, self.x, self.y, self.width, self.height, 255, 255, 255, 255, 0)
    end

    if self.target then
        SetTextRenderId(1)
    end
end

---Verifica se il loop di disegno continuo è attivo.
---@return boolean
function Scaleform:isDrawing()
    return self.isDrawingActive == true
end

---Avvia un thread in background che disegna lo scaleform ad ogni frame.
function Scaleform:startDrawing()
    if self.isDrawingActive then
        return
    end

    self.isDrawingActive = true

    async(function()
        while self.isDrawingActive do
            self:draw()
            Wait(0)
        end
    end)
end

---Arresta il loop di disegno continuo.
function Scaleform:stopDrawing()
    self.isDrawingActive = false
end

---Rilascia lo scaleform dalla memoria video e libera il render target.
function Scaleform:dispose()
    self.isDrawingActive = false

    if self.sfHandle then
        SetScaleformMovieAsNoLongerNeeded(self.sfHandle)
        self.sfHandle = nil
    end

    if self.target then
        ReleaseNamedRendertarget(self.targetName)
        self.target     = nil
        self.targetName = nil
    end
end

--#endregion

--#region Instructional Buttons Helper (Speciale per NoClip / Menù di Controllo)

---Configura e disegna la barra dei comandi a schermo (instructional_buttons).
---Richiama internamente GetControlInstructionalButton per ogni comando.
---Supporta formato a oggetti `{ label = "Avanti", control = 32 }` o array stile txAdmin `{ "Avanti", 32 }`.
---@param buttons ({ label: string, control: integer | string, padIndex?: integer } | { [1]: string, [2]: integer })[]
function Scaleform:setInstructionalButtons(buttons)
    assertType(1, buttons, "table")

    if not self.sfHandle then
        return
    end

    BeginScaleformMovieMethod(self.sfHandle, "CLEAR_ALL")
    EndScaleformMovieMethod()

    BeginScaleformMovieMethod(self.sfHandle, "SET_CLEAR_SPACE")
    ScaleformMovieMethodAddParamInt(200)
    EndScaleformMovieMethod()

    for btnIndex = 1, #buttons do
        local item      = buttons[btnIndex]
        local label     = item.label or item[1]
        local control   = item.control or item[2] or item.button
        local padIndex  = item.padIndex or 0

        local btnString = ""

        if type(control) == "number" then
            btnString = GetControlInstructionalButton(padIndex, math.floor(control), true)
        elseif type(control) == "string" then
            if control:sub(1, 1) == "~" then
                btnString = control
            else
                local resolved = disableControls and disableControls.names and disableControls.names[control:lower()]
                if resolved then
                    btnString = GetControlInstructionalButton(padIndex, resolved, true)
                else
                    btnString = control
                end
            end
        end

        BeginScaleformMovieMethod(self.sfHandle, "SET_DATA_SLOT")
        ScaleformMovieMethodAddParamInt(btnIndex - 1)
        ScaleformMovieMethodAddParamPlayerNameString(btnString)
        BeginTextCommandScaleformString("STRING")
        AddTextComponentSubstringKeyboardDisplay(label or "")
        EndTextCommandScaleformString()
        EndScaleformMovieMethod()
    end

    BeginScaleformMovieMethod(self.sfHandle, "DRAW_INSTRUCTIONAL_BUTTONS")
    EndScaleformMovieMethod()

    BeginScaleformMovieMethod(self.sfHandle, "SET_BACKGROUND_COLOUR")
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamInt(0)
    ScaleformMovieMethodAddParamInt(80)
    EndScaleformMovieMethod()
end

--#endregion

--#region Global Export

---@class scaleformlib : Scaleform
---@field new fun(details: detailsTable | string): Scaleform
---@overload fun(details: detailsTable | string): Scaleform
local scaleformWrapper = setmetatable({
    new = function(details)
        return Scaleform.new(details)
    end,
}, {
    __call = function(_, details)
        return Scaleform.new(details)
    end,
    __index = Scaleform,
})

_ENV.scaleform = scaleformWrapper
