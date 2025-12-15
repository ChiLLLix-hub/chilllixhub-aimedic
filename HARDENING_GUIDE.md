# Public Deployment Hardening Guide

This guide provides **production-ready implementations** to secure the AI Medic script for public FiveM servers. These changes address the high and medium priority security findings.

## 🎯 Quick Start

For public deployment, you **must** implement at minimum:
1. ✅ Command cooldown system
2. ✅ Event source validation
3. ✅ Server-side revive state tracking

**Recommended time to implement**: 30-60 minutes

---

## 🔴 Critical Fixes (MUST IMPLEMENT)

### 1. Command Cooldown System

**Problem**: Players can spam `/callmedic` causing server lag and griefing.

**Solution**: Add cooldown tracking on server-side.

**File**: `server/main.lua`

**Replace the entire RegisterCommand block** (lines 1-28) with:

```lua
-- Cooldown tracking
local commandCooldowns = {}
local COOLDOWN_TIME = 60 -- 60 seconds between uses
local MAX_USES_PER_HOUR = 5 -- Maximum uses per hour

-- Usage tracking for abuse detection
local usageTracking = {}

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

RegisterCommand('callmedic', function(source)
    local currentTime = os.time()
    
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

    local ped = GetPlayerPed(source)
    local coords = GetEntityCoords(ped)
    if not coords then
        print('[AI Medic] Failed to get coords for source: ' .. source)
        Utils.Notify(source, "Error: Could not get your location.", "error")
        return
    end
    
    -- Set cooldown BEFORE triggering (prevents double-tapping)
    commandCooldowns[source] = currentTime
    
    print('[AI Medic] Triggering revivePlayer for source: ' .. source .. ' at coords: ' .. tostring(coords))
    TriggerClientEvent('custom_aimedic:revivePlayer', source, coords)
end, false)
```

**What this does**:
- ✅ 60-second cooldown between uses
- ✅ Maximum 5 uses per hour
- ✅ Auto-cleanup of old data
- ✅ Abuse detection logging
- ✅ Prevents double-tapping

---

### 2. Event Source Validation

**Problem**: Modified clients could charge or revive other players.

**Solution**: Always use `source` instead of trusting client parameters.

**File**: `server/main.lua`

**Replace the chargePlayer event handler** (lines 30-45) with:

```lua
RegisterNetEvent('custom_aimedic:chargePlayer')
AddEventHandler('custom_aimedic:chargePlayer', function()
    local src = source -- ALWAYS use source, never trust parameters
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
```

**Replace the revivePlayer event handler** (lines 48-58) with:

```lua
-- Custom revive event for standalone mode
RegisterNetEvent('custom_aimedic:revivePlayer')
AddEventHandler('custom_aimedic:revivePlayer', function(target)
    local src = source
    
    -- SECURITY: Only allow players to revive themselves
    if target ~= src then
        print('[AI Medic] SECURITY WARNING: Player ' .. src .. ' attempted to revive player ' .. target .. ' - BLOCKED')
        -- Log this to your admin system
        TriggerEvent('aimedic:logSecurityViolation', src, target)
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
```

**What this does**:
- ✅ Prevents cross-player exploitation
- ✅ Logs security violations
- ✅ Server validates all requests

---

### 3. Server-Side Revive State Tracking

**Problem**: No server-side tracking allows multiple simultaneous revives.

**Solution**: Track revive state on server.

**File**: `server/main.lua`

**Add at the top of the file** (after the Utils initialization):

```lua
-- Server-side revive state tracking
local playersBeingRevived = {}

-- Cleanup disconnected players
AddEventHandler('playerDropped', function()
    local src = source
    if playersBeingRevived[src] then
        playersBeingRevived[src] = nil
        print('[AI Medic] Cleaned up revive state for disconnected player: ' .. src)
    end
end)

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

-- Timeout check (cleanup stuck revives after 2 minutes)
CreateThread(function()
    while true do
        Wait(30000) -- Check every 30 seconds
        local currentTime = os.time()
        for player, startTime in pairs(playersBeingRevived) do
            if currentTime - startTime > 120 then -- 2 minutes
                playersBeingRevived[player] = nil
                print('[AI Medic] Cleaned up stuck revive state for player: ' .. player)
            end
        end
    end
end)
```

**Modify the callmedic command** to check state (add after coords validation):

```lua
    -- Check if already being revived (add after coords check, before triggering event)
    local canRevive, message = StartReviveProcess(source)
    if not canRevive then
        Utils.Notify(source, message, "error")
        return
    end
    
    print('[AI Medic] Triggering revivePlayer for source: ' .. source .. ' at coords: ' .. tostring(coords))
    TriggerClientEvent('custom_aimedic:revivePlayer', source, coords)
```

