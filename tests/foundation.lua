local H = dofile("tests/helpers.lua")
local world = H.new()
local addon = world:load({ "Core", "Services/Config", "Services/Client", "Services/Timers" })

addon.Config.Initialize()
H.equal(addon.Config.Get("leadSeconds"), 10)
H.equal(addon.Config.Get("glowColor"), "ff00ff00")
H.equal(addon.Config.Get("iconX"), 0)
H.equal(addon.Config.Get("iconY"), -270)

local timer = addon.Timers.New()
timer:StartFrom(0, 180, "estimated")
world.time = 169.9
H.equal(timer:IsDue(10), false)
world.time = 170
H.equal(timer:IsDue(10), true)
H.equal(timer:Quality(), "estimated")
H.equal(timer:Remaining(), 10)

timer:SetDeadline(200, "exact")
H.equal(timer:Quality(), "exact")
H.equal(timer:IsDue(10), false)
timer:Clear()
H.equal(timer:Remaining(), nil)
H.equal(timer:IsDue(10), false)

local invalid = H.new()
invalid.env.WarriorAssistForeverDB = { leadSeconds = 61, glowColor = "bad", iconX = math.huge }
local other = invalid:load({ "Core", "Services/Config", "Services/Client", "Services/Timers" })
other.Config.Initialize()
H.equal(other.Config.Get("leadSeconds"), 10)
H.equal(other.Config.Get("glowColor"), "ff00ff00")
H.equal(other.Config.Get("iconX"), 0)

local changes = 0
other.Config.Subscribe(function(key, value)
    changes = changes + 1
    H.equal(key, "leadSeconds")
    H.equal(value, 15)
end)
other.Config.Set("leadSeconds", 15)
H.equal(changes, 1)
H.equal(other.Config.Get("leadSeconds"), 15)

local color = other.Config.GetColor("glowColor")
H.equal(color[1], 0)
H.equal(color[2], 1)
H.equal(color[3], 0)
H.equal(color[4], 1)

H.equal(other.Client.IsWarrior(), true)
invalid.class = "PALADIN"
H.equal(other.Client.IsWarrior(), false)
H.equal(other.Client.InCombat(), false)
invalid.combat = true
H.equal(other.Client.InCombat(), true)
H.equal(other.Client.Number(math.huge), nil)
H.equal(other.Client.Number(42), 42)

local secret = {}
invalid.secret[secret] = true
H.equal(other.Client.Readable(secret), false)

print("foundation: PASS")
