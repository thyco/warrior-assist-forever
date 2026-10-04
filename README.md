# Warrior Assist Forever

A standalone Battle Shout reminder and reactive ability glow addon for Warriors on WoW Forever (interface 16001).
It observes Battle Shout on your player, including buffs applied by another Warrior
and other ranks. Reminders appear only in combat; no target or mouseover is needed.
The addon does not cast spells or change bindings.

## Installation

Run `python3 scripts/package.py` to build `dist/WarriorAssistForever-0.3.3.zip`.
Extract the ZIP into the client's `Interface/AddOns` directory so the manifest is
`Interface/AddOns/WarriorAssistForever/WarriorAssistForever.toc`. Enable Warrior
Assist Forever in the AddOns list and log in or reload. LibStub and LibCustomGlow,
including their license notices, are bundled; no sibling addon is required.

## Settings

Use `/waf config` to open the native AddOns settings panel. Battle Shout is enabled
by default, with a **10-second lead**, a 64-pixel icon, and a green custom glow.
You can disable it, choose a lead from 1 through 60 seconds, select Blizzard's
native glow or a custom color, and set the icon size from 16 to 128 pixels in
4-pixel steps. Use **Move icon** outside combat to position it over your CDM buff
icon if desired. Settings and position are account wide and apply immediately.

Overpower and Revenge each have their own enable toggle, action bar, and button
selection. Both are enabled by default, but their bars start at **Not selected**:
choose a supported default bar and button 1–12 for each glow. The choices are
independent, saved across reloads, and apply immediately. They identify a physical
button position, including after action bar paging; the addon does not inspect,
cast, or rewrite the spell or macro on that button. You may place a stance-switch
macro for Overpower on the selected button while in Berserker Stance. The glow
prompts you to press it; it does not switch stance or cast for you. Overpower has
independent Blizzard-native or custom color settings for Battle and Berserker
Stance. Revenge has its own native or custom color setting. All three reactive
glow modes use Blizzard's native appearance by default.

In Battle Stance, a learned Overpower must be reported usable and off its own
cooldown. In Berserker Stance, its spell activation overlay must be reported and
its own cooldown ready; ordinary castability is not required there. Revenge uses
client usability and its own cooldown in Defensive Stance. The glows can appear
out of combat and without a target or mouseover. An absent, hidden, or unselected
button stays dark. Battle Shout remains combat only.

When Battle Shout is due, the movable screen icon glows in combat, whether or not
CDM displays the buff. A confirmed missing buff uses the same icon. The addon does
not attach a glow to CDM. Leaving combat or refreshing the buff clears the
reminder when it is no longer due.

## Aura timing and limitations

Readable aura expiration is authoritative. A safely observed application or refresh
with unreadable expiration starts a 180-second estimate, including an observed
cast by another Warrior. A confirmed removal overrides that estimate immediately.
An existing buff after reload with unreadable expiration has unknown timing until
a usable observation arrives. An unreadable refresh cannot reliably reset timing.

When combat blocks an aura lookup, a readable Battle Shout application in the
`UNIT_AURA` event can still refresh the timer. A successful Battle Shout cast by
your character also starts a 180-second fallback estimate and clears a due icon
when the new aura is unreadable. A later readable expiration replaces that
estimate. The cast fallback does not establish confirmed aura presence.
A readable removal of the known aura instance clears its deadline during a
restricted lookup; the state remains unknown until absence can be confirmed.

Restricted or failing aura queries produce **unknown**, never an invented missing
buff. A previously known deadline may continue as an estimated late reminder; an
unknown result without a deadline displays nothing. Missing requires a complete,
readable aura enumeration confirming absence.

If the client exposes no usable signal for an external application or refresh,
accurate timing cannot be guaranteed. Local tests cannot establish combat aura
readability or actual glow artwork in the client. If both the aura event and the
player's cast ID are restricted, the old late reminder may remain until the
client makes the new buff readable.

Reactive glows require readable learned ranks and client readiness evidence.
Unknown, secret, malformed, or failing stance, overlay, usability, or cooldown
data leaves the affected glow dark. An ability-specific cooldown blocks its glow;
the global cooldown alone does not. The addon uses the client's cooldown duration
with GCD excluded when available. A native inactive cooldown stays ready even if
the separate duration object is restricted. When timing values are restricted
during a GCD, the addon can use Blizzard's GCD flag observed in
`SPELL_UPDATE_COOLDOWN` while the GCD is active. An unreadable own cooldown
without that evidence stays dark.
A newly available button that cannot be
prepared during combat stays dark until a safe update. The client may make
usability depend on target state even though this addon has no target check.
Whether Forever reports an Overpower overlay in Berserker Stance must be confirmed
in game; the addon does not invent a dodge/block/parry timer when it is absent.

