fx_version 'cerulean'
game 'gta5'
lua54 'yes'

name 'vs_radio'
author 'VS Scripts'
version '1.0.0'
description 'Handheld radio for pma-voice. Standalone or QBCore, Qbox, ESX'

shared_script 'config.lua'

client_scripts {
    'client/voice.lua',
    'client/main.lua',
}

server_scripts {
    'server/bridge.lua',
    'server/inventory.lua',
    'server/main.lua',
}

ui_page 'web/index.html'

files {
    'web/index.html',
    'web/style.css',
    'web/app.js',
    'web/sounds/*',
}

dependency 'pma-voice'
