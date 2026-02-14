local isBeingRevived = false
local MEDBAG_MODEL = "prop_med_bag_01"

-- Spawn location constants
local MEDIC_SPAWN_DISTANCE = 2.0 -- Distance offset from player for medic spawn
local GROUND_SEARCH_HEIGHT = 100.0 -- Height offset for ground detection
local GROUND_OFFSET = 0.5 -- Vertical offset above ground level for spawn

RegisterNetEvent('custom_aimedic:revivePlayer')
AddEventHandler('custom_aimedic:revivePlayer', function(playerCoords, patients, medicId)
    if isBeingRevived then return end
    isBeingRevived = true

    local playerPed = PlayerPedId()
    local isDowned = false

    if Utils.QBCore then
        local QBCore = Utils.QBCore
        local Player = QBCore.Functions.GetPlayerData()
        if Player and (Player.metadata['isdead'] or Player.metadata['inlaststand']) then
            isDowned = true
        end
    else
        if IsEntityDead(playerPed) then
            isDowned = true
        end
    end

    if not isDowned then
        Utils.NotifyClient('You are not injured enough to call EMS.', 'error')
        isBeingRevived = false
        return
    end

    -- Store medicId for cleanup (optional parameter)
    local currentMedicId = medicId or "medic_unknown"

    local cause = GetPedCauseOfDeath(playerPed)
    local causeText = WeaponToName(cause)
    local displayCause = "Died from: " .. causeText

    RequestModel(Config.MedicModel)
    RequestModel(GetHashKey(MEDBAG_MODEL))
    while not HasModelLoaded(Config.MedicModel) or not HasModelLoaded(GetHashKey(MEDBAG_MODEL)) do
        Wait(10)
    end

    local playerPos = GetEntityCoords(playerPed)
    
    print('[AI Medic Client] Spawning medic directly at player location')
    
    -- Spawn medic directly at player location (no vehicle)
    local spawnPos = GetOffsetFromEntityInWorldCoords(playerPed, MEDIC_SPAWN_DISTANCE, 0.0, 0.0)
    
    -- Ensure spawn position has valid ground Z
    local groundFound, groundZ = GetGroundZFor_3dCoord(spawnPos.x, spawnPos.y, spawnPos.z + GROUND_SEARCH_HEIGHT, 0)
    if groundFound then
        spawnPos = vector3(spawnPos.x, spawnPos.y, groundZ + GROUND_OFFSET)
        print('[AI Medic Client] Adjusted spawn position to ground level: Z=' .. groundZ)
    end
    
    -- Create medic ped directly at location (not in vehicle)
    local medic = CreatePed(4, Config.MedicModel, spawnPos.x, spawnPos.y, spawnPos.z, 0.0, true, false)
    SetEntityAsMissionEntity(medic, true, true)
    SetBlockingOfNonTemporaryEvents(medic, true)

    local blip = AddBlipForEntity(medic)
    SetBlipSprite(blip, 280)
    SetBlipScale(blip, 0.9)
    SetBlipColour(blip, 1)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("AI Medic")
    EndTextCommandSetBlipName(blip)

    Utils.NotifyClient('AI Medic has arrived!', 'primary')

    -- Medic walks to player
    -- Task flags: 786603 = default walking behavior (move to coords, avoid obstacles, use navmesh)
    TaskGoToCoordAnyMeans(medic, playerPos.x, playerPos.y, playerPos.z, 2.0, 0, 0, 786603, 0)
    local walkTimeout = GetGameTimer() + 10000
    while #(GetEntityCoords(medic) - playerPos) > 2.0 and GetGameTimer() < walkTimeout do Wait(500) end

    local bag = CreateObject(GetHashKey(MEDBAG_MODEL), playerPos.x + 0.3, playerPos.y, playerPos.z - 1.0, true, true, true)
    SetEntityHeading(bag, GetEntityHeading(medic))

    RequestAnimDict("amb@medic@standing@tendtodead@idle_a")
    while not HasAnimDictLoaded("amb@medic@standing@tendtodead@idle_a") do Wait(10) end
    TaskPlayAnim(medic, "amb@medic@standing@tendtodead@idle_a", "idle_a", 8.0, -8.0, Config.ReviveDelay, 1, 0, false, false, false)

    -- Draw progress bar + floating text
    local start = GetGameTimer()
    local duration = Config.ReviveDelay

    CreateThread(function()
        while GetGameTimer() - start < duration do
            -- Progress bar
            local elapsed = GetGameTimer() - start
            local percent = elapsed / duration
            DrawRect(0.5, 0.9, 0.15, 0.02, 0, 0, 0, 180)
            DrawRect(0.5 - 0.075 + percent * 0.15 / 2, 0.9, percent * 0.15, 0.02, 0, 200, 0, 255)

            -- 3D text above medic
            local coords = GetEntityCoords(medic)
            DrawText3D(coords.x, coords.y, coords.z + 1.1, displayCause)
            Wait(0)
        end
    end)

    Wait(duration)
    
    -- Charge player and check if they have enough money
    TriggerServerEvent('custom_aimedic:chargePlayer')
    TriggerServerEvent('custom_aimedic:revivePlayer', GetPlayerServerId(PlayerId()))

    Wait(1000)
    
    -- Fade screen to black
    DoScreenFadeOut(1000)
    Wait(1000)
    
    -- Cleanup medic while screen is black
    DeleteEntity(bag)
    DeleteEntity(medic)
    if DoesBlipExist(blip) then RemoveBlip(blip) end
    
    -- Cleanup models from memory
    SetModelAsNoLongerNeeded(Config.MedicModel)
    SetModelAsNoLongerNeeded(GetHashKey(MEDBAG_MODEL))
    
    -- Revive player if still dead (fallback)
    if IsEntityDead(playerPed) then
        local coords = GetEntityCoords(playerPed)
        NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(playerPed), true, false)
        ClearPedTasksImmediately(playerPed)
    end
    
    -- Request an available hospital bed from server
    TriggerServerEvent('custom_aimedic:requestBed')
