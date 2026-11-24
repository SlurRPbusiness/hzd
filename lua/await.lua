---@meta

---@class Promise<T>
---@field next fun(self: Promise<T>, onFulfilled?: fun(value: T): any, onRejected: fun(err: any): any): Promise<any>
---@field resolve fun(self: Promise<T>, value: T)
---@field reject fun(self: Promise<T>, reason: any)

--#region Await

---Attende il completamento di una promise o funzione asincrona nel thread corrente.
---@generic T
---@param target Promise<T> | fun(): T
---@return T
function _ENV.await(target)
    if type(target) == "function" then
        local deferred = promise.new()

        Citizen.CreateThreadNow(function()
            local success, result = pcall(target)

            if success then
                deferred:resolve(result)
            else
                deferred:reject(result)
            end
        end)

        target = deferred
    end

    return Citizen.Await(target)
end

--#endregion

--#region AwaitFor

---Attende che una funzione restituisca un valore non-nil o diverso da false.
---Cede l'esecuzione ad ogni frame (Wait 0) fino al raggiungimento del timeout.
---@generic T
---@param callback fun(): T?
---@param errorMessage? string  messaggio di errore in caso di timeout
---@param timeout? integer      tempo massimo in millisecondi (default 5000)
---@return T
function _ENV.awaitFor(callback, errorMessage, timeout)
    assert(type(callback) == "function", "callback must be a function")

    timeout = timeout or 5000
    local startTime = GetGameTimer()

    while true do
        local result = callback()

        if result ~= nil and result ~= false then
            return result
        end

        if (GetGameTimer() - startTime) >= timeout then
            local msg = errorMessage or ("awaitFor timed out after " .. tostring(timeout) .. "ms")
            error(msg, 2)
        end

        Wait(0)
    end
end

---Alias per awaitFor.
_ENV.waitFor = _ENV.awaitFor

--#endregion
