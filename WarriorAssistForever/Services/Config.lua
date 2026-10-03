local _, addon = ...
local Config = {}
addon.Config = Config

local defaults = {
    battleShoutEnabled = true,
    leadSeconds = 10,
    glowColor = "ff00ff00",
    iconX = 0,
    iconY = -270,
    overpowerEnabled = true,
    overpowerBar = 0,
    overpowerButton = 1,
    revengeEnabled = true,
    revengeBar = 0,
    revengeButton = 1,
}
local values
local listeners = {}

local function validValue(key, value)
    if issecretvalue and issecretvalue(value) then
        return false
    end

    if type(value) ~= type(defaults[key]) then
        return false
    end

    if key == "overpowerBar" or key == "revengeBar" then
        return value >= 0 and value <= 8 and value == math.floor(value)
    end

    if key == "overpowerButton" or key == "revengeButton" then
        return value >= 1 and value <= 12 and value == math.floor(value)
    end

    if key == "leadSeconds" then
        return value >= 1 and value <= 60 and value == math.floor(value)
    end

    if key == "glowColor" then
        return #value == 8 and value:match("^%x+$") ~= nil
    end

    if key == "iconX" or key == "iconY" then
        return value == value and value >= -4096 and value <= 4096
    end

    return true
end

local function normalize(key, value)
    if key == "glowColor" then
        return "ff" .. value:sub(3):lower()
    end

    return value
end

function Config.Initialize()
    if type(WarriorAssistForeverDB) ~= "table" then
        WarriorAssistForeverDB = {}
    end

    values = WarriorAssistForeverDB

    for key, default in pairs(defaults) do
        if validValue(key, values[key]) then
            values[key] = normalize(key, values[key])
        else
            values[key] = default
        end
    end
end

function Config.GetDefault(key)
    return defaults[key]
end

function Config.Get(key)
    if values and values[key] ~= nil then
        return values[key]
    end

    return defaults[key]
end

function Config.GetColor(key)
    local hex = Config.Get(key)
    return {
        tonumber(hex:sub(3, 4), 16) / 255,
        tonumber(hex:sub(5, 6), 16) / 255,
        tonumber(hex:sub(7, 8), 16) / 255,
        1,
    }
end

function Config.Set(key, value)
    assert(defaults[key] ~= nil, "Unknown configuration key: " .. tostring(key))
    assert(validValue(key, value), "Invalid configuration value: " .. key)

    value = normalize(key, value)

    if not values then
        Config.Initialize()
    end

    if values[key] == value then
        return
    end

    values[key] = value

    for _, listener in ipairs(listeners) do
        listener(key, value)
    end
end

function Config.Subscribe(listener)
    listeners[#listeners + 1] = listener
end
