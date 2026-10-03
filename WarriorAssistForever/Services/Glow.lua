local _, addon = ...
local Glow = {}
local library = LibStub("LibCustomGlow-1.0")
local glowKey = "WarriorAssistForever"
addon.Glow = Glow

-- State lives here, never on Blizzard's protected action buttons.
local entries = {}
local appearanceColor

local ownerStyles = {}

local function sameColor(first, second)
    if first == second then
        return true
    end

    if not first or not second then
        return false
    end

    for index = 1, 4 do
        if first[index] ~= second[index] then
            return false
        end
    end

    return true
end

local function update(entry)
    local selectedOwner
    local priority
    for owner in pairs(entry.owners) do
        local style = ownerStyles[owner]
        local candidate = style and style.priority or 0
        if priority == nil or candidate > priority
            or (candidate == priority and owner < selectedOwner) then
            selectedOwner = owner
            priority = candidate
        end
    end

    local wanted = selectedOwner ~= nil
    local request = selectedOwner and entry.owners[selectedOwner]
    local startAnim = not request or request.startAnim
    local style = selectedOwner and ownerStyles[selectedOwner]
    local color = appearanceColor
    if style then
        color = style.color
    end

    if wanted then
        if not entry.active then
            entry.frame:Show()
        end

        local animationChanged = entry.startAnim ~= startAnim
        if entry.active and animationChanged and not startAnim then
            -- Restart through the public library API to cancel any in-flight
            -- startup flash and go directly to the loop. This occurs once.
            library.ProcGlow_Stop(entry.frame, glowKey)
        end

        if not entry.active or animationChanged or not sameColor(entry.color, color) then
            -- Updating the shown effect changes tint without replaying OnShow.
            library.ProcGlow_Start(entry.frame, { key = glowKey, startAnim = startAnim, color = color })
        end
    elseif entry.active then
        library.ProcGlow_Stop(entry.frame, glowKey)
        entry.frame:Hide()
    end

    entry.active = wanted
    entry.color = color
    entry.startAnim = startAnim
end

local function copyColor(color)
    return color and { color[1], color[2], color[3], color[4] } or nil
end

-- Default appearance for owners without an explicit style.
function Glow.Configure(options)
    appearanceColor = copyColor(options.color)
    for _, entry in pairs(entries) do
        update(entry)
    end
end

-- Higher priority wins when features share a button; ties use the owner name.
-- A nil color explicitly selects native artwork rather than inheriting a tint.
function Glow.ConfigureOwner(owner, options)
    ownerStyles[owner] = { color = copyColor(options.color), priority = options.priority or 0 }
    for _, entry in pairs(entries) do
        update(entry)
    end
end

function Glow.IsPrepared(button)
    return entries[button] ~= nil
end

function Glow.Prepare(button)
    if entries[button] then
        return entries[button]
    end

    -- Prepare default buttons on login and after combat, including empty ones.
    if InCombatLockdown() then
        return nil
    end

    local frame = CreateFrame("Frame", nil, button)
    frame:SetAllPoints(button)
    frame:SetFrameLevel(button:GetFrameLevel() + 6)
    frame:EnableMouse(false)

    frame:Hide()

    local entry = { frame = frame, owners = {}, active = false }
    entries[button] = entry
    return entry
end

function Glow.Set(button, owner, active, options)
    local entry = entries[button]
    if not entry and active then
        entry = Glow.Prepare(button)
    end

    if not entry then
        return
    end

    entry.owners[owner] = active and { startAnim = not options or options.startAnim ~= false } or nil
    update(entry)
end

function Glow.ClearOwner(owner)
    for button in pairs(entries) do
        Glow.Set(button, owner, false)
    end
end
