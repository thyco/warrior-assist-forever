# Warrior Assist Forever

A standalone Battle Shout reminder and reactive ability glow addon for Warriors on WoW Forever (interface 16001).
It observes Battle Shout on your player, including buffs applied by another Warrior
and other ranks. Reminders appear only in combat; no target or mouseover is needed.
The addon does not cast spells or change bindings.

## Installation

Run `python3 scripts/package.py` to build `dist/WarriorAssistForever-0.2.0.zip`.
Extract the ZIP into the client's `Interface/AddOns` directory so the manifest is
`Interface/AddOns/WarriorAssistForever/WarriorAssistForever.toc`. Enable Warrior
Assist Forever in the AddOns list and log in or reload. LibStub and LibCustomGlow,
including their license notices, are bundled; no sibling addon is required.

## Settings

Use `/waf config` to open the native AddOns settings panel. Battle Shout is enabled
by default, with a **10-second lead** and a green glow. You can disable it, choose
a lead from 1 through 60 seconds, change the glow color, and use **Move icon** outside
combat to position the 64-by-64 screen icon. Settings and position are account wide
and apply immediately.

Overpower and Revenge each have their own enable toggle, action bar, and button
selection. Both are enabled by default, but their bars start at **Not selected**:
choose a supported default bar and button 1–12 for each glow. The choices are
independent, saved across reloads, and apply immediately. They identify a physical
button position, including after action bar paging; the addon does not inspect,
cast, or rewrite the spell or macro on that button. You may place a stance-switch
macro for Overpower on the selected button while in Berserker Stance. The glow
prompts you to press it; it does not switch stance or cast for you.

In Battle Stance, a learned Overpower must be reported usable and off its own
cooldown. In Berserker Stance, its spell activation overlay must be reported and
its own cooldown ready; ordinary castability is not required there. Revenge uses
client usability and its own cooldown in Defensive Stance. The glows can appear
out of combat and without a target or mouseover. An absent, hidden, or unselected
button stays dark. Battle Shout remains combat only.

When Battle Shout is due, the addon prefers its visible, prepared icon in CDM's
Tracked Buffs display. Configure Battle Shout there to use this placement. If that
icon is hidden, absent, or cannot be prepared safely during combat, a movable
screen icon supplies the late reminder. A confirmed missing buff always uses the
screen icon in combat. Only one reminder appears at a time. Leaving combat or
refreshing the buff clears the reminder when it is no longer due.

## Aura timing and limitations

Readable aura expiration is authoritative. A safely observed application or refresh
with unreadable expiration starts a 180-second estimate, including an observed
cast by another Warrior. A confirmed removal overrides that estimate immediately.
An existing buff after reload with unreadable expiration has unknown timing until
a usable observation arrives. An unreadable refresh cannot reliably reset timing.

Restricted or failing aura queries produce **unknown**, never an invented missing
buff. A previously known deadline may continue as an estimated late reminder; an
unknown result without a deadline displays nothing. Missing requires a complete,
readable aura enumeration confirming absence.

CDM's player-caster filter may hide Battle Shout applied by another Warrior; this
is inferred from client source and still needs real-client validation. The screen
icon handles that case when the addon can observe the aura. If the client exposes
no usable signal for an external application or refresh, accurate timing cannot
be guaranteed. Local tests cannot establish combat aura readability, actual glow
artwork, protected-frame behavior, or CDM visibility in the client.

Reactive glows require readable learned ranks and client readiness evidence.
Unknown, secret, malformed, or failing stance, overlay, usability, or cooldown
data leaves the affected glow dark. An ability-specific cooldown blocks its glow;
the global cooldown alone does not. A newly available button that cannot be
prepared during combat stays dark until a safe update. The client may make
usability depend on target state even though this addon has no target check.
Whether Forever reports an Overpower overlay in Berserker Stance must be confirmed
in game; the addon does not invent a dodge/block/parry timer when it is absent.

## Diagnostics

Use `/waf` for addon/client version, Warrior activation, enabled state, lead time,
aura state (`present`, `missing`, `unknown`), timing quality (`exact`, `estimated`,
`none`), remaining time when known, CDM state, and selected output (`none`, `cdm`,
`icon-late`, `icon-missing`). It also reports stance, whether an Overpower or
Revenge rank is known, ready state, usability or overlay evidence, cooldown,
selected position, and glow activity. Unknown or restricted values use bounded
labels; raw spell IDs and restricted API results are not printed.

## In-game acceptance checks

These checks remain required; no WoW Forever client was available for local testing.

1. Enable Lua errors with `/console scriptErrors 1`, then `/reload`. On a Warrior,
   run `/waf`, open `/waf config`, change the lead/color, and move the preview outside
   combat. Reload and confirm saved settings and position. Check a non-Warrior has
   no active feature.
2. Add Battle Shout to CDM Tracked Buffs. Apply it yourself; outside combat there
   should be no reminder. Enter combat without a target and wait until the configured
   lead boundary. Confirm one activation flash followed by a looping glow on CDM.
   Change the color while due and confirm the glow does not repeatedly flash.
3. Have **another Warrior apply and refresh Battle Shout**, both outside and inside
   combat, including a different rank where available. Confirm `/waf` timing updates
   when the aura is readable and refreshing clears the reminder. Record whether CDM
   hides that externally applied buff and whether the late screen fallback appears.
4. With the buff due in combat, hide/untrack its CDM item. Confirm only the screen
   icon glows. Restore CDM and change its layout/tracked items; confirm the glow
   follows Battle Shout and never remains on a frame reused for another spell.
5. Remove Battle Shout in combat and confirm `missing` with the screen icon even
   when CDM is hidden. Reapply it and confirm the warning clears. Disable/re-enable
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
   cooldowns, insufficient rage, stance changes, action bar paging, disabling a
   feature, and `/waf` diagnostics. Confirm glows clear as opportunities end and
   no Lua errors occur. Record whether Forever exposes Berserker Overpower overlay
   and targetless usability; local mocks cannot establish these client behaviors.

If CDM visibility or aura information differs in the real client, report the `/waf`
status before and after the event, client version, combat state, whether the caster
was another Warrior, CDM setup, and any Lua error. Screenshots of unexpected output
help identify visual issues.

## Local verification

From the repository root, run:

```sh
lua tests/foundation.lua
lua tests/aura.lua
lua tests/cdm.lua
lua tests/feature.lua
lua tests/settings.lua
lua tests/integration.lua
lua tests/reactive_foundation.lua
lua tests/reactive_spells.lua
lua tests/reactive_feature.lua
python3 tests/package.py
python3 scripts/package.py
python3 -m zipfile -l dist/WarriorAssistForever-0.2.0.zip
```

The integration check loads the actual bundled LibStub and LibCustomGlow with WoW
frame/animation doubles, then exercises the production glow and CDM services.
Package checks verify the install root, unique entries, license files, exact source
bytes, ZIP integrity, and rejection of missing or escaping manifest paths.
