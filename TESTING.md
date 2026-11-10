# Current Development Status — 2026-11-10, first GitHub publication

- **Repository/branch:** `rerorriM-Mirrorer/TellLevel` / `main`, first import of the user-supplied `TellLevel-0.1.2-test3(1).zip`. The original local Git commit identities are not reconstructed from the ZIP.
- **Source checkpoint:** ZIP SHA-256 `ca2a4b66902f8ab7a3a14cfdeed6928b87984465395570cba6720069bb11b08d`; the two production Lua files are imported byte-for-byte without behavior changes.
- **Live observation:** After the original Test3 delivery, the user explicitly confirmed the movement/nameplate flicker correction worked in FFXI (2026-11-09). Earlier Test3 records below saying live validation was pending reflect their original *pre-feedback* state; they are not claims about the latest status.
- **Verification in this publication:** Lua 5.4 parsing passed for both production source files and `tests/run.lua`. Running the existing regression under Lua 5.4 passed all 43 assertions. This is simulated testing, not a fresh Windows/Windower/FFXI run. No LuaJIT / Lua 5.1 run was performed.
- **Pending:** live regression of unload/name restoration, zoning, letters/levels combinations, FPS and multiclient performance; `windower.set_mob_name` has memory-safety considerations. Avoid running Tellapart simultaneously.
- **Packaging:** main contains the full installable addon contents at repository root; use the `TellLevel/` folder name under `Windower4/addons/`, preserve any installed `data/`, and keep WORKFLOW/TESTING inside installable packages.
- **Next:** reproduce the remaining live checks and tag a stable release only after acceptance; `main` is our first user-confirmed working checkpoint, not a claim of complete regression testing.

---

# TellLevel testing record

## Current Development Status — 2026-11-09, Test3 (America/Chicago)

- **Repository / branch:** local `telllevel-dev` / `feat/telllevel-per-frame` (created from `feat/telllevel-level-only-default` at `d6cf41e`). No TellLevel GitHub remote configured; upstream Tellapart `lili-ffxi/FFXI-Addons` `master` is read-only here. Canonical NPCMirror `main` AGENTS/WORKFLOW/TESTING were checked directly on GitHub before this edit.
- **Source baseline:** committed Test2 `d6cf41e`, unchanged initial package available separately. Final Test3 commit is listed in handoff, not embedded here.
- **Runtime:** Windower 4 + retail FFXI intended; no executable access to live Windows/FFXI here.
- **User-reported live symptom:** when a monster moves, its nameplate flickers between e.g. `Goblin Lv32` and its original `Goblin`. This is a user-observed effect, not a tool-captured packet trace. The current `render_frame()` in Test2 reapplies the desired name only once every 12 frames, providing a strong plausible explanation.
- **Change:** Reapply modified names every render frame, as in original Tellapart. Keep target observation, discovery sweeps and Wide Scan scheduling on the previous maintenance cadence. No scan interval, level extraction, display format, or settings change. New version `0.1.2-test3`.
- **Verification:** `texluac -p TellLevel.lua telllevel_core.lua tests/run.lua` passes; `texlua tests/run.lua` passes (43 mocked assertions). The new regression first failed on Test2 code and passed after the change; it simulates game reset of a native name and expects repair in one `prerender` without another discovery sweep. No real FPS or visual flicker measurement has been performed. Lua 5.1 engine verification remains unavailable.
- **Current open test:** single-client movement/battle flicker; FPS and impact on 2–4 clients; ensure original Tellapart or any other name writer is unloaded. If flicker remains, capture a short video and Windower console output.

## Current test instructions — Test3

1. Unload both `//lua unload TellLevel` and `//lua unload tellapart`, then overwrite the `Windower4/addons/TellLevel/` addon files with Test3. Keep your existing `data/settings.xml`. `//lua load TellLevel`; `//tl status` should show `0.1.2-test3`, `format=full`, `letters=false`, `levels=true` unless settings were changed manually.
2. Target a monster whose exact level is available via Wide Scan or `/check <t>`. Confirm `Goblin Lv32` formatting as before, and observe the name while the monster walks or animates, especially before combat and while following you.
3. Check the name does not spend visibly long periods as the original `Goblin`; Test3 is intended to restore it on the next render frame. If it still flickers, report which other nameplate addons are loaded, the approximate FPS, and whether the reset occurs only on movement or also while idle.
4. Try `//tl letters on` then `off`, change targets, zone, and unload. Confirm original names restore and level cache behavior is unchanged. Monitor FPS on one client before running multiple clients.
5. Auto-scanning behavior is unchanged. Check `//tl status` before and after moving to see if scan counts remain stable. If needed, `//tl debug on` exposes scan/level observation messages, not every name write.

