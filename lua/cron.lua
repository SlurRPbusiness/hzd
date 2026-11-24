---@meta

---@class CronTask : classlib
---@field id       integer
---@field active   boolean
---@field pattern  string
---@field new      fun(pattern: string, callback: fun(task: CronTask, date: osdate), options?: table): CronTask
local CronTask = class("CronTask") --[[@as CronTask]]

---@class cron
cron = {}

--#region Calendar & Leap Year

local monthDays = { 31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31 }

---Verifica se un anno è bisestile (leap year).
---@param year integer
---@return boolean
function cron.isLeapYear(year)
    assert(type(year) == "number" and year % 1 == 0, "year must be an integer")
    return (year % 4 == 0 and year % 100 ~= 0) or (year % 400 == 0)
end

---Restituisce il numero di giorni presenti in un dato mese considerando gli anni bisestili.
---@param month integer  mese (1-12)
---@param year integer   anno
---@return integer
function cron.daysInMonth(month, year)
    assert(type(month) == "number" and month >= 1 and month <= 12, "month must be between 1 and 12")

    if month == 2 and cron.isLeapYear(year) then
        return 29
    end

    return monthDays[month]
end

--#endregion

--#region Cron Parser

local dayNames = {
    sun = 1, mon = 2, tue = 3, wed = 4, thu = 5, fri = 6, sat = 7,
}

local monthNames = {
    jan = 1, feb = 2, mar = 3, apr = 4, may = 5, jun = 6,
    jul = 7, aug = 8, sep = 9, oct = 10, nov = 11, dec = 12,
}

---Verifica se un singolo valore corrisponde al pattern del campo cron.
---@param field string
---@param value integer
---@param min integer
---@param max integer
---@param nameMap? table<string, integer>
---@return boolean
local function matchField(field, value, min, max, nameMap)
    if field == "*" then
        return true
    end

    field = field:lower()

    if nameMap and nameMap[field] then
        return value == nameMap[field]
    end

    -- Liste: 1,3,5
    if field:find(",", 1, true) then
        for part in field:gmatch("([^,]+)") do
            if matchField(part, value, min, max, nameMap) then
                return true
            end
        end

        return false
    end

    -- Steps: */5 o 10-30/5
    local base, step = field:match("^([^/]+)/(%d+)$")

    if step then
        step = tonumber(step)

        if base == "*" then
            return (value - min) % step == 0
        end

        local startRange, endRange = base:match("^(%d+)%-(%d+)$")

        if startRange and endRange then
            startRange = tonumber(startRange)
            endRange   = tonumber(endRange)

            if value >= startRange and value <= endRange then
                return (value - startRange) % step == 0
            end
        end

        return false
    end

    -- Intervallo: 1-5
    local rangeStart, rangeEnd = field:match("^(%d+)%-(%d+)$")

    if rangeStart and rangeEnd then
        return value >= tonumber(rangeStart) and value <= tonumber(rangeEnd)
    end

    -- Numero esatto
    return tonumber(field) == value
end

---Verifica se la data attuale soddisfa un'espressione cron a 5 campi.
---@param expression string  "minuti ore giornoMese mese giornoSettimana"
---@param date osdate
---@return boolean
function cron.matches(expression, date)
    local parts = {}

    for part in expression:gmatch("%S+") do
        parts[#parts + 1] = part
    end

    if #parts ~= 5 then
        error(("cron expression requires 5 fields, received %s"):format(#parts), 2)
    end

    return matchField(parts[1], date.min, 0, 59)
       and matchField(parts[2], date.hour, 0, 23)
       and matchField(parts[3], date.day, 1, 31)
       and matchField(parts[4], date.month, 1, 12, monthNames)
       and matchField(parts[5], date.wday, 1, 7, dayNames)
end

--#endregion

--#region CronTask Implementation

---@param pattern string
---@param callback fun(task: CronTask, date: osdate)
---@param options? table
function CronTask:constructor(pattern, callback, options)
    assert(type(pattern) == "string", "pattern must be a string")
    assert(type(callback) == "function", "callback must be a function")

    self.pattern = pattern
    self.active  = true

    local lastMinute = -1

    Citizen.CreateThread(function()
        while self.active do
            local currentDate = os.date("*t") --[[@as osdate]]

            if currentDate.min ~= lastMinute then
                if cron.matches(self.pattern, currentDate) then
                    lastMinute = currentDate.min

                    Citizen.CreateThreadNow(function()
                        callback(self, currentDate)
                    end)
                end
            end

            Wait(1000)
        end
    end)
end

---Ferma l'esecuzione dell'attività cron schedulata.
---@return CronTask
function CronTask:stop()
    self.active = false
    return self
end

---Controlla se l'attività è ancora attiva.
---@return boolean
function CronTask:isActive()
    return self.active
end

--#endregion

--#region Scheduling

---Crea una nuova pianificazione cron periodica.
---@param expression string  espressione a 5 campi (es. "0 12 * * *")
---@param callback fun(task: CronTask, date: osdate)
---@param options? table
---@return CronTask
function cron.new(expression, callback, options)
    return CronTask.new(expression, callback, options)
end

---Pianifica un'attività da eseguire ogni X secondi.
---@param seconds integer
---@param callback fun(task: CronTask)
---@return CronTask
function cron.every(seconds, callback)
    assert(type(seconds) == "number" and seconds > 0, "seconds must be positive")

    local task = setmetatable({ active = true }, CronTask) --[[@as CronTask]]

    Citizen.CreateThread(function()
        local ms = seconds * 1000

        while task.active do
            Wait(ms)

            if task.active then
                callback(task)
            end
        end
    end)

    return task
end

--#endregion

