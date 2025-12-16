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
    {coords = vector3(357.38, -594.42, 42.88), heading = 340.3}, -- Pillbox Hill Medical Center
    {coords = vector3(354.23, -592.68, 42.87), heading = 340.0},
    {coords = vector3(350.72, -591.76, 42.87), heading = 340.0},
    {coords = vector3(346.91, -590.64, 42.87), heading = 340.0},
    {coords = vector3(360.42, -587.03, 42.87), heading = 160.0},
    {coords = vector3(356.74, -585.94, 42.87), heading = 160.0},
    {coords = vector3(353.24, -584.69, 42.87), heading = 160.0},
    {coords = vector3(349.69, -583.61, 42.87), heading = 160.0}
}