## Diagnostics

Use `/waf` for addon/client version, Warrior activation, enabled state, lead time,
aura state (`present`, `missing`, `unknown`), timing quality (`exact`, `estimated`,
`none`), remaining time when known, and selected reminder (`none`, `icon-late`,
`icon-missing`). It also reports stance, whether an Overpower or
Revenge rank is known, ready state, usability or overlay evidence, cooldown,
selected position, and glow activity. Unknown or restricted values use bounded
labels; raw spell IDs and restricted API results are not printed.

## In-game acceptance checks

These checks remain required; no WoW Forever client was available for local testing.

1. Enable Lua errors with `/console scriptErrors 1`, then `/reload`. On a Warrior,
   run `/waf`, open `/waf config`, change the lead, icon size, and color, then move
   the preview outside combat. Reload and confirm saved settings and position.
   Check a non-Warrior has no active feature.
2. Apply Battle Shout; outside combat there should be no reminder. Enter combat
   without a target and wait until the configured lead boundary. Confirm one
   activation flash followed by a looping glow around the movable icon, even if
   CDM displays Battle Shout. Change its color and native setting while due and
   confirm the glow updates without repeatedly flashing.
3. Have **another Warrior apply and refresh Battle Shout**, both outside and inside
   combat, including a different rank where available. Confirm `/waf` timing updates
   when the aura is readable and refreshing clears the reminder. Confirm the
   movable icon still appears if CDM hides that externally applied buff.
4. With the buff due in combat, hide/untrack its CDM item. Confirm the movable
   icon still glows and the addon puts no glow on any CDM item.
5. Remove Battle Shout in combat and confirm `missing` with the same screen icon.
   Reapply it yourself while aura queries are restricted and confirm the warning
   clears on the successful cast, with `/waf` showing an estimated deadline.
   Disable/re-enable
   the feature while due; leave/re-enter combat and check immediate reevaluation.
6. Reload with a readable buff, an unreadable buff if reproducible, and no buff.
   Compare `/waf` state/quality/output with the rules above. Unknown must not become
   a false missing warning. Check removal and expiration readability in combat.
7. Choose distinct default bar/button positions for Overpower and Revenge in
   `/waf config`, reload, and confirm both selections persist. Put Overpower or a
   stance-switch macro on its chosen button. Trigger Overpower after a dodge or
   Bloodthrill proc in Battle Stance, then in Berserker Stance. Check the glow,
   `/waf` overlay evidence, and whether the selected macro works when pressed.
8. Trigger Revenge after a block, dodge, or parry in Defensive Stance. Repeat both
   abilities with no current target and just after leaving combat. Check own
   cooldowns, and trigger another spell's GCD while each opportunity is active;
   its glow should stay visible until the opportunity ends. Check insufficient
   rage, stance changes, action bar paging, disabling a
   feature, and `/waf` diagnostics. Confirm glows clear as opportunities end and
   no Lua errors occur. Record whether Forever exposes Berserker Overpower overlay
   and targetless usability; local mocks cannot establish these client behaviors.
9. Choose different custom Overpower colors for Battle and Berserker Stance, then
   switch between them while each glow is active. Check that each stance restores
   its own color, Blizzard native mode works for both, and Revenge keeps its own
   choice.

If aura information differs in the real client, report the `/waf` status before and
after the event, client version, combat state, whether the caster was another
Warrior, and any Lua error. Screenshots of unexpected output help identify visual
issues.

## Local verification

From the repository root, run:

```sh
lua tests/foundation.lua
lua tests/aura.lua
lua tests/feature.lua
lua tests/settings.lua
lua tests/integration.lua
lua tests/reactive_foundation.lua
lua tests/reactive_spells.lua
lua tests/reactive_feature.lua
python3 tests/package.py
python3 scripts/package.py
python3 -m zipfile -l dist/WarriorAssistForever-0.3.3.zip
```

The integration check loads the actual bundled LibStub and LibCustomGlow with WoW
frame/animation doubles, then exercises the production glow and screen icon.
Package checks verify the install root, unique entries, license files, exact source
bytes, ZIP integrity, and rejection of missing or escaping manifest paths.
