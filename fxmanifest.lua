fx_version 'cerulean'
game 'gta5'

description 'Waypoint Traffic Lights'
author 'Original author: Smallo - xnTrafficLights, Modified by: BackSH00TER - Waypoint Scripts'
version '1.0.0'

shared_script {
    -- '@ox_lib/init.lua', -- Uncomment this if you are planning to use any ox scripts
    'shared/config.lua',
    'shared/framework.lua',
}

client_scripts {
    '@menuv/menuv.lua',
    'client/*.lua',
}

server_scripts {
    'server/server.lua',
}

lua54 'yes'