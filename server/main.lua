RegisterCommand('callmedic', function(source)
    print('[AI Medic] callmedic command triggered by source: ' .. source)
    local onlineEMS = 0
    if Utils.QBCore then
        for _, id in pairs(Utils.QBCore.Functions.GetPlayers()) do
            local ply = Utils.QBCore.Functions.GetPlayer(id)
            if ply and ply.PlayerData.job.name == "ambulance" then
                onlineEMS = onlineEMS + 1
            end
        end
        print('[AI Medic] Online EMS count: ' .. onlineEMS)
    end

    if onlineEMS > Config.MaxEMSOnline then
        Utils.Notify(source, "EMS are available, please call them instead.", "error")
        return
    end

    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    if not coords then
        print('[AI Medic] Failed to get coords for source: ' .. source)
        Utils.Notify(source, "Error: Could not get your location.", "error")
        return
    end
    print('[AI Medic] Triggering revivePlayer for source: ' .. source .. ' at coords: ' .. tostring(coords))
    TriggerClientEvent('custom_aimedic:revivePlayer', source, coords)
end, false)

RegisterNetEvent('custom_aimedic:chargePlayer')
AddEventHandler('custom_aimedic:chargePlayer', function(target)
    local src = target or source
    print('[AI Medic] Charging player: ' .. src)
    local Player = Utils.GetPlayerFramework(src)
    if Player then
        if Utils.RemoveMoney(Player, Config.Fee) then
            Utils.Notify(src, "You were charged $" .. Config.Fee .. " for EMS service.", "success")
        else
            Utils.Notify(src, "You don't have enough money to pay for EMS!", "error")
        end
    else
        print('[AI Medic] No player framework for source: ' .. src)
        Utils.Notify(src, "EMS fee skipped due to server error.", "error")
    end
end)

-- Custom revive event for standalone mode
RegisterNetEvent('custom_aimedic:revivePlayer')
AddEventHandler('custom_aimedic:revivePlayer', function(target)
    print('[AI Medic] Revive requested for target: ' .. target)
    if Utils.QBCore then
        -- Use QBCore's revive event (adjust based on your QBCore version)
        TriggerClientEvent('hospital:client:Revive', target) -- Common QBCore revive event
    else
        -- Standalone revive logic
        TriggerClientEvent('custom_aimedic:standaloneRevive', target)
    end
end)