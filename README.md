CES_AI_Medic_Script
A fully autonomous AI Medic system for FiveM, compatible with QBCore and Standalone frameworks. This script detects when EMS are unavailable and sends a medic NPC to revive the player at their location, complete with animations, a medbag prop, and instant revival!

🧠 Features ✅ QBCore and Standalone compatible

🚨 Call AI EMS when no EMS are online 🧍 AI Medic spawns near you (no ambulance vehicle needed) 💉 Custom revival animations and medbag prop 💵 Configurable revive cost 🏥 Revives player at their downed location (no hospital teleport) 💬 Displays cause of death in 3D text 🔊 Notifications with chat fallback

🔧 Configuration

Config.MedicModel = 's_m_m_paramedic_01'
Config.ReviveDelay = 10000
Config.Fee = 500
Config.MaxEMSOnline = 5
📦 Installation Place the resource in your resources folder.

Add to server.cfg: ensure CES_AI_Medic

Dependencies Optional: qb-core (for full integration with QBCore framework)

🧪 Notes Automatically checks EMS online count and disables AI if real medics are available. Works out of the box in standalone mode—QBCore is optional. You can adjust the script to your preferred animation, models, and logic easily.

Credits Developed by Crazy Eyes Studio