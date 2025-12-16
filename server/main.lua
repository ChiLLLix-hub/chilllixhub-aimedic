-- Cooldown tracking
local commandCooldowns = {}
local COOLDOWN_TIME = 60 -- 60 seconds between uses
local MAX_USES_PER_HOUR = 5 -- Maximum uses per hour
local REVIVE_TIMEOUT = 120 -- 2 minutes timeout for stuck revives

-- Usage tracking for abuse detection
local usageTracking = {}

-- Server-side revive state tracking
local playersBeingRevived = {}

-- Multi-player AI Medic tracking
local activeAIMedics = 0
local medicQueue = {}
local medicAssignments = {} -- Track which players are assigned to which medic
local activeMedicLocations = {} -- Track active medic dispatch locations

-- Hospital bed occupancy tracking
local occupiedBeds = {} -- Track which beds are currently occupied {[bedIndex] = playerId}
local playerBedAssignments = {} -- Track which bed each player is on {[playerId] = bedIndex}

-- Map bounds configuration
local MIN_MAP_X = -4000
local MAX_MAP_X = 4000
local MIN_MAP_Y = -4000
local MAX_MAP_Y = 4000
local MIN_MAP_Z = -100
local MAX_MAP_Z = 1000

-- Validate coordinates are within reasonable bounds
function ValidateCoordinates(coords)
    if not coords then return false end
    if type(coords) ~= 'vector3' then return false end
    
    -- GTA V map bounds
    if coords.x < MIN_MAP_X or coords.x > MAX_MAP_X then return false end
    if coords.y < MIN_MAP_Y or coords.y > MAX_MAP_Y then return false end
    if coords.z < MIN_MAP_Z or coords.z > MAX_MAP_Z then return false end
    
    return true
end

