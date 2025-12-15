# AI Medic Script - Quick Reference

## What This Script Does

The **CES_AI_Medic_Script** is an autonomous emergency medical service (EMS) system for FiveM servers. When a player dies/is downed and real EMS players are unavailable, they can type `/callmedic` to summon an AI-controlled ambulance.

### Step-by-Step Operation:

1. **Player Dies** → Player is downed/dead in-game
2. **Player Types `/callmedic`** → Triggers the AI medic system
3. **Server Validates**:
   - Checks if too many real EMS players are online (max 5)
   - Gets player's location
4. **Ambulance Spawns** → AI ambulance spawns nearby with sirens
5. **Ambulance Arrives** → Drives to player's location (30s timeout)
6. **Medic Exits** → NPC medic leaves ambulance and walks to player
7. **Treatment** → Medic performs 10-second treatment animation
   - Shows progress bar
   - Displays cause of death in 3D text
8. **Payment** → Server charges player $500 (QBCore only)
9. **Revival** → Player is revived and healed
10. **Hospital Transport** → Player rides to nearest hospital
11. **Cleanup** → Medic and ambulance disappear

---

## Key Features

✅ **QBCore & Standalone Compatible**
- Works with or without QBCore framework
- Automatic detection and adaptation

✅ **Smart EMS Detection**
- Only activates when real EMS count is low
- Doesn't interfere with player roleplay

✅ **Full Animations**
- Medic treatment animations
- Medical bag prop
- Emergency vehicle lights and sirens

✅ **Hospital Transport**
- Automatically drives to nearest hospital
- Supports multiple hospital locations

✅ **Economy Integration**
- QBCore: Charges $500 from bank
- Standalone: Free service

---

## Configuration

**File**: `config.lua`

```lua
Config.MedicModel = 's_m_m_paramedic_01'  -- Medic NPC model
Config.AmbulanceModel = 'Ambulance'        -- Vehicle model
Config.ReviveDelay = 10000                 -- Treatment time (ms)
Config.Fee = 500                           -- Revival cost ($)
Config.MaxEMSOnline = 5                    -- Max EMS before AI disabled
Config.Hospitals = {                       -- Hospital locations
    city = vector3(308.24, -592.42, 43.28),
    sandy = vector3(1828.52, 3673.22, 34.28),
    paleto = vector3(-247.76, 6331.23, 32.43),
    default = vector3(293.0, -582.0, 43.0)
}
```

---

## File Structure

```
├── config.lua                 # Configuration settings
├── fxmanifest.lua            # Resource manifest
├── client/
│   ├── main.lua              # Main client logic (ambulance, animations)
│   └── utils_client.lua      # Client utilities (notifications, QBCore)
└── server/
    ├── main.lua              # Command registration, payment, revival
    └── utils_server.lua      # Server utilities (framework detection)
```

---

## Security Summary (CodeQL Review)

### CodeQL Status
❌ **Not Supported** - CodeQL does not analyze Lua code
✅ **Manual Review Completed** - See SECURITY_ANALYSIS.md for full details

### Security Rating: 6.5/10

**Safe for**: Casual servers, whitelisted servers, private communities
**Needs hardening for**: Public servers with known modders/cheaters

### Critical Findings:

🔴 **High Priority Issues**:
1. **No command cooldown** - Players can spam `/callmedic`
2. **Client-side entity spawning** - Modified clients can abuse
3. **Event parameter injection** - Players could target other players

🟡 **Medium Priority Issues**:
4. No rate limiting on network events
5. No server-side revive state tracking

🟢 **Low Priority Issues**:
6. No coordinate validation (edge cases)
7. Models not freed from memory
8. No permission system

### What Works Well:
✅ Server-side money handling
✅ Proper entity cleanup
✅ Framework detection
✅ State validation before revival
✅ Timeout mechanisms

---

## Quick Security Recommendations

### For Server Owners:

**Before Deployment**:
1. Add this to your admin panel to monitor usage:
   ```bash
   # Watch for spam
   grep "callmedic" server.log | tail -20
   ```

2. Consider adding ACE permission:
   ```cfg
   # In server.cfg
   add_ace group.user aimedic.use allow
   ```

**Monitor These**:
- Multiple `/callmedic` calls from same player within 60 seconds
- Unusual entity count spikes
- Failed money removal attempts (exploit indicators)

### For Developers:

**Quick Fixes** (Copy/Paste Ready):

1. **Add Command Cooldown**:
```lua
-- Add to server/main.lua
local commandCooldowns = {}
RegisterCommand('callmedic', function(source)
    local currentTime = os.time() * 1000
    if commandCooldowns[source] and currentTime - commandCooldowns[source] < 60000 then
        Utils.Notify(source, "Please wait before calling medic again.", "error")
        return
    end
    commandCooldowns[source] = currentTime
    -- ... existing code
end)
```

2. **Fix Event Security**:
```lua
-- Change in server/main.lua
RegisterNetEvent('custom_aimedic:chargePlayer')
AddEventHandler('custom_aimedic:chargePlayer', function()
    local src = source -- Don't accept target parameter
    -- ... existing code
end)
```

---

## Common Questions

**Q: Why isn't CodeQL working?**
A: CodeQL doesn't support Lua language. Manual security review was performed instead.

**Q: Is this safe for my server?**
A: Yes for private/whitelisted servers. Add cooldown protection for public servers.

**Q: Can players abuse this?**
A: Potentially - they can spam the command and grief. Add cooldown to prevent this.

**Q: Why do entities spawn client-side?**
A: Performance reasons, but this is less secure. Trade-off between performance and security.

**Q: Does this work without QBCore?**
A: Yes! It runs in standalone mode with basic functionality.

**Q: What happens if player disconnects during revival?**
A: Entities clean up automatically when player leaves. No memory leak.

**Q: Can I change the ambulance model?**
A: Yes, edit `Config.AmbulanceModel` in config.lua

---

## Troubleshooting

**Ambulance doesn't spawn**:
- Check models are valid: `s_m_m_paramedic_01`, `Ambulance`
- Verify player is actually downed/dead
- Check server console for errors

**Hospital transport fails**:
- ✅ Fixed! Hospitals now defined in config.lua
- Verify coordinates are valid vector3 values

**Payment not working**:
- Requires QBCore to be installed
- In standalone mode, service is free

**Medic gets stuck**:
- This is a GTA5 pathfinding issue
- Script has 30s timeout to prevent infinite waiting
- Medic will teleport cleanup after timeout

---

## Performance Notes

- **Memory**: ~2-5MB while active
- **Entity Count**: +2 entities during service (1 vehicle, 1 ped)
- **Network**: Minimal overhead (events only)
- **CPU**: Low impact (mostly uses GTA5 native tasks)

---

## For More Information

📄 **Detailed Operation Guide**: See `SCRIPT_OPERATION.md`
🔒 **Full Security Report**: See `SECURITY_ANALYSIS.md`
📖 **Installation Guide**: See `README.md`

---

## Credits

**Developer**: Crazy Eyes Studio
**Version**: 1.5.0
**Framework**: FiveM (GTA5)
**License**: See LICENSE file

---

**Last Updated**: 2025-12-15
**Documentation Version**: 1.0
