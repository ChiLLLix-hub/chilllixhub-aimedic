# Spawn Location Handling for AI Medic

## Overview
This document describes the spawn location validation system that ensures the AI medic ambulance spawns in safe, accessible locations regardless of where the player is when they call for help.

## Problem Statement
Previously, the AI medic ambulance would spawn directly offset from the player's position without validation. This caused issues in two main scenarios:

1. **Player Inside Building/Interior**: The ambulance would spawn inside walls or underground, making it inaccessible or causing it to get stuck.
2. **Player in Ocean/Water**: The ambulance would spawn underwater, preventing the medic from reaching the player.

## Solution Implementation

### 1. Location Detection Functions

#### `IsPlayerInInterior()`
Detects if the player is inside a building or interior space.
- Uses `GetInteriorFromEntity()` native function
- Returns `true` if interior ID is non-zero (player is inside)
- Returns `false` if player is in open world

#### `IsPlayerInWater()`
Detects if the player is in water or swimming.
- Uses `IsPedSwimming()` to check if player is swimming on surface
- Uses `IsPedSwimmingUnderWater()` to check if player is submerged
- Returns `true` if either condition is met
- Returns `false` if player is on land

### 2. Safe Spawn Position Finding

#### `FindSafeSpawnPosition(playerPos)`
Finds a safe location to spawn the ambulance when the player is in a problematic location.

**Strategy 1: Nearest Road**
- Uses `GetClosestVehicleNodeWithHeading()` to find nearby road
- Validates the road position is not underwater using `TestProbeAgainstWater()`
- Returns road position if safe

**Strategy 2: Directional Search**
If no safe road is found, searches in 6 directions around the player:
- North (+30m Y)
- South (-30m Y)
- East (+30m X)
- West (-30m X)
- Northeast (+20m X, +20m Y)
- Southwest (-20m X, -20m Y)

For each direction:
1. Projects position from player location
2. Gets ground Z coordinate using `GetGroundZFor_3dCoord()`
3. Validates position is not in water using `TestProbeAgainstWater()`
4. Validates position is not in interior using `GetInteriorAtCoords()`
5. Returns first valid position found

**Fallback**: Returns player position if no safe location found (with increased offset distance)

### 3. Integration into Spawn Logic

The spawn validation is integrated into the `custom_aimedic:revivePlayer` event handler:

```lua
-- Check if player is in problematic location
local isInInterior = IsPlayerInInterior()
local isInWater = IsPlayerInWater()
local needsSafeSpawn = isInInterior or isInWater

if needsSafeSpawn then
    -- Find safe spawn position
    local safePos, foundSafe = FindSafeSpawnPosition(playerPos)
    
    if foundSafe then
        spawnPos = safePos
        -- Notify player of adjusted spawn
    else
        -- Use fallback with larger offset
        spawnPos = GetOffsetFromEntityInWorldCoords(playerPed, -30.0, 0.0, 0.0)
    end
else
    -- Normal spawn (player in open area)
    spawnPos = GetOffsetFromEntityInWorldCoords(playerPed, -10.0, 0.0, 0.0)
end

-- Ensure spawn has valid ground Z coordinate
local groundFound, groundZ = GetGroundZFor_3dCoord(spawnPos.x, spawnPos.y, spawnPos.z + 100.0, 0)
if groundFound then
    spawnPos = vector3(spawnPos.x, spawnPos.y, groundZ + 0.5)
end
```

### 4. User Notifications

The system provides context-aware notifications to inform the player about spawn location adjustments:

- **Interior**: "AI EMS is being dispatched to a nearby location (you are inside a building)."
- **Water**: "AI EMS is being dispatched to the nearest shore (you are in the water)."
- **Fallback**: "AI EMS is en route but may have difficulty reaching you due to your location."

### 5. Logging

Debug logging has been added to help troubleshoot spawn location issues:
- Logs interior/water detection status
- Logs when safe spawn position is found
- Logs when fallback position is used
- Logs ground Z adjustment

## Technical Details

### GTA V Natives Used
- `GetInteriorFromEntity(ped)` - Get interior ID from entity
- `IsPedSwimming(ped)` - Check if ped is swimming
- `IsPedSwimmingUnderWater(ped)` - Check if ped is underwater
- `GetClosestVehicleNodeWithHeading(x, y, z, nodeType, maxDistance, flags)` - Find nearest road
- `TestProbeAgainstWater(x1, y1, z1, x2, y2, z2)` - Check if position is in water
- `GetGroundZFor_3dCoord(x, y, z, returnVal)` - Get ground elevation at position
- `GetInteriorAtCoords(x, y, z)` - Get interior ID at coordinates

### Performance Considerations
- Functions execute quickly with minimal performance impact
- Directional search uses early exit when safe position is found
- Limited to 6 direction checks to avoid excessive computation
- Ground Z calculation cached per spawn event

## Testing Scenarios

The implementation should be tested in these scenarios:

1. **Normal Ground**: Player downed on street - should spawn nearby normally
2. **Inside Building**: Player downed in store/house - should spawn outside on road
3. **In Ocean**: Player drowned in deep water - should spawn on nearest shore
4. **In Pool**: Player drowned in pool - should spawn outside property
5. **Underground Tunnel**: Player downed in tunnel - should spawn at tunnel entrance or nearby surface road
6. **On Rooftop**: Player downed on building roof - medic should spawn on ground level

## Edge Cases Handled

1. **No Road Nearby**: Falls back to directional search
2. **All Directions Invalid**: Uses offset with warning notification
3. **Invalid Ground Z**: Keeps original spawn Z coordinate
4. **Multiple Interiors**: Checks each tested position independently
5. **Shallow Water**: Water detection works regardless of depth

## Future Enhancements

Potential improvements for the system:
1. Add spawn point validation on server-side before triggering client
2. Cache safe spawn locations near popular interior/water areas
3. Add visual indicator showing ambulance spawn location
4. Implement pathfinding preview to ensure medic can reach player
5. Add configuration option for spawn search radius

## Conclusion

This implementation provides robust handling of edge cases where players call for medic assistance from problematic locations. The multi-strategy approach ensures that in almost all scenarios, the ambulance will spawn in an accessible location and be able to reach the player for treatment.