## Test3 change and verification — 2026-11-09

- Root-cause hypothesis: game-native entity updates may overwrite names set with `windower.set_mob_name`. Test2's 12-frame repaint interval allows original names to stay onscreen for ~0.4 seconds at 30 FPS. Reverting to the original Tellapart-style per-frame rename should substantially reduce the visible window.
- Added regression test that resets a mocked monster's displayed name to its original immediately after a known level appears. The test failed against the old cadence and passes after the change; discovery sweeps remain throttled.
- User confirmed flicker in actual gameplay; **fix has not yet been live-tested**. Keep this distinction when interpreting results.

## Delivery register — latest first (Test3 addition)

| Date | Batch | Package | Git trace | Verification / status |
| --- | --- | --- | --- | --- |
| 2026-11-09 | Test3 | `TellLevel-0.1.2-test3.zip` | Local `feat/telllevel-per-frame`; final commit reported on delivery; no remote | 43 mocked assertions + syntax passed; live flicker fix pending |

## User-provided observations — new Test3 report

| Date | Item | Status |
| --- | --- | --- |
| 2026-11-09 | Original enemy names flicker into view as mobs move while level names are enabled | Reported live by user; root cause hypothesized from code; Test3 mitigation awaiting testing |

---

# TellLevel testing record

## Current Development Status — 2026-11-09, Test2 (America/Chicago)

- **Repository / branch:** standalone local `telllevel-dev` / `feat/telllevel-level-only-default`. The original Test1 ZIP source was imported into a fresh local Git repository because its previous Git metadata was not available in this workspace; this is **not** an upstream fork and is **not pushed** to GitHub.
- **Source baseline:** exact source from `TellLevel-0.1.0-test1.zip`; imported locally before editing. The original Test1 package is retained separately. See subsequent Git commits for the Test2 delta.
- **Runtime:** intended for Windower 4 + retail FFXI; no Windows client or in-game test available here.
- **Change:** defaults `format=full`, `letters=false`, `levels=true`, resulting in `Goblin Lv32` when a level is known. Both `full` and `level` use `LvXX`, while `compact` retains `[XX]`. Test1's original saved default (`format=full`, `letters=true`) migrates once; other formats and subsequent manual user choices persist. Packet discovery, scan timing and identity handling unchanged.
- **Verification:** `texluac -p TellLevel.lua telllevel_core.lua tests/run.lua` passed; `texlua tests/run.lua` passed (40 assertions) using mocked Windower APIs. **The Test1 319-assertion suite was not present in the supplied package and therefore was not rerun.** Lua 5.1 runtime, Windows/Windower 4, and retail FFXI remain untested for Test2.
- **Live status:** no TellLevel live results provided in this conversation as of Test2 delivery.
- **Unresolved:** first live acceptance for actual `LvXX` appearance and no duplicate-letter naming; existing packet and level availability uncertainties from Test1 remain. Next: install Test2 over Test1, test one client, then multibox.

## Current test instructions — Test2

1. Unload any existing TellLevel and original Tellapart: `//lua unload TellLevel` and `//lua unload tellapart`. Overwrite the `Windower4/addons/TellLevel/` files from Test2 while preserving `data/settings.xml`; `//lua load TellLevel` and `//tl status` should show `0.1.1-test2` with `letters=false`, `levels=true`, `format=full` if coming from the original Test1 defaults.
2. Target two same-name enemies; when their levels are discovered (Wide Scan or `/check <t>`), their native nameplates should show `Goblin Lv32`, `Goblin Lv34` — **no A/B/C**. Unknown levels should leave the base name unchanged.
3. Enter `//tl letters on`; confirm `Goblin A Lv32`, `Goblin B Lv34`. Then `//tl letters off` and confirm return to levels only. Reload and check that the explicitly selected setting persists.
4. Test `//tl format compact` (`Goblin [32]`, or `Goblin A [32]` with letters on) and `//tl format level` (always `Goblin Lv32`). Return to `//tl format full` and `//tl letters off` for defaults.
5. If your Test1 configuration was deliberately set to `compact`, ensure that it survives the upgrade. Verify name length, chat `<t>` masking, resetting names on unload, auto-scan and zone changes following the Test1 cases below.
6. For missing levels, use `/check <t>`, `//tl scan`, `//tl debug on` and `//tl status`; record name, zone, the check result and any client error. Once single-client behavior is confirmed, try 2–4 clients for performance and consistency.

