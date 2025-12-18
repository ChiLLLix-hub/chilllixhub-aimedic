local isBeingRevived = false
local MEDBAG_MODEL = "prop_med_bag_01"

-- Spawn location constants
local ROAD_SEARCH_RADIUS = 3.0 -- Maximum distance to search for nearest road
local SEARCH_DISTANCE_FAR = 30.0 -- Far search distance for directional scan
local SEARCH_DISTANCE_NEAR = 20.0 -- Near search distance for diagonal directions
local GROUND_SEARCH_HEIGHT = 100.0 -- Height offset for ground detection
local GROUND_OFFSET = 0.5 -- Vertical offset above ground level for spawn

-- Function to check if player is in an interior/building
function IsPlayerInInterior()
    local playerPed = PlayerPedId()
    local interior = GetInteriorFromEntity(playerPed)
    return interior ~= 0
end

-- Function to check if player is in water/ocean
function IsPlayerInWater()
    local playerPed = PlayerPedId()
    return IsPedSwimming(playerPed) or IsPedSwimmingUnderWater(playerPed)
end

-- Function to find safe spawn position for ambulance
-- Returns a safe position on a nearby road or falls back to a position outside the interior/water
function FindSafeSpawnPosition(playerPos)
    local safePos = playerPos
    local foundSafe = false
    
    -- Try to find a nearby road position
    local roadFound, roadCoords, heading = GetClosestVehicleNodeWithHeading(playerPos.x, playerPos.y, playerPos.z, 1, ROAD_SEARCH_RADIUS, 0)
    
    if roadFound then
        -- Verify the road position is not in water
        local testWater, waterZ = TestProbeAgainstWater(roadCoords.x, roadCoords.y, roadCoords.z - 5.0, roadCoords.x, roadCoords.y, roadCoords.z + 5.0)
        
        if not testWater then
            -- Road position is safe (not in water)
            safePos = roadCoords
            foundSafe = true
        end
    end
    
    -- If we still don't have a safe position, try multiple directions from player
    if not foundSafe then
        local directions = {
            {x = SEARCH_DISTANCE_FAR, y = 0.0},
            {x = -SEARCH_DISTANCE_FAR, y = 0.0},
            {x = 0.0, y = SEARCH_DISTANCE_FAR},
            {x = 0.0, y = -SEARCH_DISTANCE_FAR},
            {x = SEARCH_DISTANCE_NEAR, y = SEARCH_DISTANCE_NEAR},
            {x = -SEARCH_DISTANCE_NEAR, y = -SEARCH_DISTANCE_NEAR},
        }
        
        for _, dir in ipairs(directions) do
            local testPos = vector3(playerPos.x + dir.x, playerPos.y + dir.y, playerPos.z)
            local groundFound, groundZ = GetGroundZFor_3dCoord(testPos.x, testPos.y, testPos.z + GROUND_SEARCH_HEIGHT, 0)
            
            if groundFound then
                testPos = vector3(testPos.x, testPos.y, groundZ)
                local testWater, waterZ = TestProbeAgainstWater(testPos.x, testPos.y, testPos.z - 5.0, testPos.x, testPos.y, testPos.z + 5.0)
                
                -- Check if position is not in water and not in interior
                if not testWater then
                    -- Check if this position is also outside interior
                    local testInterior = GetInteriorAtCoords(testPos.x, testPos.y, testPos.z)
                    if testInterior == 0 then
                        safePos = testPos
                        foundSafe = true
                        break
                    end
                end
            end
        end
    end
    
    return safePos, foundSafe
