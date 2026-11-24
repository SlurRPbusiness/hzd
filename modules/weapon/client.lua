---@meta

--#region Native Upvalue Optimization

local GiveWeaponToPed <const>        = GiveWeaponToPed
local RemoveWeaponFromPed <const>    = RemoveWeaponFromPed
local RemoveAllPedWeapons <const>    = RemoveAllPedWeapons
local SetCurrentPedWeapon <const>    = SetCurrentPedWeapon
local GetCurrentPedWeapon <const>    = GetCurrentPedWeapon
local HasPedGotWeapon <const>        = HasPedGotWeapon
local GetAmmoInPedWeapon <const>     = GetAmmoInPedWeapon
local SetPedAmmo <const>             = SetPedAmmo
local AddAmmoToPed <const>           = AddAmmoToPed
local SetPedInfiniteAmmo <const>     = SetPedInfiniteAmmo
local SetPedInfiniteAmmoClip <const> = SetPedInfiniteAmmoClip
local SetPedCanSwitchWeapon <const>  = SetPedCanSwitchWeapon
local DisablePlayerFiring <const>    = DisablePlayerFiring
local PlayerPedId <const>            = PlayerPedId
local PlayerId <const>               = PlayerId

--#endregion

---@class Weapon
---@field give fun(ped: integer, hash: integer, ammo?: integer, equipNow?: boolean, ammoLoaded?: integer)
---@field remove fun(ped: integer, hash: integer)
---@field removeAll fun(ped: integer, deselect?: boolean)
---@field has fun(ped: integer, hash: integer): boolean
---@field getAmmo fun(ped: integer, hash: integer): integer
---@field setAmmo fun(ped: integer, hash: integer, ammo: integer)
---@field addAmmo fun(ped: integer, hash: integer, amount: integer)
---@field equip fun(ped: integer, hash: integer)
---@field getCurrent fun(ped: integer): integer
---@field giveLoadout fun(ped: integer, loadout: WeaponDef[], equipFirst?: boolean)
---@field setInfinite fun(ped: integer, toggle: boolean)
---@field setInfiniteClip fun(ped: integer, toggle: boolean)
---@field setCanSwitch fun(ped: integer, toggle: boolean)
---@field disableFiring fun(toggle: boolean)

weapon                               = weapon or {}

--#region Instance Methods

---Dà un'arma al ped con ammo specificata.
---@param ped integer
---@param hash integer
---@param ammo? integer (default 9999)
---@param equipNow? boolean
---@param ammoLoaded? integer Colpi nel caricatore
function weapon.give(ped, hash, ammo, equipNow, ammoLoaded)
    GiveWeaponToPed(ped, hash, ammo or 9999, equipNow == true, ammoLoaded or false)
end

---Rimuove un'arma specifica dal ped.
---@param ped integer
---@param hash integer
function weapon.remove(ped, hash)
    RemoveWeaponFromPed(ped, hash)
end

---Rimuove tutte le armi dal ped.
---@param ped integer
---@param deselect? boolean (default true)
function weapon.removeAll(ped, deselect)
    RemoveAllPedWeapons(ped, deselect ~= false)
end

---Verifica se il ped possiede un'arma.
---@param ped integer
---@param hash integer
---@return boolean
function weapon.has(ped, hash)
    return HasPedGotWeapon(ped, hash, false)
end

---Restituisce le munizioni disponibili per un'arma.
---@param ped integer
---@param hash integer
---@return integer
function weapon.getAmmo(ped, hash)
    return GetAmmoInPedWeapon(ped, hash)
end

---Imposta le munizioni per un'arma al ped.
---@param ped integer
---@param hash integer
---@param ammo integer
function weapon.setAmmo(ped, hash, ammo)
    SetPedAmmo(ped, hash, ammo)
end

---Aggiunge munizioni a un'arma che il ped già possiede.
---@param ped integer
---@param hash integer
---@param amount integer
function weapon.addAmmo(ped, hash, amount)
    AddAmmoToPed(ped, hash, amount)
end

---Equipaggia immediatamente l'arma specificata.
---@param ped integer
---@param hash integer
function weapon.equip(ped, hash)
    SetCurrentPedWeapon(ped, hash, true)
end

---Restituisce l'hash dell'arma attualmente equipaggiata.
---@param ped integer
---@return integer hash
function weapon.getCurrent(ped)
    local _, hash = GetCurrentPedWeapon(ped, true)
    return hash
end

---Abilita o disabilita le munizioni infinite (non sparano mai a secco).
---@param ped integer
---@param toggle boolean
function weapon.setInfinite(ped, toggle)
    SetPedInfiniteAmmo(ped, toggle == true, 0)
end

---Abilita o disabilita il caricatore infinito (nessuna ricarica).
---@param ped integer
---@param toggle boolean
function weapon.setInfiniteClip(ped, toggle)
    SetPedInfiniteAmmoClip(ped, toggle == true)
end

---Abilita o disabilita la possibilità di cambiare arma.
---@param ped integer
---@param toggle boolean
function weapon.setCanSwitch(ped, toggle)
    SetPedCanSwitchWeapon(ped, toggle == true)
end

---Abilita o disabilita lo sparo per il giocatore locale.
---@param toggle boolean
function weapon.disableFiring(toggle)
    DisablePlayerFiring(PlayerId(), toggle == true)
end

--#endregion

--#region Loadout System

---Dà un loadout completo al ped (lista di WeaponDef).
---@param ped integer
---@param loadout WeaponDef[]
---@param equipFirst? boolean Se true equipaggia la prima arma del loadout
function weapon.giveLoadout(ped, loadout, equipFirst)
    if not loadout then return end

    for i = 1, #loadout do
        local def = loadout[i]
        if def and def.hash then
            GiveWeaponToPed(ped, def.hash, def.ammo or 9999, false, false)

            -- Componenti arma (silenziatori, ottica, ecc.)
            if def.component then
                for j = 1, #def.component do
                    -- GiveWeaponComponentToPed(ped, def.hash, def.component[j])
                end
            end
        end
    end

    if equipFirst and loadout[1] and loadout[1].hash then
        SetCurrentPedWeapon(ped, loadout[1].hash, true)
    end
end

---Rimuove tutte le armi e assegna il loadout specificato (reset + give).
---@param ped integer
---@param loadout WeaponDef[]
---@param equipFirst? boolean
function weapon.resetToLoadout(ped, loadout, equipFirst)
    RemoveAllPedWeapons(ped, true)
    weapon.giveLoadout(ped, loadout, equipFirst)
end

--#endregion

---Shortcut: dà il loadout al giocatore locale.
---@param loadout WeaponDef[]
---@param equipFirst? boolean
function weapon.giveLocal(loadout, equipFirst)
    weapon.giveLoadout(PlayerPedId(), loadout, equipFirst)
end

---Shortcut: rimuove tutte le armi al giocatore locale.
function weapon.removeLocal()
    RemoveAllPedWeapons(PlayerPedId(), true)
end
