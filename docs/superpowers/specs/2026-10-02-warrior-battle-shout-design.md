# Warrior Assist Forever: Battle Shout reminder design

## Purpose and scope

Build a standalone WoW Forever addon in the existing `warrior-assist-forever` repository. Its first feature reminds a Warrior to refresh Battle Shout by glowing one user-selected default action bar button. The reminder uses the same animated proc glow and cast-timer model as Paladin Assist Forever's seal reminder. The addon has no runtime dependency on the Paladin, Hunter, or Range addons.

The user selects the physical button position. The addon does not cast spells, change key bindings or action attributes, inspect target state, or require a target. Feature processing runs only for Warriors; settings can remain available on other characters. The initial version targets the WoW Forever interface used by the sibling addons (16001), subject to in-client validation.

## Behavior

A successful player Battle Shout cast, at any rank, starts or restarts a 180-second session timer. A configured lead time determines the reminder threshold: `cast time + 180 seconds - lead time`. The default lead time is 10 seconds, so a cast at time zero first becomes due at 170 seconds. Once due, the reminder stays due until another successful cast. Failed casts, other units' casts, and unrelated spells do not reset it. Battle Shout identification uses the client's spell metadata so ranks share one timer. Unreadable or restricted event values are ignored safely.

A due reminder glows only while the player is in combat and the selected default action bar button is visible. Combat is sufficient; target and mouseover state play no part. Leaving combat hides the glow immediately without changing the timer. Re-entering combat shows it again if due. A new Battle Shout cast hides an active glow immediately. The glow flashes once on activation and then loops, as in the Paladin addon.

The timer is session local. After login or reload, it starts due until the addon observes a successful player Battle Shout cast. Player death clears the observed timer, making the reminder due on the next combat entry. The feature continues observing casts while its display setting is disabled, so enabling it later uses the current session timer. This is an estimated refresh reminder: it does not read auras and cannot detect an early dispel, a duration modifier, a Battle Shout from someone else, or an expiration during a reload.

Only one button position is selected. A changed selection clears the old glow and reevaluates the new visible button immediately. A hidden button does not glow. The selection is physical and remains at the same bar position through action bar paging or spell movement. If no bar is selected, the feature remains inert visually. Default Blizzard action bars are supported, matching the eight-bar list in the Paladin addon; third-party bars are outside this version's scope. Glow overlays are prepared out of combat, with a newly discovered button in combat prepared once combat ends.

## Settings and user interface

`/waf config` opens a native AddOns settings panel with one Battle Shout group. It contains an enable toggle (on by default), action bar selector ("Not selected" by default), button selector (Button 1 by default until a bar is chosen), lead-time control (integer seconds from 1 through 60, default 10), and a glow color picker (green `#00FF00` by default). Settings are saved account wide, following Paladin Assist Forever, and changes apply immediately. Changing the lead time recalculates the current threshold from the observed cast time; it does not start a fresh 180-second timer.

`/waf` prints concise diagnostics: addon/client version, whether Warrior processing is active, enabled state, selected button, configured lead time, and time until the reminder is due. Diagnostic output uses safe status text when client values are unavailable or restricted.

## Architecture and data flow

Use a private Lua addon namespace and a TOC that loads `Core`, focused reusable services, the Battle Shout feature, settings panel, and bootstrap in dependency order. Reuse the Paladin patterns for fixed default-button selection, session timers, config validation, settings widgets, and LibCustomGlow rendering. Copy only the components needed by this feature, adapt addon names and keys, and bundle the glow library with its license files. Keep the feature's spell and timer rules separate from generic services.

At login, initialize settings, register the panel, and start the feature only for Warriors. Register successful player casts, death, combat transitions, and action bar discovery events. The feature validates a cast, resolves its spell identity, and records the cast time. A refresh resolves the selected button and evaluates timer due state plus combat and button visibility. A 0.1-second update tick checks the threshold while the feature is active in combat; settings changes, relevant events, and button discovery trigger immediate refresh. The renderer owns an addon-specific overlay and releases it on disable, selection changes, combat exit, or unavailable button. It does not modify protected action button attributes.

## Error handling and limits

Unknown, missing, or restricted spell/event information never starts a timer. Unknown or restricted combat state never turns the glow on. Invalid saved settings fall back to defaults. The timer uses addon-owned timestamps rather than secret aura values. The addon does not infer a cast from a buff icon and does not promise an exact buff expiration if the game's duration differs from the agreed 180 seconds.

## Verification and delivery

Create Lua tests around the production modules and TOC. Cover Warrior gating; default and saved settings; no-selection behavior; successful cast recognition across ranks; unrelated, failed, other-unit, and restricted events; exact 170-second default boundary; recast reset; configurable lead time recalculated from the original cast; combat-only visibility without a target; button movement and hidden buttons; disabled observation; reload and death behavior; and renderer ownership/cleanup. Include a manifest-driven package script and README with install, settings, limitations, and in-game acceptance steps. Local tests establish module behavior; verify actual event delivery, protected-frame behavior, and glow appearance in WoW Forever.

## Design choice

A focused standalone addon preserves the existing family structure and makes later Warrior features straightforward to add. A single-file implementation would be shorter initially but would combine settings, timing, action-bar selection, and rendering in one module. Depending on the Paladin addon would make this Warrior feature unavailable to users who do not install it. The standalone focused structure is the selected design.
