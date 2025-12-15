Utils = {}
Utils.QBCore = nil

CreateThread(function()
    if GetResourceState('qb-core') == 'started' then
        Utils.QBCore = exports['qb-core']:GetCoreObject()
        print('[AI Medic] QBCore detected and initialized')
    else
        print('[AI Medic] QBCore not found, running in standalone mode')
    end
end)

function Utils.GetPlayerFramework(source)
    if Utils.QBCore then
        local player = Utils.QBCore.Functions.GetPlayer(source)
        if player then
            print('[AI Medic] Player framework retrieved for source: ' .. source)
            return player
        else
            print('[AI Medic] Failed to get player framework for source: ' .. source)
        end
    end
    return nil
end

function Utils.Notify(src, msg, type)
    print('[AI Medic] Notify sent to ' .. src .. ': ' .. msg)
    if Utils.QBCore then
        TriggerClientEvent('QBCore:Notify', src, msg, type or 'primary')
    else
        TriggerClientEvent('chat:addMessage', src, {
            color = {255, 0, 0},
            multiline = true,
            args = {"EMS", msg}
        })
    end
end

function Utils.RemoveMoney(player, amount)
    if Utils.QBCore and player then
        local success = player.Functions.RemoveMoney('bank', amount)
        print('[AI Medic] Money removal attempt for ' .. player.PlayerData.source .. ': $' .. amount .. ' - Success: ' .. tostring(success))
        return success
    end
    print('[AI Medic] Money removal skipped (standalone mode)')
    Utils.Notify(player.PlayerData.source, 'EMS fee skipped in standalone mode', 'error')
    return false
end