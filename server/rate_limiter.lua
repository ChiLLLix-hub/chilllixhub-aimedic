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
