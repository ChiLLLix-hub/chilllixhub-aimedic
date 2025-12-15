# Security Analysis Report - AI Medic Script

## Executive Summary

This document provides a comprehensive security analysis of the CES_AI_Medic_Script for FiveM. Since the script is written in Lua (which is not supported by CodeQL), this is a manual security review based on common FiveM security patterns and best practices.

**Overall Risk Level**: MODERATE
- The script contains several security concerns typical of FiveM resources
- Most issues are related to abuse potential rather than critical exploits
- Recommended improvements are included below

---

## CodeQL Analysis Results

**Status**: Not Applicable
**Reason**: CodeQL does not support Lua language analysis

**Alternative Analysis Method**: Manual code review based on:
- FiveM security best practices
- Common Lua/FiveM vulnerability patterns
- OWASP principles adapted for game scripting
- Community-reported FiveM exploits

---

## Security Findings

### 1. Command Injection & Spam Prevention

#### Finding: No Command Cooldown System
**Severity**: MEDIUM
**Location**: `server/main.lua` - `RegisterCommand('callmedic', ...)`

**Description**:
Players can spam the `/callmedic` command repeatedly without any cooldown or rate limiting.

**Impact**:
- Server resource exhaustion from spawning multiple ambulances
- Griefing potential (blocking roads with ambulances)
- Performance degradation

**Recommendation**:
```lua
local commandCooldowns = {}
local COOLDOWN_TIME = 60000 -- 60 seconds

RegisterCommand('callmedic', function(source)
    local currentTime = os.time() * 1000
    if commandCooldowns[source] and currentTime - commandCooldowns[source] < COOLDOWN_TIME then
        local remaining = math.ceil((COOLDOWN_TIME - (currentTime - commandCooldowns[source])) / 1000)
        Utils.Notify(source, "Please wait " .. remaining .. " seconds before calling medic again.", "error")
        return
    end
    
    commandCooldowns[source] = currentTime
    -- ... rest of command logic
end, false)
```

**Status**: Not Fixed (Minimal change requirement)

---

### 2. Permission & Access Control

#### Finding: No Permission Check on Command
**Severity**: LOW-MEDIUM
**Location**: `server/main.lua` - `RegisterCommand('callmedic', ...)`

**Description**:
The `/callmedic` command is available to all players without any permission checks or restrictions.

**Impact**:
- Any player can call the service, even if they shouldn't (e.g., already revived)
- No way for admins to restrict access
- Could be abused by banned players if anti-cheat isn't configured

**Recommendation**:
While the current design may be intentional (all players should access medic), consider:
```lua
RegisterCommand('callmedic', function(source)
    -- Optional: Add ace permission check
    if not IsPlayerAceAllowed(source, "aimedic.use") then
        Utils.Notify(source, "You don't have permission to use AI medic.", "error")
        return
    end
    -- ... rest of logic
end, false)
```

**Status**: Not Fixed (Feature, not bug - all players should access)

---

### 3. Client-Side Entity Spawning

#### Finding: Entities Spawned Client-Side
**Severity**: MEDIUM-HIGH
**Location**: `client/main.lua` - Lines 43-44

**Description**:
The ambulance vehicle and medic NPC are spawned client-side:
```lua
local vehicle = CreateVehicle(Config.AmbulanceModel, spawnPos.x, spawnPos.y, spawnPos.z, 0.0, true, false)
local medic = CreatePedInsideVehicle(vehicle, 4, Config.MedicModel, -1, true, false)
```

**Impact**:
- Modified clients could spawn malicious entities
- Network desync if client's entity doesn't match server expectations
- Potential for entity ID conflicts
- Modders could spawn unlimited entities
- No server-side validation of spawned entities

**Recommendation**:
Move entity spawning to server-side and sync to clients:
```lua
-- server/main.lua
function SpawnAIMedic(playerCoords)
    local spawnPos = playerCoords - vector3(10.0, 0.0, 0.0)
    local vehicle = CreateVehicle(Config.AmbulanceModel, spawnPos.x, spawnPos.y, spawnPos.z, 0.0, true, true)
    -- Wait for vehicle to exist
    while not DoesEntityExist(vehicle) do Wait(0) end
    local medic = CreatePedInsideVehicle(vehicle, 4, Config.MedicModel, -1, true, true)
    return NetworkGetNetworkIdFromEntity(vehicle), NetworkGetNetworkIdFromEntity(medic)
end
```

**Status**: Not Fixed (Major refactoring required, beyond minimal changes)

---

### 4. Input Validation

#### Finding: Limited Coordinate Validation
**Severity**: LOW
**Location**: `server/main.lua` - Line 21

**Description**:
The script checks if coordinates exist but doesn't validate they're reasonable:
```lua
local coords = GetEntityCoords(ped)
if not coords then
    -- error
end
```

**Impact**:
- Could spawn ambulances in invalid locations (underwater, in sky, etc.)
- Potential for ambulances getting stuck
- Minor griefing potential

