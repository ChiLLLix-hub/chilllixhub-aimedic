# Multi-Player AI Medic Solution - Analysis & Recommendations

## Problem Statement

**Current Issue**: When multiple players die in the same area and each calls `/callmedic`, multiple AI ambulances spawn at the same location simultaneously, causing:
- Visual chaos (multiple ambulances stacked)
- Unrealistic gameplay
- Server resource waste
- Poor player experience

## Current Behavior

1. Player A dies at location X, calls `/callmedic` → Ambulance A spawns
2. Player B dies at location X, calls `/callmedic` → Ambulance B spawns
3. Player C dies at location X, calls `/callmedic` → Ambulance C spawns
4. **Result**: 3 ambulances at same spot, treating 1 player each

## Recommended Solutions

### 🥇 Solution 1: Single AI Medic Queue System (RECOMMENDED)

**Concept**: One AI medic serves multiple downed players in the area sequentially.

**How It Works**:
1. First player calls `/callmedic` → AI medic dispatched
2. Other nearby downed players are automatically added to queue
3. AI medic treats players one by one at their locations
4. System notifies players of their queue position
5. After treating all players, medic transports them together or sequentially

**Advantages**:
- ✅ Most realistic (like real EMS triage)
- ✅ Prevents ambulance chaos
- ✅ Resource efficient (1 medic for multiple patients)
- ✅ Better player experience (fair queue system)
- ✅ Implements proper triage logic

**Disadvantages**:
- ⚠️ Requires moderate code changes
- ⚠️ Players must wait in queue
- ⚠️ Complex if players are far apart

**Implementation Complexity**: Medium (2-3 hours)

---

### 🥈 Solution 2: Area-Based Medic Dispatch

**Concept**: Prevent multiple medics from being dispatched to the same area.

**How It Works**:
1. Server tracks active AI medic locations
2. When player calls `/callmedic`, check if medic already en route to area
3. If medic exists within radius (e.g., 100m), add player to that medic's list
4. If no medic nearby, spawn new one
5. Single medic can revive multiple players in same area

**Advantages**:
- ✅ Prevents duplicate dispatches
- ✅ Realistic area coverage
- ✅ Moderate complexity
- ✅ Works well for clustered deaths

**Disadvantages**:
- ⚠️ Complex radius calculation
- ⚠️ Edge cases (medic leaves area before treating all)
- ⚠️ May delay revives for some players

**Implementation Complexity**: Medium (2-3 hours)

---

### 🥉 Solution 3: Global AI Medic Limit

**Concept**: Limit total number of AI medics active server-wide.

**How It Works**:
1. Set maximum active AI medics (e.g., 2-3 server-wide)
2. Queue additional requests when limit reached
3. First-come, first-served dispatch
4. Players see "AI medic busy, you are #X in queue"

**Advantages**:
- ✅ Simple to implement
- ✅ Prevents server overload
- ✅ Fair queue system
- ✅ Works for any scenario

