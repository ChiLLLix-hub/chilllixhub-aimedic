Utils = {}
Utils.QBCore = nil

CreateThread(function()
    if GetResourceState('qb-core') == 'started' then
        Utils.QBCore = exports['qb-core']:GetCoreObject()
        print('[AI Medic Client] QBCore detected and initialized')
    else
        print('[AI Medic Client] QBCore not found, running in standalone mode')
    end
end)

function Utils.NotifyClient(msg, type)
    print('[AI Medic Client] Notify: ' .. msg)
    if Utils.QBCore then
        TriggerEvent('QBCore:Notify', msg, type or 'primary')
    else
        TriggerEvent('chat:addMessage', {
            color = {255, 0, 0},
            multiline = true,
            args = {"EMS", msg}
        })
    end
end