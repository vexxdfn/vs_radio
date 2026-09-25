Inventory = { name = 'framework' }

local function started(name)
    return GetResourceState(name) == 'started'
end

-- ox and qs have their own item count exports. Every other supported
-- inventory keeps the framework's item functions up to date, so it uses those.
local OWN_EXPORTS = { ox = true, qs = true }

CreateThread(function()
    if Config.Inventory ~= 'auto' then
        Inventory.name = OWN_EXPORTS[Config.Inventory] and Config.Inventory or 'framework'
    else
        for _ = 1, 20 do
            if started('ox_inventory') then Inventory.name = 'ox' break end
            if started('qs-inventory') then Inventory.name = 'qs' break end
            Wait(500)
        end
    end

    while not Bridge.ready do Wait(250) end
    if Config.RequireItem and Bridge.name == 'none' and Inventory.name == 'framework'
        and type(Config.CustomItemCount) ~= 'function' then
        print('^1[vs_radio]^7 Running standalone with Config.RequireItem on, but no inventory can be checked. Set Config.RequireItem = false or use ox_inventory.')
    end
end)

local function frameworkCount(src)
    local ply = Bridge.getPlayer(src)
    if not ply then return 0 end
    if Bridge.name == 'esx' then
        local item = ply.getInventoryItem(Config.ItemName)
        return item and item.count or 0
    end
    local item = ply.Functions.GetItemByName(Config.ItemName)
    return item and (item.amount or item.count) or 0
end

function Inventory.count(src)
    local ok, count = pcall(function()
        if type(Config.CustomItemCount) == 'function' then
            return Config.CustomItemCount(src, Config.ItemName)
        end
        if Inventory.name == 'ox' then
            return exports.ox_inventory:Search(src, 'count', Config.ItemName)
        end
        if Inventory.name == 'qs' then
            return exports['qs-inventory']:GetItemTotalAmount(src, Config.ItemName)
        end
        return frameworkCount(src)
    end)
    return ok and tonumber(count) or 0
end

function Inventory.hasRadio(src)
    if not Config.RequireItem then return true end
    return Inventory.count(src) > 0
end

local function toggle(src)
    TriggerClientEvent('vs_radio:client:toggleRadio', src)
end

-- Used by the command/keybind, and as a manual hook for inventories that
-- don't route item use through the framework.
RegisterNetEvent('vs_radio:server:itemUsed', function()
    local src = source
    if Inventory.hasRadio(src) then
        toggle(src)
    else
        TriggerClientEvent('vs_radio:client:notify', src, 'You don\'t have a radio.')
    end
end)

CreateThread(function()
    while not Bridge.ready do Wait(250) end

    if Bridge.name == 'qbx' then
        exports.qbx_core:CreateUseableItem(Config.ItemName, toggle)
    elseif Bridge.name == 'qb' then
        Bridge.core.Functions.CreateUseableItem(Config.ItemName, toggle)
    elseif Bridge.name == 'esx' then
        Bridge.core.RegisterUsableItem(Config.ItemName, toggle)
    end
end)
