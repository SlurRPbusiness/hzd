---@meta

---@diagnostic disable: undefined-global
local IsGameEnhancedVersion <const> = IsGameEnhancedVersion

---@class Enhanced
enhanced = {}

--#region Constructor

---@return boolean
function enhanced:get()
    local isEnhanced

    local GAME_NAMES = {
        ["gta5enhanced"] = true,
        ["gta5_enhanced"] = true
    }

    if not hzd:is("client") then
        isEnhanced = GAME_NAMES[GetConvar("gamename", "gta5")] == true
    else
        isEnhanced = IsGameEnhancedVersion() == true
    end

    return isEnhanced
end

--#endregion
