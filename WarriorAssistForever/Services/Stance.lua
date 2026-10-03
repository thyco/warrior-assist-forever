local _, addon = ...
local Stance = {}
addon.Stance = Stance

local stanceNames = { [17] = "battle", [18] = "defensive", [19] = "berserker" }

function Stance.Current()
    if type(GetShapeshiftFormID) ~= "function" then
        return "unknown"
    end

    local ok, id = pcall(GetShapeshiftFormID)
    if not ok or not addon.Client.Number(id) then
        return "unknown"
    end

    return stanceNames[id] or "unknown"
end
