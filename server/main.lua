local jobCache = {}
local onRadio = {}

local function toChannel(value)
    local n = tonumber(value)
    if not n or n ~= n then return nil end
    n = math.floor(n)
    if n < Config.MinChannel or n > Config.MaxChannel then return nil end
    return n
end

local function cachedJob(src)
    local hit = jobCache[src]
    local now = GetGameTimer()
    if hit and now - hit.at < Config.JobCacheMs then return hit.job end
    local job = Bridge.jobOf(src)
    jobCache[src] = { job = job, at = now }
    return job
end

local function canJoin(src, value)
    if not Inventory.hasRadio(src) then return false, _L('need_radio') end

    local channel = toChannel(value)
    if not channel then return false, _L('invalid_channel') end

    local rule = Config.Channels[channel]
    local hasJobs = rule and rule.jobs and #rule.jobs > 0
    if not rule or (not hasJobs and not rule.ace) then
        return true, nil, channel
    end

    if rule.ace and IsPlayerAceAllowed(src, rule.ace) then
        return true, nil, channel
    end

    if hasJobs then
        local job = cachedJob(src)
        for i = 1, #rule.jobs do
            if rule.jobs[i] == job then return true, nil, channel end
        end
    end

    return false, _L('restricted', channel)
end

RegisterNetEvent('vs_radio:server:join', function(value, token)
    local src = source
    local ok, reason, channel = canJoin(src, value)
    if ok then
        onRadio[src] = true
        List.set(src, channel)
    end
    TriggerClientEvent('vs_radio:client:joinResult', src, token, ok, ok and channel or reason)
end)

RegisterNetEvent('vs_radio:server:left', function()
    onRadio[source] = nil
    List.remove(source)
end)

AddEventHandler('playerDropped', function()
    jobCache[source] = nil
    onRadio[source] = nil
end)

CreateThread(function()
    if not Config.RequireItem then return end
    while true do
        Wait(Config.ItemCheckMs)
        for src in pairs(onRadio) do
            if not GetPlayerName(src) then
                onRadio[src] = nil
            elseif not Inventory.hasRadio(src) then
                onRadio[src] = nil
                List.remove(src)
                TriggerClientEvent('vs_radio:client:forceOff', src)
            end
        end
    end
end)
