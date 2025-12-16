Config = {}

-- Models
Config.MedicModel = 's_m_m_paramedic_01' -- Fallback: 's_m_m_doctor_01'
Config.AmbulanceModel = 'Ambulance'

-- Behavior
Config.ReviveDelay = 10000 -- Time for medic to "treat" player (ms)
Config.Fee = 500 -- Cost of EMS service
Config.MaxEMSOnline = 5 -- Max online EMS before AI medic is disabled

-- Multi-Player AI Medic Settings
Config.MaxActiveAIMedics = 2 -- Max AI medics active server-wide
Config.NearbyPlayerRadius = 50.0 -- Meters to check for nearby downed players
Config.MaxPatientsPerMedic = 5 -- Max players one medic can handle
Config.TreatmentTimePerPlayer = 10000 -- Time to treat each player (ms)

-- Hospital bed locations for patient teleport after revival
Config.HospitalBeds = {
    {coords = vector3(356.73, -585.27, 43.31), heading = 252.0}, -- Pillbox Hill Medical Center
    {coords = vector3(353.14, -584.55, 43.31), heading = 252.0},
    {coords = vector3(349.76, -583.81, 43.31), heading = 252.0},
    {coords = vector3(346.19, -583.04, 43.31), heading = 252.0},
    {coords = vector3(335.70, -580.13, 43.31), heading = 252.0},
    {coords = vector3(332.21, -579.34, 43.31), heading = 252.0},
    {coords = vector3(328.61, -578.54, 43.31), heading = 252.0},
    {coords = vector3(325.06, -577.76, 43.31), heading = 252.0},
}