## Test2 changes and verification — 2026-11-09

- Changed default letters to off; kept the existing formatting mode `full` so `//tl letters on` remains straightforward.
- Changed the level suffix in full/level modes from ` Lv. 32` to ` Lv32`. Compact formatting remains `[32]`.
- Added a once-only migration marker under saved settings. It converts Test1's exact default combination to the new default; saved custom formats are retained. If someone explicitly selected the same combination as Test1's default, that indistinguishable case is also converted; `//tl letters on` restores it permanently.
- Added `tests/run.lua` for the naming format, suffix limits, level packet handling, rendering, options, migration, pre-login migration guard, and restoration of original names. `texluac -p`: pass. Mock suite: 40 assertions pass. This is **simulation/static testing only**, not live FFXI.
- The previous Test1 test report remains below as historical evidence; the 319-assertion Test1 suite was unavailable, not rerun, and its prior pass should not be read as Test2 verification.

## Delivery register — latest first

| Date | Batch | Package | Git trace | Verification / status |
| --- | --- | --- | --- | --- |
| 2026-11-09 | Test2 | `TellLevel-0.1.1-test2.zip` | Local branch `feat/telllevel-level-only-default`; no remote configured | 40 mocked assertions + Lua syntax passed; not in-game-tested |
| 2026-11-09 | Test1 | `TellLevel-0.1.0-test1.zip` | Original local work branch reported as `feat/telllevel-nameplates`; original Git metadata unavailable here | 319 mocked assertions reported in Test1 record; not rerun in this workspace; not in-game-tested |

## User-provided requests since Test1

| Date | Item | Status |
| --- | --- | --- |
| 2026-11-09 | Default to levels only, omit A/B/C on all monsters | Implemented, mock tested; waiting live test |
| 2026-11-09 | Change level suffix to `LvXX` with no punctuation | Implemented, mock tested; waiting live test |

---

## Historical Test1 record (preserved below)

# TellLevel testing record

## Current Development Status — 2026-11-09 (America/Chicago)

- **Working repository / branch:** standalone local `telllevel-dev` / `feat/telllevel-nameplates`. Not a fork pushed to GitHub; no TellLevel remote configured.
- **Source references:** `lili-ffxi/FFXI-Addons` `master`, Tellapart v1.2.0; `DiscipleOfEris/MobLevel` `master`, MobLevel v1.2.1; Windower Lua packet definitions `dev`; XIUI `/check` packet implementation. Upstream Tellapart lacks root `AGENTS.md`, `WORKFLOW.md` and `TESTING.md`; canonical shared guidance consulted directly from NPCMirror `main`.
- **Tested baseline/source checkpoint:** initial TellLevel local implementation commits `604e2a5`, `257460c`; later documentation/package commits are described in delivery records. Final local git HEAD should be checked at delivery and does not appear within this tracked file to avoid self-referential hashes.
- **Package:** `TellLevel-0.1.0-test1.zip`, intended to unzip under `Windower4/addons/`.
- **Current code:** native rename, deterministic A/B/C, suffix format, Wide Scan `0x0F4`, `/check` response `0x029`, optional tracking `0x0F5`, cached levels with TTL, optional autocheck, user controls and diagnostics.
- **Static/simulated verification:** Lua 5.3 `texluac -p` syntax pass; `texlua tests/run.lua` Windower-mock tests pass (319 assertions). **Lua 5.1 engine, live Windows/Windower and retail FFXI were not available**; 5.3 syntax alone does not prove 5.1 compatibility.
- **Most recent user-confirmed live status:** none for TellLevel. Previous positive experience with original Tellapart or MobLevel should not be represented as a test of this version.
- **Known open questions:** Live level packet mapping; current retail scans; long names; possible same-ID respawn level changes; multisession performance; actual name restoration when unloading; chat expansion; field enum variations.
- **Next development step:** run a single-client in-game smoke test, record outcomes below, then expand to two or more clients, adjust the fields/refresh lifecycle from actual observations and package test2 on the working branch.