**Add cleanup event** (add at the end of server/main.lua):

```lua
-- Client notifies when revive is complete
RegisterNetEvent('custom_aimedic:reviveComplete')
AddEventHandler('custom_aimedic:reviveComplete', function()
    local src = source
    EndReviveProcess(src)
    print('[AI Medic] Revive completed for player: ' .. src)
end)
```

**Update client/main.lua** (add at the end, line 140):

```lua
    DeleteEntity(medic)
    DeleteEntity(vehicle)
    isBeingRevived = false
    TriggerServerEvent('custom_aimedic:reviveComplete') -- Add this line
end)
```

**What this does**:
- ✅ Prevents multiple simultaneous revives
- ✅ Auto-cleanup on disconnect
- ✅ Timeout handling for stuck states
- ✅ Server-authoritative state

---

## 🟡 Recommended Fixes (SHOULD IMPLEMENT)

### 4. Rate Limiting on Network Events

**Problem**: Clients can spam network events.

**Solution**: Add rate limiter wrapper.

**File**: Create new file `server/rate_limiter.lua`

```lua
-- Simple rate limiter for network events
RateLimiter = {}
RateLimiter.limits = {}

function RateLimiter.CheckLimit(source, eventName, maxCalls, windowSeconds)
    local key = source .. ":" .. eventName
    local currentTime = os.time()
    
    if not RateLimiter.limits[key] then
        RateLimiter.limits[key] = {
            calls = {},
            blocked = false
        }
    end
    
    local data = RateLimiter.limits[key]
    
    -- Remove old calls outside the window
    local newCalls = {}
    for _, callTime in ipairs(data.calls) do
        if currentTime - callTime < windowSeconds then
            table.insert(newCalls, callTime)
        end
    end
    data.calls = newCalls
    
    -- Check if limit exceeded
    if #data.calls >= maxCalls then
        if not data.blocked then
            data.blocked = true
            print('[AI Medic] RATE LIMIT: Player ' .. source .. ' exceeded limit for ' .. eventName)
        end
        return false
    end
    
    -- Record this call
    table.insert(data.calls, currentTime)
    data.blocked = false
    return true
end

-- Cleanup old data every 5 minutes
CreateThread(function()
    while true do
        Wait(300000)
        local currentTime = os.time()
        for key, data in pairs(RateLimiter.limits) do
            local newCalls = {}
            for _, callTime in ipairs(data.calls) do
                if currentTime - callTime < 300 then -- Keep last 5 minutes
                    table.insert(newCalls, callTime)
                end
            end
            if #newCalls == 0 then
                RateLimiter.limits[key] = nil
            else
                data.calls = newCalls
            end
        end
    end
end)
```

**Update fxmanifest.lua** to include the rate limiter:

```lua
server_scripts {
    'server/rate_limiter.lua', -- Add this line FIRST
    'server/main.lua',
    'server/utils_server.lua'
}
```

**Wrap your events** in server/main.lua:

```lua
RegisterNetEvent('custom_aimedic:chargePlayer')
AddEventHandler('custom_aimedic:chargePlayer', function()
    local src = source
    
    -- Rate limit: max 3 calls per minute
    if not RateLimiter.CheckLimit(src, 'chargePlayer', 3, 60) then
        print('[AI Medic] Player ' .. src .. ' rate limited on chargePlayer')
        return
    end
    
    -- ... rest of handler
end)
```

**What this does**:
- ✅ Prevents event flooding
- ✅ Configurable limits per event
- ✅ Auto-cleanup
- ✅ Logging of violations

---

### 5. Input Validation

**Problem**: No validation of coordinates.

**Solution**: Add coordinate sanity checks.

**File**: `server/main.lua`

Add this function at the top:

```lua
-- Validate coordinates are within reasonable bounds
function ValidateCoordinates(coords)
    if not coords then return false end
    if type(coords) ~= 'vector3' then return false end
    
    -- GTA V map bounds (approximately)
    if coords.x < -4000 or coords.x > 4000 then return false end
    if coords.y < -4000 or coords.y > 4000 then return false end
    if coords.z < -100 or coords.z > 1000 then return false end
    
    return true
end
```

Use in callmedic command:

```lua
    local coords = GetEntityCoords(ped)
    if not ValidateCoordinates(coords) then
        print('[AI Medic] Invalid coords for source: ' .. source .. ' - ' .. tostring(coords))
        Utils.Notify(source, "Invalid location for medic service.", "error")
        return
    end
```

---

## 🟢 Optional Improvements

### 6. Admin Permission System

**File**: `server/main.lua`

