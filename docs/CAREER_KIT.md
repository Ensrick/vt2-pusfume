# Pusfume Career Kit

This document records the first implementation contract for Pusfume's career
gameplay. The mod remains Adventure-only, friends-only, and requires the same
version on every peer.

Current uploaded test build: v0.6.5-dev, Steam ManifestID
`441804382456025179`, uploaded 2026-07-16 at 16:37:25 local time.

The v0.6.4 live log confirmed selection, player spawn, native model/material
attachment, controller startup, weapon setup, and session stability. v0.6.5
adds global gameplay localization and a skinned native-alpha whisker material;
both await live acceptance.

## Identity

- Character: **Pusfume**
- Career: **Under-Empire Reject**
- Passive: **The Great Scheme**
- Activated ability: **Skaven Ingenuity**

The selector overrides Bardin's displayed character name only while Pusfume is
selected. It does not mutate the shared Bardin profile or other Bardin careers.

## Implemented Gameplay

The Great Scheme creates two host-owned placeholder challenges per mission:

- Kill 40 Skaven for a strength potion.
- Kill 5 Skaven specials for a speed potion.

Challenge, reward, and category identifiers are appended to the engine network
lookups deterministically. All peers therefore need the same mod version.

The initial perks are implemented through stock synchronized systems:

- **Hell Pit Native** rejects known poison damage types and Poison Wind sources
  before health damage and `on_damage_taken` procs occur.
- **Scaredy-rat** grants a refreshable 1.2 movement multiplier for 3 seconds
  after real damage.
- **Insider Knowledge** applies one server-controlled `power_level_skaven`
  stack worth 0.05 to the hero side.

## Skaven Ingenuity Boundary

The activated ability no longer uses Ranger Veteran's smoke bomb. It records a
20-second station at Pusfume's position, starts a 60-second cooldown, and emits
diagnostics. The visible bag, interaction prompt, potion enchantments, gas-bomb
item, and gas traps are deliberately guarded rather than simulated with unsafe
inventory writes.

Before inventory conversion is enabled, the host must validate the station,
requesting player, range, slot contents, one-use state, and replacement item.
Custom gas payloads also need stable item, pickup, projectile, damage-profile,
and network lookup definitions.

Run `/pusfume_gameplay` to report poison blocks, station deployments, active
station state, and the guarded inventory status.

## Visual Contract

The whisker diffuse preserves Janfon's fractional DXT5 coverage alpha with
texture preprocessing thresholding disabled. At build time the canonical
private pipeline extracts the installed game's 128-byte Laurel feather
material, verifies its diffuse/normal/combined channel contract, patches only
those three resource IDs to the Pusfume whisker maps, and splices it over a
mod-owned child. This keeps native character skinning and alpha-card behavior
without redistributing the extracted source payload in Git.