-- Get an available hospital bed
function GetAvailableBed()
    -- Try to find an unoccupied bed
    for bedIndex = 1, #Config.HospitalBeds do
        if not occupiedBeds[bedIndex] then
            return bedIndex
        end
    end
    
    -- If all beds are occupied, return a random one (overwrite)
    -- This prevents system failure when all beds are full
    print('[AI Medic] Warning: All hospital beds occupied, assigning random bed')
    return math.random(1, #Config.HospitalBeds)
end

-- Reserve a bed for a player
function ReserveBed(playerId, bedIndex)
    -- Release any previously assigned bed
    if playerBedAssignments[playerId] then
        local oldBedIndex = playerBedAssignments[playerId]
        occupiedBeds[oldBedIndex] = nil
        print('[AI Medic] Released bed ' .. oldBedIndex .. ' (previous assignment for player ' .. playerId .. ')')
    end
    
    -- Reserve the new bed
    occupiedBeds[bedIndex] = playerId
    playerBedAssignments[playerId] = bedIndex
    print('[AI Medic] Reserved bed ' .. bedIndex .. ' for player ' .. playerId)
end

-- Release a bed
function ReleaseBed(playerId)
    if playerBedAssignments[playerId] then
        local bedIndex = playerBedAssignments[playerId]
        occupiedBeds[bedIndex] = nil
        playerBedAssignments[playerId] = nil
        print('[AI Medic] Released bed ' .. bedIndex .. ' for player ' .. playerId)
        return true
    end
    return false
end

-- Find nearby downed players within radius
function FindNearbyDownedPlayers(coords, requestingPlayer)
    local nearbyPlayers = {}
    local players = GetPlayers()
    
    for _, playerId in ipairs(players) do
        local id = tonumber(playerId)
        if id and id ~= requestingPlayer then
            local playerPed = GetPlayerPed(id)
            if playerPed and playerPed ~= 0 then
                local playerCoords = GetEntityCoords(playerPed)
                if playerCoords then
                    local distance = #(coords - playerCoords)
                    if distance <= Config.NearbyPlayerRadius then
                        -- Check if player is downed
                        local isDowned = false
                        if Utils.QBCore then
                            local Player = Utils.QBCore.Functions.GetPlayer(id)
                            if Player and (Player.PlayerData.metadata['isdead'] or Player.PlayerData.metadata['inlaststand']) then
                                isDowned = true
                            end
                        else
                            if IsEntityDead(playerPed) then
                                isDowned = true
                            end
                        end
                        
                        if isDowned and not playersBeingRevived[id] then
                            table.insert(nearbyPlayers, {id = id, coords = playerCoords, distance = distance})
                        end
                    end
                end
            end
        end
    end
    
    -- Sort by distance (closest first)
    table.sort(nearbyPlayers, function(a, b) return a.distance < b.distance end)
    
    return nearbyPlayers
end

-- Check if there's already a medic dispatched nearby
function IsMedicNearby(coords)
    for medicId, medicData in pairs(activeMedicLocations) do
        local distance = #(coords - medicData.location)
        if distance <= Config.NearbyPlayerRadius then
            -- Check if this medic can handle more patients
            if #medicData.patients < Config.MaxPatientsPerMedic then
                return true, medicId
            end
        end
    end
    return false, nil
end

-- Assign player to existing medic
function AssignToExistingMedic(playerId, medicId)
    if activeMedicLocations[medicId] then
        table.insert(activeMedicLocations[medicId].patients, playerId)
        playersBeingRevived[playerId] = os.time()
        return true
    end
    return false
end

-- Create new medic assignment
function CreateMedicAssignment(primaryPlayer, coords, nearbyPlayers)
    local medicId = "medic_" .. primaryPlayer .. "_" .. os.time()
    local patients = {primaryPlayer}
    
    -- Add nearby players to this medic (up to max limit)
    local addedCount = 0
    for _, playerData in ipairs(nearbyPlayers) do
        if addedCount >= Config.MaxPatientsPerMedic - 1 then
            break
        end
        table.insert(patients, playerData.id)
        playersBeingRevived[playerData.id] = os.time()
        addedCount = addedCount + 1
    end
    
    activeMedicLocations[medicId] = {
        location = coords,
        patients = patients,
        primaryPlayer = primaryPlayer,
        timestamp = os.time()
    }
    
    activeAIMedics = activeAIMedics + 1
    
    return medicId, patients
end

-- Process next queued request
function ProcessMedicQueue()
    if #medicQueue > 0 and activeAIMedics < Config.MaxActiveAIMedics then
        local nextRequest = table.remove(medicQueue, 1)
        if nextRequest then
            Utils.Notify(nextRequest.source, "AI medic is now available! Dispatching...", "success")
            print('[AI Medic] Processing queued request for player: ' .. nextRequest.source)
            
            -- Re-trigger the medic dispatch
            local ped = GetPlayerPed(nextRequest.source)
            local coords = GetEntityCoords(ped)
            if ValidateCoordinates(coords) then
                DispatchAIMedic(nextRequest.source, coords)
            end
        end
    end
end

-- Main dispatch function
function DispatchAIMedic(source, coords)
    -- Check if there's already a medic nearby that can handle this player
    local medicNearby, medicId = IsMedicNearby(coords)
    if medicNearby and medicId then
        if AssignToExistingMedic(source, medicId) then
            Utils.Notify(source, "AI medic is already en route to your location. You will be treated shortly.", "primary")
            print('[AI Medic] Player ' .. source .. ' assigned to existing medic: ' .. medicId)
            return
        end
    end
    
    -- Find nearby downed players
    local nearbyPlayers = FindNearbyDownedPlayers(coords, source)
    
    -- Create new medic assignment
    local medicId, patients = CreateMedicAssignment(source, coords, nearbyPlayers)
    
    -- Notify all assigned players
    if #patients > 1 then
        Utils.Notify(source, "AI medic dispatched! Nearby patients detected (" .. (#patients - 1) .. "). ETA: 30 seconds", "success")
        for i = 2, #patients do
            local patientId = patients[i]
            Utils.Notify(patientId, "AI medic en route to your location. You will be treated shortly.", "primary")
            print('[AI Medic] Player ' .. patientId .. ' auto-assigned to medic for group treatment')
        end
    else
        Utils.Notify(source, "AI medic dispatched! ETA: 30 seconds", "success")
    end
    
    print('[AI Medic] Medic ' .. medicId .. ' dispatched for ' .. #patients .. ' patient(s)')
    
    -- Trigger client event with patient list
    TriggerClientEvent('custom_aimedic:revivePlayer', source, coords, patients, medicId)
end

-- Function to start revive process
function StartReviveProcess(source)
    if playersBeingRevived[source] then
        return false, "You are already being revived!"
    end
    playersBeingRevived[source] = os.time()
    return true, "Revive started"
end

-- Function to end revive process
function EndReviveProcess(source)
    playersBeingRevived[source] = nil
end

-- Cleanup old cooldown data every 5 minutes
CreateThread(function()
    while true do
        Wait(300000) -- 5 minutes
        local currentTime = os.time()
        for player, data in pairs(commandCooldowns) do
            if currentTime - data > 3600 then -- 1 hour old
                commandCooldowns[player] = nil
            end
        end
        for player, data in pairs(usageTracking) do
            if currentTime - data.resetTime > 3600 then
                usageTracking[player] = nil
            end
        end
    end
end)

-- Timeout check (cleanup stuck revives)
CreateThread(function()
    while true do
        Wait(30000) -- Check every 30 seconds
        local currentTime = os.time()
        for player, startTime in pairs(playersBeingRevived) do
            if currentTime - startTime > REVIVE_TIMEOUT then
                playersBeingRevived[player] = nil
                print('[AI Medic] Cleaned up stuck revive state for player: ' .. player)
            end
        end
        
        -- Cleanup old medic assignments
        for medicId, medicData in pairs(activeMedicLocations) do
            if currentTime - medicData.timestamp > 300 then -- 5 minutes old
                activeMedicLocations[medicId] = nil
                print('[AI Medic] Cleaned up old medic assignment: ' .. medicId)
            end
        end
    end
end)

-- Cleanup disconnected players
AddEventHandler('playerDropped', function()
    local src = source
    if playersBeingRevived[src] then
        playersBeingRevived[src] = nil
        print('[AI Medic] Cleaned up revive state for disconnected player: ' .. src)
    end
    if commandCooldowns[src] then
        commandCooldowns[src] = nil
    end
    if usageTracking[src] then
        usageTracking[src] = nil
    end
    
    -- Remove from queue if present
    for i = #medicQueue, 1, -1 do
        if medicQueue[i].source == src then
            table.remove(medicQueue, i)
            print('[AI Medic] Removed disconnected player from queue: ' .. src)
        end
    end
    
    -- Remove from medic assignments
    for medicId, medicData in pairs(activeMedicLocations) do
        for i = #medicData.patients, 1, -1 do
            if medicData.patients[i] == src then
                table.remove(medicData.patients, i)
                print('[AI Medic] Removed disconnected player from medic assignment: ' .. src)
            end
        end
    end
    
    -- Release any occupied bed
    ReleaseBed(src)
end)

RegisterCommand('callmedic', function(source)
    local currentTime = os.time()
    
    -- Check if player is actually downed FIRST (before any tracking)
    local ped = GetPlayerPed(source)
    local isDowned = false
    
    if Utils.QBCore then
        local Player = Utils.QBCore.Functions.GetPlayer(source)
        if Player and (Player.PlayerData.metadata['isdead'] or Player.PlayerData.metadata['inlaststand']) then
            isDowned = true
        end
    else
        if IsEntityDead(ped) then
            isDowned = true
        end
    end
    
    if not isDowned then
        Utils.Notify(source, "You are not injured enough to call EMS.", "error")
        print('[AI Medic] Player ' .. source .. ' attempted to call medic while not downed')
        return
    end
    
    -- Check cooldown
    if commandCooldowns[source] and currentTime - commandCooldowns[source] < COOLDOWN_TIME then
        local remaining = COOLDOWN_TIME - (currentTime - commandCooldowns[source])
        Utils.Notify(source, "Please wait " .. remaining .. " seconds before calling medic again.", "error")
        print('[AI Medic] Player ' .. source .. ' attempted to call medic during cooldown')
        return
    end
    
    -- Track usage for abuse detection
    if not usageTracking[source] then
        usageTracking[source] = {count = 0, resetTime = currentTime + 3600}
    end
    
    if currentTime > usageTracking[source].resetTime then
        usageTracking[source] = {count = 0, resetTime = currentTime + 3600}
    end
    
    usageTracking[source].count = usageTracking[source].count + 1
    
    if usageTracking[source].count > MAX_USES_PER_HOUR then
        Utils.Notify(source, "You have exceeded the hourly limit for AI medic. Please wait.", "error")
        print('[AI Medic] WARNING: Player ' .. source .. ' exceeded hourly limit (' .. usageTracking[source].count .. ' uses)')
        return
    end
    
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

    local coords = GetEntityCoords(ped)
    if not ValidateCoordinates(coords) then
        print('[AI Medic] Invalid coords for source: ' .. source .. ' - ' .. tostring(coords))
        Utils.Notify(source, "Invalid location for medic service.", "error")
        return
    end
    
    -- Check if already being revived
    if playersBeingRevived[source] then
        Utils.Notify(source, "You are already being revived!", "error")
        return
    end
    
    -- Check global medic limit
    if activeAIMedics >= Config.MaxActiveAIMedics then
        -- Add to queue
        table.insert(medicQueue, {source = source, coords = coords, timestamp = currentTime})
        Utils.Notify(source, "All AI medics are busy. You are #" .. #medicQueue .. " in queue.", "error")
        print('[AI Medic] Player ' .. source .. ' added to queue. Queue position: ' .. #medicQueue)
        return
    end
    
    -- Set cooldown BEFORE triggering (prevents double-tapping)
    commandCooldowns[source] = currentTime
    playersBeingRevived[source] = currentTime
    
    -- Dispatch AI medic with smart queue system
    DispatchAIMedic(source, coords)
end, false)

-- Event handler for charging player (server validates source)
-- NOTE: This event no longer accepts parameters from client for security
-- Server always uses the authenticated source ID
RegisterNetEvent('custom_aimedic:chargePlayer')
AddEventHandler('custom_aimedic:chargePlayer', function()
    local src = source -- ALWAYS use source, never trust client parameters
    
    -- Rate limit: max 3 calls per minute
    if not RateLimiter.CheckLimit(src, 'chargePlayer', 3, 60) then
        print('[AI Medic] Player ' .. src .. ' rate limited on chargePlayer')
        return
    end
    
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
    local src = source
    
    -- Rate limit: max 2 calls per minute
    if not RateLimiter.CheckLimit(src, 'revivePlayer', 2, 60) then
        print('[AI Medic] Player ' .. src .. ' rate limited on revivePlayer')
        return
    end
    
    -- SECURITY: Only allow players to revive themselves
    if target ~= src then
        print('[AI Medic] SECURITY WARNING: Player ' .. src .. ' attempted to revive player ' .. target .. ' - BLOCKED')
        return
    end
    
    print('[AI Medic] Revive requested for target: ' .. target)
    if Utils.QBCore then
        -- Use QBCore's revive event (adjust based on your QBCore version)
        TriggerClientEvent('hospital:client:Revive', target) -- Common QBCore revive event
    else
        -- Standalone revive logic
        TriggerClientEvent('custom_aimedic:standaloneRevive', target)
    end
end)

-- Client notifies when revive is complete
RegisterNetEvent('custom_aimedic:reviveComplete')
AddEventHandler('custom_aimedic:reviveComplete', function(medicId)
    local src = source
    EndReviveProcess(src)
    print('[AI Medic] Revive completed for player: ' .. src)
    
    -- If medicId provided, clean up the medic assignment
    if medicId and activeMedicLocations[medicId] then
        activeMedicLocations[medicId] = nil
        activeAIMedics = activeAIMedics - 1
        print('[AI Medic] Medic ' .. medicId .. ' completed service. Active medics: ' .. activeAIMedics)
        
        -- Process queue if there are waiting requests
        ProcessMedicQueue()
    end
end)

-- Request an available hospital bed
RegisterNetEvent('custom_aimedic:requestBed')
AddEventHandler('custom_aimedic:requestBed', function()
    local src = source
    local bedIndex = GetAvailableBed()
    ReserveBed(src, bedIndex)
    
    -- Send bed data back to client
    TriggerClientEvent('custom_aimedic:assignBed', src, bedIndex, Config.HospitalBeds[bedIndex])
end)

-- Release hospital bed when player gets up
RegisterNetEvent('custom_aimedic:releaseBed')
AddEventHandler('custom_aimedic:releaseBed', function()
    local src = source
    ReleaseBed(src)
end)
