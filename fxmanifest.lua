fx_version 'cerulean'
game 'gta5'
lua54 'yes'

author 'Crazy Eyes Studio'
description 'Advanced AI Medic Script - QBCore & Standalone Compatible'
version '1.5.0'

shared_script 'config.lua'

client_scripts {
    'client/utils_client.lua',
    'client/main.lua'
}

server_scripts {
    'server/rate_limiter.lua',
    'server/main.lua',
    'server/utils_server.lua'
}
