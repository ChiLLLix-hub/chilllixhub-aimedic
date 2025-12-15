# AI Medic Script - Operation Documentation

## Overview
The **CES_AI_Medic_Script** is an autonomous AI medic system for FiveM servers that provides emergency medical services when human EMS players are unavailable. The script is compatible with both QBCore framework and standalone mode.

## Architecture

### File Structure
```
├── config.lua              # Configuration settings
├── fxmanifest.lua         # Resource manifest
├── client/
│   ├── main.lua           # Client-side main logic
│   └── utils_client.lua   # Client utility functions
└── server/
    ├── main.lua           # Server-side main logic
    └── utils_server.lua   # Server utility functions
```

## How It Works

### 1. System Initialization

#### Server-Side (`server/utils_server.lua`)
- **Framework Detection**: On startup, the script checks if QBCore is available
- If QBCore is running, it initializes the QBCore object for integration
- If not, it runs in standalone mode with fallback functionality

#### Client-Side (`client/utils_client.lua`)
- Similar framework detection happens on the client
- Initializes notification system based on available framework

### 2. Calling the AI Medic

#### Command Registration (`server/main.lua`)
The `/callmedic` command is registered and performs:

1. **EMS Availability Check**:
   - Counts online EMS players (if QBCore is active)
   - If more than `Config.MaxEMSOnline` (5) EMS are online, denies the request
   - This prevents AI medic from interfering with real player EMS

2. **Location Retrieval**:
   - Gets the player's coordinates
   - Validates the location data

3. **Event Trigger**:
   - Triggers `custom_aimedic:revivePlayer` client event with player coordinates

### 3. AI Medic Dispatch (`client/main.lua`)

When the `custom_aimedic:revivePlayer` event is triggered:

#### Phase 1: Validation
```lua
- Checks if player is already being revived (prevents duplicate calls)
- Verifies player is actually downed/dead:
  * QBCore: Checks metadata['isdead'] or metadata['inlaststand']
  * Standalone: Uses IsEntityDead()
- Determines cause of death for display
```

#### Phase 2: Spawn & Approach
```lua
- Loads required models:
  * Medic NPC (s_m_m_paramedic_01)
  * Ambulance vehicle
  * Medical bag prop (prop_med_bag_01)
  
- Spawns ambulance 10 units away from player
- Creates medic NPC inside the ambulance
- Activates sirens and emergency lights
- Creates a red blip on the map labeled "AI Medic"
- Drives to player location using TaskVehicleDriveToCoord
- 30-second timeout for arrival
```

#### Phase 3: Treatment
```lua
- Medic exits vehicle
- Walks to player position
- Places medical bag on ground
- Plays treatment animation ("amb@medic@standing@tendtodead@idle_a")
- Displays:
  * Progress bar at bottom of screen
  * 3D text above medic showing cause of death
- Treatment duration: Config.ReviveDelay (10 seconds default)
```

#### Phase 4: Revival
```lua
- Server charges player Config.Fee ($500 default)
- Server triggers revive:
  * QBCore: Uses 'hospital:client:Revive' event
  * Standalone: Uses NetworkResurrectLocalPlayer
- Fallback revival if server event fails
- Cleans up medical bag
```

#### Phase 5: Hospital Transport
```lua
- Player enters ambulance as passenger
- Medic drives to nearest hospital from Config.Hospitals
- Uses GetNearestHospital() to find closest location
- 60-second timeout for hospital arrival
- Player exits at hospital
- Medic returns to vehicle
- Cleanup: Removes blip, deletes medic and ambulance
```

### 4. Payment System (`server/main.lua`)

#### Event: `custom_aimedic:chargePlayer`
- Attempts to get player framework object
- In QBCore mode:
  - Removes $500 (Config.Fee) from player's bank account
  - Notifies player of charge
  - Handles insufficient funds
- In standalone mode:
  - Fee is skipped (no economy system)

### 5. Revival System (`server/main.lua`)

#### Event: `custom_aimedic:revivePlayer`
- QBCore: Triggers standard QBCore revival event
- Standalone: Triggers custom revival event that:
  - Resurrects player at current location
  - Restores full health
  - Clears all tasks/animations

## Key Features

### 1. Framework Compatibility
- **QBCore Integration**:
  - Uses QBCore player data for death detection
  - Integrates with QBCore economy system
  - Uses QBCore notification system
  - Checks actual ambulance job players