## Current test instructions — Test1

1. Unload `tellapart`, install `TellLevel/` from the ZIP and `//lua load TellLevel`; confirm no errors and `//tl status` shows `0.1.0-test1`.
2. Outside a safe city, locate **two same-name monsters**. Confirm A/B labels correspond to stable individual spawns and repeat when retargeted. Try another character in the same zone; letters should match each monster.
3. Confirm `//tl scan` requests Wide Scan. Target an enemy and perform `/check <t>` normally. Confirm the actual level appears as `Goblin A Lv. 32` (sample number only), never an estimated number. Use `//tl status` and `//tl debug on` if absent. Test *Impossible to Gauge*.
4. Check a **unique-name** monster: it should have no A/B letter but acquire a known `Lv. N` suffix. Unknown singleton names should be untouched.
5. Switch `//tl format compact`, `level`, `letters`, then `full`. Try a very long monster name (up to 23 visible characters). Confirm no client crash or severely clipped text.
6. Enter `//tl letters off`, `//tl levels off`, `//tl letters on`, `//tl levels on`. Confirm changes and `//tl status`; reload and verify saved settings.
7. In chat, send `//tl mask on` and `/p Target <t>` against a renamed mob. Ensure original monster name is spoken, while `/check <t>` and spell macro targets remain functional.
8. Zone to a city and back, despawn/repop the same enemy where possible, and test `//tl clear`, `//tl unload`, reload Tellapart. Record any stale level or original-name failure.
9. Optional: `//tl autocheck on`, quickly scroll targets then hold one selected for 0.7s; confirm only the stable selection receives native `/check`, no dangerous side effects, and normal `/check` chat still shows. Turn it off afterwards.
10. After stable one-client results, test with 2–4 clients at different resolutions, and verify FPS, consistency of labels, and independent level discovery.

Please report zone, target name, character count, observed result, and any Windower console error. Exact packet captures are preferred if discrepancies arise.

## Static and simulated results — 2026-11-09

- Confirmed source APIs against Windower Lua packet definitions and existing addon examples; source-only review, not live test.
- `texluac -p`: syntax successfully checked for both Lua files with Lua 5.3 tooling.
- `texlua tests/run.lua`: 319 assertions. Mocked monster list and `get_mob_array`, received packets `0x0F4` and `0x029`, unrelated check-like action rejection, server-ID change invalidation, TTL expiry, singleton no-op, formats, chat masking, scan throttles, unknown-target refresh, delayed DAT readiness, optional autocheck stable-target gating, lifecycle, city exclusions and user commands.
- No direct calls to actual FFXI or Windower during these checks. Tests cannot establish that 2026 retail packets match our source assumptions or that `set_mob_name` is crash-free in the user's environment.

## Delivery register

| Date | Batch | Package | Git trace | Verification / status |
| --- | --- | --- | --- | --- |
| 2026-11-09 | Test1 | `TellLevel-0.1.0-test1.zip` | Local work branch; source commits `604e2a5`, `257460c`, final packaging commit in local git history | Syntax and simulated tests passed; not live-tested; not pushed |

## Prior observations and cumulative history

- 2026-11-09: First discussion requested monster nameplates like `Goblin Lv. 32`, preserving Tellapart's A/B suffix behavior. No earlier TellLevel test sessions.
- 2026-11-09: Initial code implemented from reviewed sources. First mock regression revealed that a test incorrectly assumed no `/check` would be issued for a **new, still-stable target**; corrected test to check old-target cancellation and current-target execution separately. This was a test-assertion issue, not an in-game issue.
- 2026-11-09: Review identified unnecessary writes to unmodified singleton names. Fixed implementation and added assertion to avoid touching them.
- 2026-11-09: Added delayed zone-DAT readiness retries, bounded unknown-target Wide Scan refreshes and extra singleton-level scenarios. Re-ran simulated regression suite (319 assertions).

## User-provided materials and requests

| Date | Item | Status |
| --- | --- | --- |
| 2026-11-09 | Stable A/B/C letters distinguishing same-name spawns | Implemented, simulated |
| 2026-11-09 | Display exact levels after monster names (`Goblin Lv. 32`) | Implemented, simulated; awaiting in-game confirmation |
| 2026-11-09 | Deliver a complete addon to try | Test1 installation package prepared, awaiting live testing |