end

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

    -- Store medicId for cleanup
    local currentMedicId = medicId or "medic_unknown"
    local patientList = patients or {GetPlayerServerId(PlayerId())}

    local cause = GetPedCauseOfDeath(playerPed)
    local causeText = WeaponToName(cause)
    local displayCause = "Died from: " .. causeText

    RequestModel(Config.MedicModel)
    RequestModel(Config.AmbulanceModel)
    RequestModel(GetHashKey(MEDBAG_MODEL))
    while not HasModelLoaded(Config.MedicModel) or not HasModelLoaded(Config.AmbulanceModel) or not HasModelLoaded(GetHashKey(MEDBAG_MODEL)) do
        Wait(10)
    end

    local playerPos = GetEntityCoords(playerPed)
    
    -- Check if player is in problematic location
    local isInInterior = IsPlayerInInterior()
    local isInWater = IsPlayerInWater()
    local needsSafeSpawn = isInInterior or isInWater
    
    print('[AI Medic Client] Player location check - Interior: ' .. tostring(isInInterior) .. ', Water: ' .. tostring(isInWater))
    
    local spawnPos = playerPos
    if needsSafeSpawn then
        -- Find a safe spawn position
        local safePos, foundSafe = FindSafeSpawnPosition(playerPos)
        
        if foundSafe then
            spawnPos = safePos
            print('[AI Medic Client] Found safe spawn position: ' .. tostring(spawnPos))
            if isInInterior then
                Utils.NotifyClient('AI EMS is being dispatched to a nearby location (you are inside a building).', 'primary')
            elseif isInWater then
                Utils.NotifyClient('AI EMS is being dispatched to the nearest shore (you are in the water).', 'primary')
            end
        else
            -- If we can't find a safe position, use offset from player position
            spawnPos = GetOffsetFromEntityInWorldCoords(playerPed, -30.0, 0.0, 0.0)
            print('[AI Medic Client] Could not find safe spawn, using fallback offset position')
            Utils.NotifyClient('AI EMS is en route but may have difficulty reaching you due to your location.', 'warning')
        end
    else
        -- Normal spawn: offset from player position
        spawnPos = GetOffsetFromEntityInWorldCoords(playerPed, -10.0, 0.0, 0.0)
        print('[AI Medic Client] Normal spawn - player in open area')
    end
    
    -- Ensure spawn position has valid ground Z
    local groundFound, groundZ = GetGroundZFor_3dCoord(spawnPos.x, spawnPos.y, spawnPos.z + GROUND_SEARCH_HEIGHT, 0)
    if groundFound then
        spawnPos = vector3(spawnPos.x, spawnPos.y, groundZ + GROUND_OFFSET)
        print('[AI Medic Client] Adjusted spawn position to ground level: Z=' .. groundZ)
    end
    
    local vehicle = CreateVehicle(Config.AmbulanceModel, spawnPos.x, spawnPos.y, spawnPos.z, 0.0, true, false)
    local medic = CreatePedInsideVehicle(vehicle, 4, Config.MedicModel, -1, true, false)

    -- Ensure vehicle is completely unlocked for all operations
    SetVehicleDoorsLocked(vehicle, 1) -- 1 = unlocked
    SetVehicleDoorsLockedForAllPlayers(vehicle, false)
    SetVehicleDoorsLockedForPlayer(vehicle, PlayerId(), false)
    -- Unlock all individual doors
    for i = 0, 5 do
        SetVehicleDoorOpen(vehicle, i, false, false) -- Open doors briefly to unlock
        Wait(10)
        SetVehicleDoorShut(vehicle, i, false) -- Close them
    end
    
    SetVehicleSiren(vehicle, true)
    SetVehicleHasMutedSirens(vehicle, false)
    SetVehicleLights(vehicle, 2)

    local blip = AddBlipForEntity(vehicle)
    SetBlipSprite(blip, 56)
    SetBlipScale(blip, 0.9)
    SetBlipColour(blip, 1)
    BeginTextCommandSetBlipName("STRING")
    AddTextComponentString("AI Medic")
    EndTextCommandSetBlipName(blip)

    Utils.NotifyClient('AI EMS is on the way!', 'primary')

    TaskVehicleDriveToCoord(medic, vehicle, playerPos.x, playerPos.y, playerPos.z, 25.0, 0, GetHashKey(Config.AmbulanceModel), 524863, 5.0, 1.0)

    local timeout = GetGameTimer() + 30000
    while #(GetEntityCoords(vehicle) - playerPos) > 5.0 and GetGameTimer() < timeout do Wait(500) end

    -- Immediately unlock vehicle when arrived
    SetVehicleDoorsLocked(vehicle, 1) -- 1 = unlocked
    SetVehicleDoorsLockedForAllPlayers(vehicle, false)
    SetVehicleDoorsLockedForPlayer(vehicle, PlayerId(), false)
    
    ClearPedTasks(medic)
    Wait(500) -- Reduced from 1000ms to 500ms
    
    -- Force unlock all doors before medic exits
    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(vehicle, false)
    SetVehicleDoorsLockedForPlayer(vehicle, PlayerId(), false)
    
    TaskLeaveVehicle(medic, vehicle, 0)
    Wait(1000) -- Reduced from 2000ms to 1000ms
    
    -- Force medic out if still inside
    if IsPedInAnyVehicle(medic, false) then
        ClearPedTasksImmediately(medic)
        SetPedCanRagdoll(medic, false)
        TaskLeaveVehicle(medic, vehicle, 256) -- Use flag 256 for instant exit
        Wait(500) -- Reduced from 2000ms to 500ms
    end
    
    -- Ensure vehicle remains unlocked after medic exits
    SetVehicleDoorsLocked(vehicle, 1)
    SetVehicleDoorsLockedForAllPlayers(vehicle, false)
    SetVehicleDoorsLockedForPlayer(vehicle, PlayerId(), false)

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
    
    -- Cleanup medic and vehicle while screen is black
    DeleteEntity(bag)
    DeleteEntity(medic)
    DeleteEntity(vehicle)
    if DoesBlipExist(blip) then RemoveBlip(blip) end
    
    -- Cleanup models from memory
    SetModelAsNoLongerNeeded(Config.MedicModel)
    SetModelAsNoLongerNeeded(Config.AmbulanceModel)
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
