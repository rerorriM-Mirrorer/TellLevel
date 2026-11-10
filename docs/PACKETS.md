# TellLevel packet investigation — 2026-11-09

**Evidence:** Current Windower Lua packet definitions, Lili's Tellapart, DiscipleOfEris's MobLevel, and tirem's XIUI petbar check handler. This is a source audit + simulated checks, **not live packet capture**. No packets were captured from retail FFXI for this release.

## Known fields and handling

| Scenario | Direction / ID | Fields used | Source and confidence |
| --- | --- | --- | --- |
| Request Wide Scan | Outgoing `0x0F4` | `Flags = 1`, remaining fields zero | Windower `fields.lua`, MobLevel example; high confidence in schema, live behavior pending |
| Receive Wide Scan monster | Incoming `0x0F4` | `Index` (unsigned short), `Level` (unsigned char), `Type` (enemy classifier) | Windower `fields.lua`, MobLevel; high confidence in schema; actual 2026 results unverified |
| Receive `/check` | Incoming `0x029` | `Target`, `Target Index`, `Message`, `Param 1` | Windower `fields.lua`, XIUI `modules/petbar/init.lua`; message IDs 170–178 mark normal check results; `Param 1` is mob level |
| Track Wide Scan mob | Incoming `0x0F5` | `Status` (Update), `Index`, `Level` | Windower `fields.lua`; accepted only for Update status |
| Monster appearance/update | Incoming `0x00E` | Raw zone-local index at offset `0x009` | Tellapart original; trigger register + rename when current entity confirms spawn type 16 |
| Zoning | Outgoing `0x00C` and zone change event | Rebuild name table, clear former zone | Tellapart original; timing requires in-game verification |

For `/check`, `0x029` action messages outside 170–178 are ignored (including `249` Impossible to Gauge), and IDs/indices must match a currently loaded enemy. The check `Param 1` field is parsed by Windower and validated to 1–255 before use. `Message` high status bits are stripped with modulus `0x4000`.

## Outstanding live observations

1. Confirm that incoming `0x0F4` arrives after an injected outgoing `0x0F4` with the expected `Type` enum and a nonzero `Level`, especially on normal jobs and across several zones.
2. Confirm `0x029` normal `/check` messages 170–178 and `Param 1` levels on retail. Capture whether *Impossible to Gauge* produces any reliable level field (currently ignored).
3. Confirm zone-change clearing, entity ID/index validity, delayed spawn packets and long-monster-name behavior.
4. Confirm server ID behavior on reappearance; test that a monster with the same ID but a newly rolled level refreshes correctly within 10 minutes.
5. Confirm `0x0F5` enum `Status` resolves to `'Update'` and that per-client Wide Scan packet injections are safely rate limited.

## Source references

- <https://github.com/Windower/Lua/blob/dev/addons/libs/packets/fields.lua>
- <https://github.com/lili-ffxi/FFXI-Addons/blob/master/tellapart/tellapart.lua>
- <https://github.com/DiscipleOfEris/MobLevel/blob/master/moblevel.lua>
- <https://github.com/tirem/XIUI/blob/main/XIUI/modules/petbar/init.lua>
- <https://github-wiki-see.page/m/Windower/Lua/wiki/message-IDs>
