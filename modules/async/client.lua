---@meta

---Esegue una funzione in un thread immediato senza allocazioni di classe superflue.
---@param callback fun(threadId?: integer)
function _ENV.async(callback)
    Citizen.CreateThreadNow(callback)
end

