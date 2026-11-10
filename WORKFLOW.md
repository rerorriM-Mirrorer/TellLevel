# TellLevel development workflow

This repository adopts the shared FFXI practices in [NPCMirror's canonical WORKFLOW.md](https://github.com/rerorriM-Mirrorer/ffxi-NPCmirror/blob/main/WORKFLOW.md), read directly from the `main` branch on 2026-11-09. The canonical file remains the source of truth; this document records its application to this independent addon, not a replacement for the canonical full text.

## Principles

- Extend FFXI's native presentation instead of building a competing display. Avoid altering original game state when the requested appearance already matches the original.
- Preserve deterministic mob identity across clients by assigning letter suffixes from stable zone indices.
- Never present guesses as exact monster levels. Derive levels only from verified incoming packet fields. Do not inject `/check` requests as raw packets; the opt-in automatic check uses the game's command path.
- Allow partial knowledge: an unknown level displays only the name/letter, then updates when a confirmed level arrives. Keep unresolved states visible in `//tl status` and optional debug output.
- Limit packet requests and per-frame work for multiple clients. Keep auto-/check opt-in, pause on zoning, and do not target players or pets.
- Use code-local defaults and persistent Windower `config` settings; commands and help must match documented behavior.
- Prefer short, traceable commits on development branches. Do not promote to a trusted release branch until in-game results justify it.

## Verification and record keeping

1. Review the original request, the source repository/branch and current `AGENTS.md`, `WORKFLOW.md`, `TESTING.md` before changes. If the upstream lacks these files, consult canonical NPCMirror guidance while preserving upstream-specific behavior.
2. Review actual Windower packet definitions and known implementations before interpreting packet fields. Record details, assumptions and live-observation questions in `docs/PACKETS.md`.
3. Test in layers: Lua syntax/static analysis, scripted mock smoke/regression checks, then real Windower 4 in-game testing. State plainly which layer passed; do not substitute mocks for live behavior.
4. Record each test batch at the top of `TESTING.md`, preserving the cumulative history and user observations. Keep README and help/status aligned with the build.
5. For testing ZIPs, place `README.md`, `WORKFLOW.md`, `TESTING.md` and relevant docs **inside** the installable `TellLevel` folder alongside Lua files, not at the ZIP root.
6. Review the diff and tests, update the status, commit the version, and state exactly what is and is not pushed/verified before delivery. Verify a published branch if a remote is used.

## Development history

- **2026-11-09:** Created as a new independent test addon rather than editing `lili-ffxi/FFXI-Addons` without write access. Upstream Tellapart `master` has no root `AGENTS.md`, `WORKFLOW.md`, or `TESTING.md` (404 confirmed). This file and a cumulative `TESTING.md` adopt the shared conventions for TellLevel.