**Disadvantages**:
- ⚠️ May cause long waits during mass casualties
- ⚠️ Doesn't solve local clustering
- ⚠️ Less realistic (doesn't prioritize nearby players)

**Implementation Complexity**: Low (1 hour)

---

### 🔧 Solution 4: Shared Ambulance System

**Concept**: Multiple nearby players share one ambulance ride to hospital.

**How It Works**:
1. First player calls → AI medic spawns
2. Nearby downed players can join the same ambulance
3. Medic treats all at once (group revival)
4. All players transported together to hospital
5. Single ambulance handles entire incident

**Advantages**:
- ✅ Very realistic (actual EMS response)
- ✅ Great player experience (collaborative)
- ✅ Prevents ambulance spam
- ✅ Efficient resource usage

**Disadvantages**:
- ⚠️ Complex synchronization
- ⚠️ Vehicle seating limitations
- ⚠️ Timing issues (what if players die at different times)

**Implementation Complexity**: High (4-5 hours)

---

### 💡 Solution 5: Notification + Manual Join

**Concept**: Notify nearby downed players that AI medic is coming, let them opt-in.

**How It Works**:
1. Player A calls `/callmedic` → AI medic spawns
2. Server notifies nearby downed players: "AI medic en route nearby, type /joinmedic to share"
3. Players can opt-in to share the medic
4. Medic treats all opted-in players
5. Players who don't join wait for their own medic

**Advantages**:
- ✅ Player choice/control
- ✅ Simple notification system
- ✅ Prevents unwanted grouping
- ✅ Fair and transparent

**Disadvantages**:
- ⚠️ Requires player action (may miss notification if downed)
- ⚠️ Some players may not understand system
- ⚠️ Could still have some duplicate ambulances

**Implementation Complexity**: Low-Medium (1-2 hours)

---

## 🎯 Final Recommendation

**Best Solution**: **Combination of Solutions 1 + 3**

### Hybrid Approach: "Smart Queue + Global Limit"

**Implementation**:
1. **Global Limit**: Maximum 2 active AI medics server-wide
2. **Area Detection**: When player calls, check for nearby downed players (50m radius)
3. **Smart Dispatch**:
   - If nearby players found → Dispatch ONE medic to treat all
   - If no nearby players → Dispatch individual medic
   - If limit reached → Queue the request
4. **Queue Notifications**: Players see their position and estimated wait time
5. **Sequential Treatment**: Medic treats nearby players one after another

**Why This Is Best**:
- ✅ Realistic (EMS triage + multiple patients)
- ✅ Prevents chaos (max 2 ambulances on server)
- ✅ Efficient (one medic for clustered incidents)
- ✅ Fair (queue system for high demand)
- ✅ Good UX (players know what's happening)
- ✅ Moderate complexity (achievable in 2-3 hours)

---

## Implementation Details for Recommended Solution

### Configuration Variables
```lua
Config.MaxActiveAIMedics = 2 -- Max AI medics active server-wide
Config.NearbyPlayerRadius = 50.0 -- Meters to check for nearby downed players
Config.MaxPatientsPerMedic = 5 -- Max players one medic can handle
Config.TreatmentTimePerPlayer = 10000 -- Time to treat each player (ms)
```

### Server-Side Changes
1. Track active AI medics globally
2. Track medic assignments (which medic handles which players)
3. Area detection system (find nearby downed players)
4. Queue management for overflow requests
5. Smart dispatch logic

### Client-Side Changes
1. Handle queue notifications
2. Support multi-player treatment sequence
3. Update UI to show queue position

### Player Experience
```
Scenario: 3 players die at same location

Player 1 calls /callmedic:
→ "AI medic dispatched! Nearby patients detected (2). ETA: 30 seconds"

Player 2 tries /callmedic:
→ "AI medic already en route to your location. You will be treated shortly."

Player 3 tries /callmedic:
→ "AI medic already en route to your location. You will be treated shortly."

Medic arrives:
→ Treats Player 1 (10s)
→ Moves to Player 2 (10s)
→ Moves to Player 3 (10s)
→ Loads all 3 into ambulance
→ Drives to hospital
```

---

## Quick Fix (Immediate Implementation)

If you need a quick solution NOW, implement **Solution 3: Global Limit**

```lua
-- Add to server/main.lua
local activeAIMedics = 0
local MAX_ACTIVE_MEDICS = 2
local medicQueue = {}

-- Modify callmedic command
RegisterCommand('callmedic', function(source)
    -- ... existing validation ...
    
    if activeAIMedics >= MAX_ACTIVE_MEDICS then
        table.insert(medicQueue, source)
        Utils.Notify(source, "All AI medics are busy. You are #" .. #medicQueue .. " in queue.", "error")
        return
    end
    
    activeAIMedics = activeAIMedics + 1
    -- ... spawn medic ...
end)

-- When medic completes
RegisterNetEvent('custom_aimedic:reviveComplete')
AddEventHandler('custom_aimedic:reviveComplete', function()
    -- ... existing code ...
    
    activeAIMedics = activeAIMedics - 1
    
    -- Process queue
    if #medicQueue > 0 then
        local nextPlayer = table.remove(medicQueue, 1)
        Utils.Notify(nextPlayer, "AI medic is now available! Dispatching...", "success")
        -- Trigger medic for queued player
    end
end)
```

This takes 15 minutes to implement and solves 70% of the problem.

---

## Question for You

Before I implement, please choose:

**A)** Implement the **Quick Fix** (Global Limit) - 15 minutes, prevents chaos immediately

**B)** Implement the **Recommended Solution** (Smart Queue + Area Detection) - 2-3 hours, full solution

**C)** Implement a **Different Solution** from the list above

**D)** **Discuss further** - you want to modify one of the approaches

Let me know which approach you prefer, and I'll implement it right away!

---

## Additional Considerations

### Edge Cases to Handle
1. What if player disconnects while in queue?
2. What if player is revived by real EMS while waiting for AI?
3. What if players are spread across large area (treat all or split)?
4. Should there be a timeout for queue (cancel after X minutes)?

### Future Enhancements
- Priority system (critical injuries first)
- Multiple pickup locations (medic picks optimal route)
- Hospital selection based on closest to all patients
- Team-based priority (revive squad members first)

---

**Decision needed from @ChiLLLix-hub**: Which solution should I implement?
