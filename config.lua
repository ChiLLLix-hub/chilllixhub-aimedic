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

-- Hospital locations for patient transport
Config.Hospitals = {
    city = vector3(308.24, -592.42, 43.28),
    sandy = vector3(1828.52, 3673.22, 34.28),
    paleto = vector3(-247.76, 6331.23, 32.43),
    default = vector3(293.0, -582.0, 43.0)
}

