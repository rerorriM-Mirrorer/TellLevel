# TellLevel — native monster names + actual levels

**Version:** `0.1.2-test3` (2026-11-09). The user confirmed the Test3 nameplate flicker correction worked in FFXI after the initial test package. Broader lifecycle, multiclient and performance checks remain open.

TellLevel replaces Tellapart for this test. By default it adds **only known, exact monster levels** to the game's native nameplates (`Goblin Lv32`), without A/B/C spawn letters. Letters remain available with `//tl letters on` (`Goblin A Lv32`). There is no overlay. Until a level is observed, the monster keeps its original name (unless letters were explicitly enabled).

**Credits:** The stable-letter concept, zone exclusions and native renaming approach come from [Lili's Tellapart](https://github.com/lili-ffxi/FFXI-Addons/tree/master/tellapart). The widescan level retrieval approach was informed by [DiscipleOfEris's MobLevel](https://github.com/DiscipleOfEris/MobLevel). This is an independent test implementation, not an official version of either addon.

## Install

1. **Unload Tellapart first:** `//lua unload tellapart`. Do not run two addons that both overwrite monster names. MobLevel can coexist, but is unnecessary to display the levels on nameplates.
2. Unzip this package into `Windower4/addons/` so you have `Windower4/addons/TellLevel/TellLevel.lua`, `telllevel_core.lua`, `README.md`, and the other included files. If upgrading from Test1 or Test2, **overwrite the two Lua files and the included documentation**, keeping your `data/` folder intact.
3. In FFXI enter `//lua load TellLevel`. Then `//tl status` (or `//tl help`). If you like it, add `lua load TellLevel` to `scripts/init.txt` **after** testing.
4. In an enemy area, target a monster. **The default display is `Goblin Lv32`, not `Goblin A Lv32`.** TellLevel requests a Wide Scan when loaded, then every 300 seconds or after targeting a level-unknown monster (at most one target-triggered request per 30 seconds). If a level hasn't appeared, use the game's `/check <t>` or `//tl scan` for another Wide Scan. The exact level is extracted from incoming information, not an estimated level range.

**Recommended first test:** Try two similarly named enemies with different levels; confirm both show `LvXX` but no A/B letters. Toggle `//tl letters on`, verify the letters appear, then `//tl letters off` to return to levels-only. Finally try on two separate clients in the same zone.

## Commands

| Chat command | Effect |
| --- | --- |
| `//tl` or `//tl help` | Show command help |
| `//tl status` | Show version, switches, cache/scan counts, target's known level |
| `//tl scan` | Request Wide Scan; requests have a 5-second minimum gap |
| `//tl format full` | `Goblin Lv32` by default; `Goblin A Lv32` if letters on |
| `//tl format compact` | `Goblin [32]` by default; `Goblin A [32]` if letters on |
| `//tl format level` | `Goblin Lv32` (always suppresses letters) |
| `//tl format letters` | `Goblin A` (omit levels) |
| `//tl letters on/off` | Toggle A/B/C suffixes (off by default; visible in `full`, `compact`, or `letters` modes) |
| `//tl levels on/off` | Toggle exact level suffixes |
| `//tl mask on/off` | Use original monster names when expanding `<t>` in chat commands |
| `//tl autoscan on/off` | Toggle background/unknown-target Wide Scan requests (on by default) |
| `//tl interval 300` | Set 60–3600 seconds between Wide Scans |
| `//tl autocheck on/off` | **Opt-in**: automatically `/check <t>` after a stable target pause of 0.7 seconds; its normal chat messages are not hidden |
| `//tl debug on/off` | Show registration, Wide Scan and `/check` decisions |
| `//tl clear` | Clear cached levels; attempt to request a fresh scan |
| `//tl reload` | Windower Lua reload |
| `//tl restart` | Windower Lua unload then load |
| `//tl unload` | Restore visible original names and unload |

Bare toggles flip their current value; `on` and `off` set a definite value. Settings are persisted by Windower under `TellLevel/data/settings.xml`.

**Upgrading from Test1:** The old saved `format=full, letters=true` default is migrated once to `letters=false`; deliberately chosen alternative formats such as `compact` are preserved. Because an explicit manual selection of the exact Test1 default is indistinguishable from an untouched default, that combination also migrates. To restore letters, run `//tl letters on` once; the new preference will persist. If you previously used `//tl format level`, that style already hides letters and will remain selected.

## Behavior and limitations

- Native names are limited to **23 bytes**. Longer names are shortened only when suffixes are actually applied, retaining the suffix. There is no added textbox or UI layer.
- Wide Scan reports only what that client's Wide Scan can see. Monsters outside its coverage remain level-unknown unless a valid `/check` response or tracking update is seen.
- The addon observes **manual `/check` automatically**. It does not automatically check every new target unless `//tl autocheck on` is set, so there is no default check-chat spam. That option still displays native `/check` messages.
- Known levels expire after **10 minutes** and are associated with a monster's server ID. An unbound Wide Scan result expires after 20 seconds. Reused IDs on rare respawns may need a fresh scan to refresh changed levels; this remains a live test case.
- A zone change clears levels and identities. Some safe city zones are skipped, as in Tellapart. Pets, players and trusts are never renamed.
- Chat masking is deliberately limited to chat/emote commands. It does **not** rewrite target pronouns in `/ma`, `/check`, `/ja`, etc.
- `windower.set_mob_name` alters native client memory. Windower's documentation warns that it can cause crashes, so test on one client first and keep Tellapart unloaded. The addon reapplies **only modified names** each render frame to counter the game restoring them during movement updates. Untouched singleton names are not rewritten. Try one client first and observe performance before enabling multiple clients.
- Native game movement updates may still briefly restore an original name before the next render frame; Test3 reduces the repair interval from 12 frames to 1. The user subsequently confirmed the flicker mitigation worked; longer-term performance and multiclient behavior still need verification.
- This is intended for **retail Windower 4**. The core movement-flicker correction was user-confirmed in game, but zone timing, unload behavior, performance and multiple-client behavior still need broader tests.

## Troubleshooting

If names appear but levels do not, target a normal enemy, run `/check <t>`, and then `//tl status`. Try `//tl scan` if Wide Scan is available. If needed, use `//tl debug on` and report the console messages, zone, target and whether `/check` supplied a level. A monster that reports *Impossible to Gauge* might not provide a supported exact `/check` value, so Wide Scan may be required.

If the addon fails to load, check that **both Lua files** are present in the **same `TellLevel` folder** and consult Windower's console error. To revert, run `//tl unload` or `//lua unload TellLevel` and reload your normal Tellapart addon.

## Flicker test (Test3)

After installing this version, approach a group of mobs with known levels and watch their names **while they move**, before and during battle. Previously a native movement refresh could leave the original name onscreen for up to 12 frames; Test3 reapplies the modified name each frame without requesting additional scans. If it still flickers, verify `//lua unload tellapart` and check for another addon rewriting monster names. Try one FFXI instance first and watch FPS with `//tl status` available for diagnostics.

## Changelog

- **2026-11-10 — GitHub source import:** Published the original Test3 Lua source unchanged and updated documentation with the user-confirmed flicker fix. Full lifecycle testing remains open.

- **2026-11-09 — 0.1.2-test3:** Apply known modified monster names every prerender instead of every 12 frames to reduce nameplate flicker when movement updates restore original names. Keep expensive discovery and scan scheduling on the prior cadence; add a mocked movement-refresh regression test. No level formats, saved settings or packet-request policies changed. The user subsequently confirmed the flicker correction worked in game; see current TESTING status for remaining checks.

- **2026-11-09 — 0.1.1-test2:** New default native display is `Goblin Lv32` with no A/B/C labels; level suffix is `LvXX` (no dot or internal space) in `full` and `level` modes. Existing Test1 default settings migrate once, while other custom formats remain intact; explicit `//tl letters on` persists. Added mocked upgrade/format regression tests. Packet behavior unchanged; live verification still pending.
- **2026-11-09 — 0.1.0-test1:** Added stable letter suffixes, native level suffixes from Wide Scan and recognized `/check` packets, bounded level caches, name-length protection, chat-only original-name masking, configuration, diagnostics, controlled automatic scanning, optional debounced automatic checking, reset/restore lifecycle commands and simulated regression checks. Initial independent test package; no live retail confirmation.
