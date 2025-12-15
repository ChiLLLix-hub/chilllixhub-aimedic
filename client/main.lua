local isBeingRevived = false
local MEDBAG_MODEL = "prop_med_bag_01"

RegisterNetEvent('custom_aimedic:revivePlayer')
AddEventHandler('custom_aimedic:revivePlayer', function(playerCoords)
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
    local spawnPos = GetOffsetFromEntityInWorldCoords(playerPed, -10.0, 0.0, 0.0)
    local vehicle = CreateVehicle(Config.AmbulanceModel, spawnPos.x, spawnPos.y, spawnPos.z, 0.0, true, false)
    local medic = CreatePedInsideVehicle(vehicle, 4, Config.MedicModel, -1, true, false)

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

    ClearPedTasks(medic)
    Wait(1000)
    TaskLeaveVehicle(medic, vehicle, 0)
    Wait(2000)
    if IsPedInAnyVehicle(medic, false) then
        ClearPedTasksImmediately(medic)
        TaskLeaveVehicle(medic, vehicle, 0)
        Wait(2000)
    end

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
    TriggerServerEvent('custom_aimedic:chargePlayer')
    TriggerServerEvent('custom_aimedic:revivePlayer', GetPlayerServerId(PlayerId()))

    Wait(2000)
    if IsEntityDead(PlayerPedId()) then
        local ped = PlayerPedId()
        local coords = GetEntityCoords(ped)
        NetworkResurrectLocalPlayer(coords.x, coords.y, coords.z, GetEntityHeading(ped), true, false)
        SetEntityHealth(ped, GetEntityMaxHealth(ped))
        ClearPedTasksImmediately(ped)
        Utils.NotifyClient('You have been revived by AI EMS (fallback).', 'success')
    end

    DeleteEntity(bag)
    ClearPedTasks(medic)
    Wait(1000)

    local dest = GetNearestHospital(playerPos)
    TaskEnterVehicle(playerPed, vehicle, 10000, 2, 1.0, 1, 0)
    Wait(3000)
    TaskVehicleDriveToCoord(medic, vehicle, dest.x, dest.y, dest.z, 25.0, 0, GetHashKey(Config.AmbulanceModel), 524863, 5.0, 1.0)

    local driveTimeout = GetGameTimer() + 60000
    while #(GetEntityCoords(vehicle) - dest) > 5.0 and GetGameTimer() < driveTimeout do Wait(1000) end

    TaskLeaveVehicle(playerPed, vehicle, 0)
    Wait(2000)
    if DoesBlipExist(blip) then RemoveBlip(blip) end
    TaskEnterVehicle(medic, vehicle, -1, -1, 1.0, 1, 0)
    Wait(3000)

    DeleteEntity(medic)
    DeleteEntity(vehicle)
    isBeingRevived = false
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

function GetNearestHospital(pos)
    local closest, dist
    for _, hospital in pairs(Config.Hospitals) do
        if hospital and type(hospital) == 'vector3' then
            local d = #(pos - hospital)
            if not dist or d < dist then
                closest, dist = hospital, d
            end
        end
    end
    return closest or Config.Hospitals.default
end

function WeaponToName(hash)
    for name, value in pairs(_G) do
        if type(value) == 'number' and value == hash and name:match("^WEAPON_") then
            return name:gsub("WEAPON_", ""):gsub("_", " "):lower()
        end
    end
    return "unknown"
end