**Recommendation**:
```lua
local coords = GetEntityCoords(ped)
if not coords or coords.z < -100 or coords.z > 1000 then
    Utils.Notify(source, "Invalid location for medic service.", "error")
    return
end
```

**Status**: Not Fixed (Low severity, edge case)

---

### 5. Resource Cleanup

#### Finding: Models Not Marked as No Longer Needed
**Severity**: LOW
**Location**: `client/main.lua` - After entity deletion

**Description**:
Models are loaded but never freed:
```lua
RequestModel(Config.MedicModel)
RequestModel(Config.AmbulanceModel)
RequestModel(GetHashKey(MEDBAG_MODEL))
-- ... used later
-- Missing: SetModelAsNoLongerNeeded()
```

**Impact**:
- Memory leak over time with repeated use
- Increased memory footprint
- Could contribute to performance issues on lower-end systems

**Recommendation**:
```lua
-- After DeleteEntity calls at end of script
SetModelAsNoLongerNeeded(Config.MedicModel)
SetModelAsNoLongerNeeded(Config.AmbulanceModel)
SetModelAsNoLongerNeeded(GetHashKey(MEDBAG_MODEL))
```

**Status**: Not Fixed (Performance optimization, not security)

---

### 6. Money Handling

#### Finding: Client Assumes Server Will Handle Payment
**Severity**: LOW
**Location**: `client/main.lua` - Line 106

**Description**:
Client triggers payment event but doesn't wait for confirmation:
```lua
TriggerServerEvent('custom_aimedic:chargePlayer')
```

**Impact**:
- If server event fails, player gets free revive
- In standalone mode, no payment occurs
- No feedback if payment fails

**Recommendation**:
Current implementation is acceptable for game mechanic. Real security concern would be if client could set the amount (it cannot).

**Status**: No Action Required (Server-side validation is sufficient)

---

### 7. Event Security

#### Finding: Server Events Without Source Validation
**Severity**: MEDIUM
**Location**: `server/main.lua` - Lines 30-45, 48-58

**Description**:
Server events `custom_aimedic:chargePlayer` and `custom_aimedic:revivePlayer` accept a target parameter:
```lua
RegisterNetEvent('custom_aimedic:chargePlayer')
AddEventHandler('custom_aimedic:chargePlayer', function(target)
    local src = target or source
    -- Uses src without validating target
end)
```

**Impact**:
- Modified client could send target = <any_player_id>
- Players could charge or revive other players
- Potential for griefing or helping cheaters

**Recommendation**:
```lua
RegisterNetEvent('custom_aimedic:chargePlayer')
AddEventHandler('custom_aimedic:chargePlayer', function()
    local src = source -- Only use source, ignore any parameter
    -- ... rest of logic
end)

RegisterNetEvent('custom_aimedic:revivePlayer')
AddEventHandler('custom_aimedic:revivePlayer', function(target)
    local src = source
    if target ~= src and target ~= GetPlayerServerId(PlayerId()) then
        -- Log suspicious activity
        print('[AI Medic] WARNING: Player ' .. src .. ' attempted to revive player ' .. target)
        return
    end
    -- ... rest of logic
end)
```

**Status**: Not Fixed (Requires code change, documenting for user awareness)

---

### 8. Race Condition

#### Finding: isBeingRevived Flag Not Server-Synced
**Severity**: LOW
**Location**: `client/main.lua` - Line 1

**Description**:
The `isBeingRevived` flag is client-side only:
```lua
local isBeingRevived = false
```

**Impact**:
- Modified client could bypass this check
- Player could trigger multiple revives from different clients (if alt-tabbing)
- Server doesn't track revive state

**Recommendation**:
Add server-side tracking:
```lua
-- server/main.lua
local playersBeingRevived = {}

RegisterCommand('callmedic', function(source)
    if playersBeingRevived[source] then
        Utils.Notify(source, "You are already being revived!", "error")
        return
    end
    playersBeingRevived[source] = true
    -- ... trigger client event
end)

-- Clean up after revive completes
RegisterNetEvent('custom_aimedic:reviveComplete')
AddEventHandler('custom_aimedic:reviveComplete', function()
    playersBeingRevived[source] = nil
end)
```

**Status**: Not Fixed (Low impact, would require client code changes)

---

### 9. Network Event Flooding

#### Finding: No Rate Limiting on Network Events
**Severity**: MEDIUM
**Location**: All `RegisterNetEvent` handlers

**Description**:
Server events can be triggered rapidly by modified clients.

**Impact**:
- Server resource exhaustion
- Network flooding
- Potential DoS from single malicious client

**Recommendation**:
Implement rate limiting middleware:
```lua
local eventLimiter = {}
local EVENT_LIMIT = 5 -- max 5 calls per minute

function RateLimitEvent(source, eventName, callback)
    local key = source .. ":" .. eventName
    local currentTime = os.time()
    
    if not eventLimiter[key] then
        eventLimiter[key] = {count = 0, resetTime = currentTime + 60}
    end
    
    if currentTime > eventLimiter[key].resetTime then
        eventLimiter[key] = {count = 0, resetTime = currentTime + 60}
    end
    
    if eventLimiter[key].count >= EVENT_LIMIT then
        print('[AI Medic] Rate limit exceeded for ' .. source .. ' on ' .. eventName)
        return false
    end
    
    eventLimiter[key].count = eventLimiter[key].count + 1
    return callback()
end
```

