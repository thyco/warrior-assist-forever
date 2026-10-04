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

local function update(entry, refreshGeometry)
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
        local animationChanged = entry.startAnim ~= startAnim
        if entry.active and animationChanged and not startAnim then
            -- Hide stops both animations without returning our reserved effect
            -- to the shared library pool. The next start selects the loop.
            entry.effect:Hide()
        end

        if not entry.active or animationChanged or not sameColor(entry.color, color) or refreshGeometry then
            -- Updating the shown effect changes tint without replaying OnShow.
            library.ProcGlow_Start(entry.frame, { key = glowKey, startAnim = startAnim, color = color })
        end

        if not entry.active then
            entry.frame:Show()
        end
    elseif entry.active then
        entry.effect:Hide()
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

function Glow.RefreshGeometry(button)
    local entry = entries[button]
    if entry and entry.active then
        update(entry, true)
    end
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

    -- ProcGlow_Start allocates the effect, textures, and animation groups lazily.
    -- Keep that effect attached for this overlay's lifetime: releasing it would
    -- let another addon consume the pool entry before our next combat reminder.
    library.ProcGlow_Start(frame, { key = glowKey, startAnim = false })
    local effect = frame["_ProcGlow" .. glowKey]
    effect:Hide()

    local entry = { frame = frame, effect = effect, owners = {}, active = false }
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