- **Standalone Fallback**:
  - Basic death detection via native functions
  - Chat-based notifications
  - Free revives (no economy)
  - Always available (no EMS check)

### 2. Smart EMS Detection
- Only activates when EMS count ≤ Config.MaxEMSOnline
- Prevents interference with real player RP

### 3. Visual Feedback
- Map blip tracking ambulance
- Progress bar during treatment
- 3D floating text showing cause of death
- Animated treatment sequence

### 4. Robust Error Handling
- Timeouts for vehicle arrival and hospital transport
- Fallback revival if framework revival fails
- Prevents duplicate simultaneous revives
- Validates player state before proceeding

## Configuration Options

### `config.lua`
```lua
Config.MedicModel       -- NPC model (default: 's_m_m_paramedic_01')
Config.AmbulanceModel   -- Vehicle model (default: 'Ambulance')
Config.ReviveDelay      -- Treatment time in ms (default: 10000)
Config.Fee              -- Revival cost (default: 500)
Config.MaxEMSOnline     -- Max EMS before disable (default: 5)
Config.Hospitals        -- Hospital locations (MISSING - needs to be added)
```

## Known Issues

### 1. Missing Hospital Configuration
The script references `Config.Hospitals` but it's not defined in config.lua. The GetNearestHospital function will fail without this. Should contain:
```lua
Config.Hospitals = {
    city = vector3(308.24, -592.42, 43.28),
    sandy = vector3(1828.52, 3673.22, 34.28),
    paleto = vector3(-247.76, 6331.23, 32.43),
    default = vector3(293.0, -582.0, 43.0)
}
```

### 2. Double Event Registration
In `server/main.lua`, the event `custom_aimedic:revivePlayer` is registered twice:
- Line 48: As a server event handler
- This could be confusing but won't cause errors

### 3. Potential Resource Cleanup
Entities are deleted but models remain loaded. Consider calling `SetModelAsNoLongerNeeded()` after use.

## Security Considerations

### Potential Vulnerabilities
1. **Client-Side Spawning**: Entities are spawned client-side, which could be exploited
2. **Command Access**: The `/callmedic` command has no permission checks
3. **No Cooldown**: Players could spam the command
4. **Client-Side Money Check**: While server validates, client makes assumptions

### Recommendations
1. Add command cooldown system
2. Add permission/ace check for command
3. Consider moving entity spawning to server-side
4. Add anti-spam protection
5. Add logging for admin monitoring

## Flow Diagram

```
Player Dies
    ↓
Player types /callmedic
    ↓
Server checks EMS count → [Too many EMS] → Deny
    ↓
Server validates player location
    ↓
Server triggers client event
    ↓
Client validates player is downed
    ↓
Client spawns ambulance + medic
    ↓
Ambulance drives to player (sirens on)
    ↓
Medic exits and walks to player
    ↓
Medic performs treatment animation
    ↓
Server charges player fee
    ↓
Server revives player
    ↓
Player enters ambulance
    ↓
Medic drives to nearest hospital
    ↓
Player exits at hospital
    ↓
Cleanup: Delete medic and ambulance
    ↓
Player is free to continue playing
```

## Dependencies

### Required
- FiveM server
- GTA5 game

### Optional
- qb-core framework (for full integration)

### Native Functions Used
- GetPlayerPed, GetEntityCoords
- CreateVehicle, CreatePedInsideVehicle
- TaskVehicleDriveToCoord, TaskGoToCoordAnyMeans
- NetworkResurrectLocalPlayer
- SetEntityHealth, ClearPedTasks
- RequestModel, HasModelLoaded
- CreateObject, DeleteEntity
- And many more GTA5 natives

## Performance Considerations

1. **Model Loading**: Models are loaded synchronously with Wait() loops
2. **Thread Usage**: Multiple Wait() calls in main thread could impact performance
3. **Entity Cleanup**: Proper cleanup prevents entity leak
4. **Blip Management**: Blips are properly removed

## Conclusion

This is a well-structured autonomous medic system that provides a good player experience when real EMS are unavailable. The dual-mode operation (QBCore/Standalone) makes it versatile for different server setups. Main improvements needed are adding the missing hospital configuration and addressing security/spam concerns.
