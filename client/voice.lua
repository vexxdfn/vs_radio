Voice = { available = false, volume = Config.DefaultVolume }

local appliedVolume = nil
local clicksReplaced = false

CreateThread(function()
    for _ = 1, 20 do
        if GetResourceState('pma-voice') == 'started' then
            Voice.available = true
            break
        end
        Wait(500)
    end

    if not Voice.available then
        print('^1[vs_radio]^7 pma-voice is not running.')
        return
    end

    if Config.UI.radioSounds then
        clicksReplaced = pcall(function()
            exports['pma-voice']:setVoiceProperty('micClicks', false)
        end)
    end
end)

function Voice.join(channel)
    if not Voice.available then return false end
    return pcall(function() exports['pma-voice']:setRadioChannel(channel) end)
end

function Voice.leave()
    return Voice.join(0)
end

function Voice.setVolume(volume)
    Voice.volume = volume
    if not Voice.available or volume == appliedVolume then return false end
    local ok = pcall(function() exports['pma-voice']:setRadioVolume(volume) end)
    if ok then appliedVolume = volume end
    return ok
end

AddEventHandler('pma-voice:radioActive', function(talking)
    SendNUIMessage({
        action = 'tx',
        value = talking == true,
        sfx = Config.UI.radioSounds,
        vol = Voice.volume,
    })
end)

local talkers, talkerCount, rxLit = {}, 0, false

local function pushRx()
    local lit = talkerCount > 0
    if lit ~= rxLit then
        rxLit = lit
        SendNUIMessage({ action = 'rx', value = lit })
    end
end

RegisterNetEvent('pma-voice:setTalkingOnRadio', function(src, talking)
    if talking then
        if not talkers[src] then
            talkers[src] = true
            talkerCount = talkerCount + 1
        end
    elseif talkers[src] then
        talkers[src] = nil
        talkerCount = talkerCount - 1
    end
    pushRx()
end)

function Voice.resetRx()
    talkers, talkerCount = {}, 0
    pushRx()
end

AddEventHandler('onResourceStop', function(resource)
    if resource ~= GetCurrentResourceName() or not clicksReplaced then return end
    pcall(function() exports['pma-voice']:setVoiceProperty('micClicks', true) end)
end)