end

-- Receive bed assignment from server
RegisterNetEvent('custom_aimedic:assignBed')
AddEventHandler('custom_aimedic:assignBed', function(bedIndex, bedData)
    local playerPed = PlayerPedId()
    
    print('[AI Medic Client] Assigned to bed ' .. bedIndex)
    
    -- Teleport player to hospital bed
    SetEntityCoords(playerPed, bedData.coords.x, bedData.coords.y, bedData.coords.z, false, false, false, true)
    SetEntityHeading(playerPed, bedData.heading)
    
    -- Set player to lay on bed
    RequestAnimDict("anim@gangops@morgue@table@")
    while not HasAnimDictLoaded("anim@gangops@morgue@table@") do Wait(10) end
    TaskPlayAnim(playerPed, "anim@gangops@morgue@table@", "body_search", 8.0, -8.0, -1, 1, 0, false, false, false)
    
    -- Give full health
    SetEntityHealth(playerPed, GetEntityMaxHealth(playerPed))
    
    Wait(1000)
    
    -- Fade screen back in
    DoScreenFadeIn(1000)
    Wait(1000)
    
    -- Show press E to get up message
    local canGetUp = false
    CreateThread(function()
        Wait(3000) -- Wait 3 seconds before allowing player to get up
        canGetUp = true
    end)
    
    -- Wait for player to press E to get up
    while true do
        Wait(0)
        if canGetUp then
            DrawText3D(bedData.coords.x, bedData.coords.y, bedData.coords.z + 1.0, "Press ~g~[E]~w~ to get up")
            if IsControlJustPressed(0, 38) then -- E key
                break
            end
        else
            DrawText3D(bedData.coords.x, bedData.coords.y, bedData.coords.z + 1.0, "Recovering...")
        end
    end
    
    -- Get up from bed
    ClearPedTasks(playerPed)
    Wait(100)
    
    -- Play get up animation
    RequestAnimDict("get_up@directional@transition@prone_to_seated@crawl")
    if HasAnimDictLoaded("get_up@directional@transition@prone_to_seated@crawl") then
        TaskPlayAnim(playerPed, "get_up@directional@transition@prone_to_seated@crawl", "front", 8.0, -8.0, 1000, 0, 0, false, false, false)
    end
    
    Wait(1000)
    Utils.NotifyClient('You have been treated and released from the hospital.', 'success')
    
    -- Release the bed on the server
    TriggerServerEvent('custom_aimedic:releaseBed')
    
    isBeingRevived = false
    TriggerServerEvent('custom_aimedic:reviveComplete', currentMedicId)
end)

RegisterNetEvent('custom_aimedic:standaloneRevive')
AddEventHandler('custom_aimedic:standaloneRevive', function()
    local playerPed = PlayerPedId()
    local coords = GetEntityCoords(playerPed)
    NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(playerPed), true, false)
    SetEntityHealth(playerPed, GetEntityMaxHealth(playerPed))
    ClearPedTasks(playerPed)
    Utils.NotifyClient('You have been revived by AI EMS.', 'success')
end)

function DrawText3D(x, y, z, text)
    local onScreen, _x, _y = World3dToScreen2d(x, y, z)
    if not onScreen then return end
    SetTextScale(0.35, 0.35)
    SetTextFont(4)
    SetTextProportional(1)
    SetTextColour(255, 255, 255, 215)
    SetTextCentre(true)
    SetTextEntry("STRING")
    AddTextComponentString(text)
    DrawText(_x, _y)
end

function WeaponToName(hash)
    for name, value in pairs(_G) do
        if type(value) == 'number' and value == hash and name:match("^WEAPON_") then
            return name:gsub("WEAPON_", ""):gsub("_", " "):lower()
        end
    end
    return "unknown"
end

-- Show /callmedic command suggestion when player spawns
AddEventHandler('playerSpawned', function()
    Wait(2000) -- Wait 2 seconds after spawn
    TriggerEvent('chat:addSuggestion', '/callmedic', 'Call an AI medic to revive you when downed', {})
end)

-- Also show on resource start for players already connected
Citizen.CreateThread(function()
    Wait(5000) -- Wait 5 seconds after resource start
    TriggerEvent('chat:addSuggestion', '/callmedic', 'Call an AI medic to revive you when downed', {})
end)
