---@meta

--#region Modulo NUI Sicuro

---@class NuiNotifyOptions
---@field title? string Titolo della notifica
---@field message string Testo del messaggio
---@field type? "info" | "success" | "warning" | "error" | "pvp" | "kill" | "streak" Tipo di notifica
---@field duration? integer Durata in millisecondi (default: 4000)
---@field position? "top-right" | "top-left" | "top-center" | "bottom-right" | "bottom-left" | "bottom-center" Posizione
---@field icon? string Icona o logo personalizzato (opzionale)
---@field badge? string Testo badge/etichetta (es: "HEADSHOT", "ROUND 1")
---@field sound? boolean Riproduci feedback sonoro fluido Apple (default: true)

---@class nuilib : table
---@field send fun(action: string, data?: table) Invia un messaggio alla NUI con token di sessione
---@field update fun(data: table) Aggiorna lo stato della NUI
---@field register fun(action: string, handler: fun(data: table, cb: fun(response?: any))) Registra una callback NUI con verifica del token di sessione
---@field notify fun(options: NuiNotifyOptions | string) Mostra una notifica stile Apple con fisica a molla
---@field setFocus fun(hasCursor?: boolean, keepInput?: boolean) Imposta il focus dell'interfaccia
---@field removeFocus fun() Rimuove completamente il focus dell'interfaccia
---@field isReady fun(): boolean Verifica se la NUI ha completato l'handshake
---@field open fun(view?: string, data?: table) Invia comando di apertura vista
---@field close fun(view?: string) Invia comando di chiusura vista
---@field toggle fun(view?: string, data?: table) Inverte lo stato di visualizzazione
local nui = {}

-- Token di sessione crittografico unico per la sessione client
local sessionToken = sha256.hex(("%s:%s:%s:%d:%d"):format(
    hzd.name,
    hzd.version,
    cache.resource,
    GetGameTimer(),
    math.random(1000000, 9999999)
))

local isNuiReady = false
local pendingMessages = {}

--#endregion

--#region Funzioni Interne di Sicurezza

---Sanifica ed estrae il payload JSON da una richiesta grezza NUI.
---@param rawData table
---@return boolean isValid, table? payload, string? errorMsg
local function verifyAndParseRawRequest(rawData)
    if type(rawData) ~= "table" then
        return false, nil, "Richiesta NUI malformata"
    end

    local rawBody = rawData.body
    local decoded

    if rawBody == nil or rawBody == "" then
        decoded = {}
    elseif type(rawBody) == "string" then
        local success, result = pcall(json.decode, rawBody)
        if not success or type(result) ~= "table" then
            return false, nil, "Corpo richiesta non è un JSON valido"
        end
        decoded = result
    elseif type(rawBody) == "table" then
        decoded = rawBody
    else
        return false, nil, "Tipo corpo non supportato"
    end

    local headers = type(rawData.headers) == "table" and rawData.headers or {}
    local receivedToken = headers["x-nui-token"]
        or headers["X-Nui-Token"]
        or headers["x-nui-auth"]
        or decoded.__token

    if receivedToken ~= sessionToken then
        return false, nil, "Accesso Negato: Token di sicurezza NUI non valido o assente"
    end

    decoded.__token = nil

    return true, decoded, nil
end

--#endregion

--#region Metodi Pubblici NUI

---Verifica se l'interfaccia web ha completato la sincronizzazione iniziale.
---@return boolean
function nui.isReady()
    return isNuiReady
end

