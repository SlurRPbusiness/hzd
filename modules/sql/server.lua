---@meta

---@class sqllib
---@field isReady fun(): boolean
---@field query fun(query: string, params?: table): table
---@field single fun(query: string, params?: table): table?
---@field scalar fun(query: string, params?: table): any
---@field insert fun(query: string, params?: table): integer?
---@field update fun(query: string, params?: table): integer
---@field transaction fun(queries: table, params?: table): boolean

local sql = {}
_ENV.sql = sql

local isDatabaseReady = false
local oxmysql = exports.oxmysql

local function execute(method, query, params)
    assert(params == nil or type(params) == "table", "SQL parameters must be a table")

    if method == "transaction_async" then
        assert(type(query) == "table" and #query > 0, "transaction requires at least one query")
    else
        assertType("query", query, "string")
        assert(query ~= "", "query cannot be empty")
    end

    local operation = oxmysql[method]
    assert(type(operation) == "function", ("oxmysql export '%s' is unavailable"):format(method))
    return operation(oxmysql, query, params or {})
end

function sql.isReady()
    return isDatabaseReady
end

function sql.query(query, params)
    return execute("query_async", query, params)
end

function sql.single(query, params)
    return execute("single_async", query, params)
end

function sql.scalar(query, params)
    return execute("scalar_async", query, params)
end

function sql.insert(query, params)
    return execute("insert_async", query, params)
end

function sql.update(query, params)
    return execute("update_async", query, params)
end

function sql.transaction(queries, params)
    return execute("transaction_async", queries, params)
end

local schema = assert(
    LoadResourceFile(hzd.name, "modules/sql/schema.sql"),
    "SQL schema file modules/sql/schema.sql is missing from this resource"
)

local function initializeSchema()
    sql.query(schema)

    local columns = sql.query("SHOW COLUMNS FROM `hzd_users`;")
    assert(type(columns) == "table", "unable to inspect hzd_users schema")

    local existing = {}
    for i = 1, #columns do
        existing[columns[i].Field] = true
    end

    -- Upgrade tables created by earlier versions without interrupting deployment.
    local migrations = {
        { name = "skin", definition = "LONGTEXT NULL" },
        { name = "xp", definition = "INT UNSIGNED NOT NULL DEFAULT 0" },
        { name = "level", definition = "INT UNSIGNED NOT NULL DEFAULT 1" },
    }

    for i = 1, #migrations do
        local migration = migrations[i]
        if not existing[migration.name] then
            sql.query(("ALTER TABLE `hzd_users` ADD COLUMN `%s` %s;"):format(migration.name, migration.definition))
            existing[migration.name] = true
        end
    end

    local requiredColumns = {
        "identifier", "name", "kills", "deaths", "headshots", "matches_played", "matches_won",
        "elo", "coins", "xp", "level", "settings", "skin",
    }
    for i = 1, #requiredColumns do
        assert(existing[requiredColumns[i]], ("hzd_users is missing required column '%s'"):format(requiredColumns[i]))
    end
end

Citizen.CreateThread(function()
    while true do
        local success, err = pcall(initializeSchema)

        if success then
            isDatabaseReady = true
            print.info("[SQL] Schema hzd_users pronto.")
            TriggerEvent("hzd:databaseReady")
            return
        end

        print.error("[SQL] Inizializzazione fallita: %s. Nuovo tentativo tra 5 secondi.", tostring(err))
        Wait(5000)
    end
end)