**Status**: Not Fixed (Infrastructure change, beyond minimal scope)

---

## Additional Security Observations

### ✅ Good Security Practices Found

1. **Server-Side Money Handling**: Money removal is server-side only
2. **Framework Detection**: Proper checking for QBCore availability
3. **Timeout Mechanisms**: Prevents infinite waiting loops
4. **State Validation**: Checks if player is actually downed before reviving
5. **EMS Count Check**: Prevents interference with real players
6. **Entity Cleanup**: Properly deletes spawned entities

### ⚠️ Potential Issues Not Classified as Vulnerabilities

1. **Console Logging**: Extensive logging could be performance issue
2. **Hardcoded Values**: Some values like timeout durations are hardcoded
3. **No Encryption**: Events are plain text (standard for FiveM)
4. **Global Variables**: Utils is global (standard Lua pattern)

---

## Risk Assessment Matrix

| Finding | Severity | Likelihood | Impact | Priority |
|---------|----------|------------|--------|----------|
| No Command Cooldown | MEDIUM | HIGH | MEDIUM | HIGH |
| Client-Side Spawning | MEDIUM-HIGH | MEDIUM | HIGH | HIGH |
| Event Parameter Injection | MEDIUM | MEDIUM | MEDIUM | MEDIUM |
| No Permission Check | LOW-MEDIUM | LOW | LOW | LOW |
| Rate Limiting | MEDIUM | MEDIUM | MEDIUM | MEDIUM |
| Race Condition | LOW | LOW | LOW | LOW |
| Input Validation | LOW | LOW | LOW | LOW |
| Resource Cleanup | LOW | HIGH | LOW | LOW |

---

## Recommendations Summary

### High Priority (Should Fix)
1. ✅ **Add command cooldown system** - Prevents spam and griefing
2. ✅ **Fix event source validation** - Prevents cross-player exploitation
3. ✅ **Consider server-side entity spawning** - Better control and security

### Medium Priority (Consider Fixing)
4. ⚠️ **Add rate limiting to network events** - Prevents DoS
5. ⚠️ **Add server-side revive state tracking** - Prevents race conditions

### Low Priority (Nice to Have)
6. ⚠️ **Add coordinate validation** - Prevents edge case bugs
7. ⚠️ **Add model cleanup** - Memory optimization
8. ⚠️ **Add permission system** - Better access control

---

## Compliance & Standards

### FiveM Security Guidelines: PARTIAL
- ✅ Server-side validation for critical operations (money)
- ❌ No rate limiting on events
- ❌ Client-side entity spawning
- ✅ Proper resource cleanup

### OWASP Top 10 (Adapted for Game Scripts)
- ✅ A01:2021 – Broken Access Control: **PARTIAL** (no permission system)
- ✅ A02:2021 – Cryptographic Failures: **N/A** (no sensitive data)
- ✅ A03:2021 – Injection: **GOOD** (no SQL/command injection vectors)
- ❌ A04:2021 – Insecure Design: **NEEDS IMPROVEMENT** (client-side spawning)
- ✅ A05:2021 – Security Misconfiguration: **GOOD** (proper defaults)

---

## Conclusion

The AI Medic script is a **functional and generally safe resource** for FiveM servers, but it follows common patterns that can be abused by malicious actors. The main security concerns are:

1. **Spam/Griefing Potential**: Lack of cooldowns allows abuse
2. **Client Trust**: Too much logic on client-side (entity spawning)
3. **Event Security**: Some events accept parameters that could be manipulated

**For Production Use**: 
- ✅ Safe for casual/whitelisted servers
- ⚠️ Add cooldowns before public server deployment
- ❌ Needs hardening for servers with known cheater/modder presence

**Overall Security Score**: 6.5/10
- The script won't cause server crashes or data breaches
- It can be abused for griefing without additional protections
- Recommended to implement high-priority fixes before public use

---

## Monitoring Recommendations

To detect abuse in production:

1. **Log all `/callmedic` command usage with timestamps**
2. **Alert on rapid event triggering from same source**
3. **Monitor entity count for unusual spikes**
4. **Track money removal failures (potential exploit attempts)**
5. **Review server logs for WARNING messages**

---

## References

- FiveM Documentation: https://docs.fivem.net/
- FiveM Server Security Guide: https://docs.fivem.net/docs/server-manual/security/
- Lua Security Patterns: https://www.lua.org/manual/5.4/
- GTA V Natives Reference: https://docs.fivem.net/natives/

---

**Report Generated**: 2025-12-15
**Analyst**: Automated Security Review
**Script Version**: 1.5.0
**Review Method**: Manual Code Analysis (CodeQL N/A for Lua)