---Invia un messaggio alla NUI includendo token di validazione e timestamp.
---@param action string Nome dell'azione
---@param data? table Dati associati
function nui.send(action, data)
    assertType("action", action, "string")

    local envelope = {
        action    = action,
        data      = data or {},
        token     = sessionToken,
        timestamp = GetGameTimer(),
        resource  = cache.resource,
    }

    if not isNuiReady and action ~= "__handshake" then
        pendingMessages[#pendingMessages + 1] = envelope
        return
    end

    SendNUIMessage(envelope)
end

---Invia un aggiornamento generico di stato alla NUI.
---@param data table
function nui.update(data)
    assertType("data", data, "table")
    nui.send("update", data)
end

---Invia una notifica con animazione fisica a molla stile Apple.
---@param options NuiNotifyOptions | string
function nui.notify(options)
    if type(options) == "string" then
        options = {
            message = options,
            type = "info",
        }
    end

    assertType("options", options, "table")
    assertType("message", options.message, "string")

    local payload = {
        id       = ("notif_%d_%d"):format(GetGameTimer(), math.random(100, 999)),
        title    = options.title or nil,
        message  = options.message,
        type     = options.type or "info",
        duration = options.duration or 4000,
        position = options.position or "top-right",
        icon     = options.icon or nil,
        badge    = options.badge or nil,
        sound    = options.sound ~= false,
    }

    nui.send("notify", payload)
end

---Registra un endpoint NUI utilizzando RegisterRawNuiCallback e verifica il token di sessione.
---@param action string Nome identificativo della callback
---@param handler fun(data: table, cb: fun(response?: any)) Funzione di gestione
function nui.register(action, handler)
    assertType("action", action, "string")
    assertType("handler", handler, "function")

    RegisterRawNuiCallback(action, function(requestData, respond)
        local isValid, payload, errorMsg = verifyAndParseRawRequest(requestData)

        if not isValid then
            print.warn(("Richiesta NUI rifiutata per '%s': %s"):format(action,
                errorMsg or "Sconosciuto"))
            respond(json.encode({
                success = false,
                error   = errorMsg or "Access Denied",
            }))
            return
        end

        local responded = false
        local function safeCallback(responsePayload)
            if responded then return end
            responded = true
            respond(json.encode(responsePayload or { success = true }))
        end

        local success, resultError = pcall(handler, payload, safeCallback)
        if not success then
            print.error(("Errore nel callback NUI '%s': %s"):format(action,
                tostring(resultError)))
            safeCallback({
                success = false,
                error   = "Internal Handler Error",
            })
        end
    end)
end

---Imposta lo stato del focus dell'interfaccia NUI con gestione opzionale del cursore e tastiera.
---@param hasCursor? boolean Abilita o disabilita il cursore del mouse (default: true)
---@param keepInput? boolean Se true, consente al giocatore di muoversi mantenendo il focus (default: false)
function nui.setFocus(hasCursor, keepInput)
    local cursorState = hasCursor ~= false
    local inputState = keepInput == true

    SetNuiFocus(cursorState, cursorState)
    SetNuiFocusKeepInput(inputState)
end

---Rimuove completamente il focus della NUI ripristinando il pieno controllo di gioco.
function nui.removeFocus()
    SetNuiFocus(false, false)
    SetNuiFocusKeepInput(false)
end

---Invia il comando di apertura di una specifica schermata o vista NUI.
---@param view? string Nome della vista da aprire
---@param data? table Dati contestuali iniziali
function nui.open(view, data)
    nui.send("open", {
        view = view,
        data = data,
    })
end

---Invia il comando di chiusura di una schermata o vista NUI.
---@param view? string Nome della vista
function nui.close(view)
    nui.send("close", {
        view = view,
    })
end

---Inverte lo stato di visualizzazione di una schermata NUI.
---@param view? string Nome della vista
---@param data? table Dati contestuali opzionali
function nui.toggle(view, data)
    nui.send("toggle", {
        view = view,
        data = data,
    })
end

--#endregion

--#region Inizializzazione e Handshake Sicuro

RegisterRawNuiCallback("__init_handshake", function(requestData, respond)
    isNuiReady = true

    respond(json.encode({
        success  = true,
        token    = sessionToken,
        resource = cache.resource,
        devMode  = debug.isEnabled(),
        language = locale.current,
        translations = locale.export(),
    }))

    if #pendingMessages > 0 then
        for i = 1, #pendingMessages do
            SendNUIMessage(pendingMessages[i])
        end
        pendingMessages = {}
    end
end)

nui.register("exitFocus", function(_, cb)
    nui.removeFocus()
    cb({ success = true })
end)

CreateThread(function()
    Wait(500)
    SendNUIMessage({
        action   = "__handshake",
        token    = sessionToken,
        resource = cache.resource,
        devMode  = debug.isEnabled(),
    })
end)

--#endregion

setmetatable(nui, {
    __call = function()
        return nui
    end,
})

_ENV.nui = nui
