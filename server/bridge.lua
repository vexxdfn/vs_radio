Bridge = { name = 'none', core = nil, ready = false }

local function started(name)
    local s = GetResourceState(name)
    return s == 'started' or s == 'starting'
end

local function detect()
    if Config.Framework ~= 'auto' then return Config.Framework end
    if started('qbx_core') then return 'qbx' end
    if started('qb-core') then return 'qb' end
    if started('es_extended') then return 'esx' end
    return 'none'
end

CreateThread(function()
    if Config.Framework ~= 'none' then
        for _ = 1, 20 do
            Bridge.name = detect()
            if Bridge.name ~= 'none' then break end
            Wait(500)
        end
    end

    if Bridge.name == 'qbx' then
        Bridge.core = exports.qbx_core
    elseif Bridge.name == 'qb' then
        Bridge.core = exports['qb-core']:GetCoreObject()
    elseif Bridge.name == 'esx' then
        Bridge.core = exports['es_extended']:getSharedObject()
    else
        Bridge.name = 'none'
        print('^3[vs_radio]^7 No framework found, running standalone.')
    end

    Bridge.ready = true
end)

function Bridge.getPlayer(src)
    if not Bridge.ready or Bridge.name == 'none' then return nil end
    if Bridge.name == 'qbx' then return Bridge.core:GetPlayer(src) end
    if Bridge.name == 'qb' then return Bridge.core.Functions.GetPlayer(src) end
    if Bridge.name == 'esx' then return Bridge.core.GetPlayerFromId(src) end
end

function Bridge.jobOf(src)
    local ply = Bridge.getPlayer(src)
    if not ply then return nil end
    if Bridge.name == 'esx' then
        local job = ply.job or (ply.getJob and ply.getJob())
        return job and job.name
    end
    local job = ply.PlayerData.job
    return job and job.name
end

function Bridge.nameOf(src)
    local ply = Bridge.getPlayer(src)
    if ply then
        if Bridge.name == 'esx' then
            local name = ply.getName and ply.getName()
            if name and name ~= '' then return name end
        else
            local ci = ply.PlayerData and ply.PlayerData.charinfo
            if ci then
                local name = ((ci.firstname or '') .. ' ' .. (ci.lastname or '')):gsub('^%s+', ''):gsub('%s+$', '')
                if name ~= '' then return name end
            end
        end
    end
    return GetPlayerName(src) or _L('player_fallback', src)
end

function Bridge.idOf(src)
    local ply = Bridge.getPlayer(src)
    if ply then
        if Bridge.name == 'esx' then return ply.identifier end
        return ply.PlayerData and ply.PlayerData.citizenid
    end
    return GetPlayerIdentifierByType(src, 'license')
end
