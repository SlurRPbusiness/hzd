---@diagnostic disable

fx_version "cerulean"
game "gta5"
lua54 "yes"

author "lowsime"
description "Project hzd PvP"
version "1.0"

dependencies {
    "oxmysql",
    "/onesync",
}

ui_page "web/dist/index.html"

files {
    "locales/**/*.json",
    "web/dist/**/*",
    "source/**/shared/**/*.json",
    "modules/sql/schema.sql",
}

shared_scripts {
    "lua/type.lua",
    "lua/class.lua",
    "init.lua",
    "lua/table.lua",
    "lua/string.lua",
    "lua/math.lua",
    "lua/color.lua",
    "lua/print.lua",
    "lua/await.lua",
    "lua/cache.lua",
    "lua/cron.lua",
    "modules/**/shared.lua",
    "source/**/shared/**/*.lua",
}

client_scripts {
    "modules/**/client.lua",
    "source/**/client/**/*.lua",
}

server_scripts {
    "modules/**/server.lua",
    "source/**/server/**/*.lua",
}