```lua
-- Optional: Add to server.cfg to grant all players access by default
-- add_ace group.user aimedic.use allow

RegisterCommand('callmedic', function(source)
    -- Optional permission check
    if not IsPlayerAceAllowed(source, "aimedic.use") then
        Utils.Notify(source, "You don't have permission to use AI medic.", "error")
        print('[AI Medic] Permission denied for player: ' .. source)
        return
    end
    
    -- ... rest of code
end, false)
```

---

### 7. Enhanced Logging

**File**: Create `server/logging.lua`

```lua
-- Enhanced logging system
AIMedicLogs = {}

function AIMedicLogs.LogUsage(source, action, details)
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    local logEntry = string.format('[%s] Player %d - %s - %s', timestamp, source, action, details or '')
    print(logEntry)
    
    -- Optional: Save to file or database
    -- SaveLog(logEntry)
end

function AIMedicLogs.LogSecurity(source, violation, details)
    local timestamp = os.date('%Y-%m-%d %H:%M:%S')
    local logEntry = string.format('[%s] SECURITY: Player %d - %s - %s', timestamp, source, violation, details or '')
    print(logEntry)
    
    -- Optional: Alert admins
    -- TriggerEvent('admin:alert', logEntry)
end
```

Add to fxmanifest.lua and use throughout code.

---

## 📋 Implementation Checklist

### For Production Deployment:

- [ ] Implement command cooldown system (Critical)
- [ ] Fix event source validation (Critical)
- [ ] Add server-side revive state tracking (Critical)
- [ ] Add rate limiting on network events (Recommended)
- [ ] Add coordinate validation (Recommended)
- [ ] Configure admin permissions (Optional)
- [ ] Set up enhanced logging (Optional)
- [ ] Test all changes on dev server
- [ ] Monitor logs for abuse after deployment

### Testing Steps:

1. **Test Cooldown**: Try calling `/callmedic` twice quickly
2. **Test Rate Limiting**: Spam events (needs modified client to test properly)
3. **Test State Tracking**: Disconnect during revive
4. **Test Validation**: Try invalid coordinates (edge of map)
5. **Monitor Logs**: Watch for security warnings

---

## 📊 Configuration Values

Adjust these in the code based on your server:

```lua
-- Cooldown settings
local COOLDOWN_TIME = 60        -- Seconds between uses (default: 60)
local MAX_USES_PER_HOUR = 5     -- Max uses per hour (default: 5)

-- Rate limiting
maxCalls = 3                    -- Max event calls (default: 3)
windowSeconds = 60              -- Time window (default: 60)

-- Coordinate validation
min_x, max_x = -4000, 4000     -- Map bounds X
min_y, max_y = -4000, 4000     -- Map bounds Y
min_z, max_z = -100, 1000      -- Map bounds Z
```

**Recommended for different server types**:

| Server Type | COOLDOWN_TIME | MAX_USES_PER_HOUR | Rate Limit |
|-------------|---------------|-------------------|------------|
| Private/Whitelist | 30 | 10 | 5/min |
| Public (Low Traffic) | 60 | 5 | 3/min |
| Public (High Traffic) | 90 | 3 | 2/min |
| Hardcore RP | 120 | 2 | 1/min |

---

## 🔍 Monitoring

After deployment, monitor these:

```bash
# Watch for rate limiting
grep "RATE LIMIT" server.log

# Watch for security violations
grep "SECURITY WARNING" server.log

# Watch for excessive usage
grep "exceeded hourly limit" server.log

# Count total medic calls
grep "callmedic command triggered" server.log | wc -l
```

---

## 🚨 Security Incident Response

If you detect abuse:

1. **Immediate**: Check logs for player ID
2. **Investigate**: Review their usage patterns
3. **Action**: Temporarily revoke `aimedic.use` permission
4. **Long-term**: Adjust rate limits if needed

---

## ✅ Verification

After implementing changes, verify:

```lua
-- Test script (run in server console)
-- This should fail with cooldown message:
callmedic
-- Wait 5 seconds
callmedic
-- Should see "Please wait X seconds"
```

---

## 📞 Support

If you encounter issues:
1. Check server console for error messages
2. Verify all files are updated correctly
3. Ensure fxmanifest.lua includes all new files
4. Review the SECURITY_ANALYSIS.md for detailed explanations

---

**Estimated Security Improvement**: From 6.5/10 to 8.5/10 with all critical and recommended fixes implemented.

**Time to Implement**: 
- Critical fixes only: 30 minutes
- All recommended: 60 minutes
- Optional improvements: +30 minutes

---

**Last Updated**: 2025-12-15
**For Script Version**: 1.5.0
**Hardening Version**: 1.0
