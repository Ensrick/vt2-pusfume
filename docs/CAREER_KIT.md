# Pusfume Career Kit

This is the runtime contract for Pusfume's v2 career prototype. The complete
design and deferred content inventory are recorded in
[`PUSFUME_CAREER_SPEC_V2.md`](PUSFUME_CAREER_SPEC_V2.md). The mod remains
Adventure-only, friends-only, and requires the same version on every peer.

## Identity

- Character: **Pusfume**
- Career: **Under-Empire Reject**
- Health: **100**
- Passive: **Aggressive Iteration**
- Activated ability: **Moulder Ingenuity**, 90-second cooldown

The selector overrides Bardin's displayed character name only while Pusfume is
selected. It does not mutate the shared Bardin profile or other Bardin careers.

## Implemented Gameplay

Aggressive Iteration listens for Special kills, records the killed breed, maps
supported Specials to their future payload, and adds a synchronized ready-state
buff. Applying that payload to Pusfume's next ranged attack is intentionally
guarded until each effect has a tested damage, projectile, and network contract.

Moulder Ingenuity consumes the career charge and arms the next consumable
selection. It does not yet replace an inventory item. Healing, potion, bomb,
and incendiary transformations remain guarded pending item definitions,
networked replacement rules, effects, and first-person assets.

The base perks use stock VT2 contracts:

- **Hell Pit Native** rejects known poison damage types and Poison Wind sources
  before health damage and damage-taken procs occur.
- **Scaredy-rat** applies VT2's `no_moveslow_on_hit` perk and grants a
  refreshable 1.2 movement multiplier for 3 seconds after an enemy light or
  heavy melee attack deals damage.
- **Swift Claws** applies the stock `reload_speed` stat with Fatshark's `-0.15`
  convention for 15% faster reloads.

Run `/pusfume_gameplay` to report poison blocks, Scaredy-rat triggers, captured
Special/effect state, augmentation activations, and guarded payload status.

## Talent Tree

Pusfume owns a fifth deterministic `dwarf_ranger` talent tree and six locally
persisted column choices. Selecting a Pusfume talent no longer changes Ranger
Veteran. The temporary-health row, Coward at Heart, Elusive Nature, and the
standard stagger row use stock VT2 buff contracts and are operational.

The other ten slots are present so the specification and UI can be tested, but
their names explicitly say `Guarded Prototype` and their buff lists are empty.
This prevents item mutation, target tracking, area effects, and host-authority
logic from entering multiplayer before each contract has dedicated tests.

## Deferred Systems

Aggressive Iteration attack payloads, consumable transformations, ten guarded
talent effects, and the final custom weapon roster must not be presented as
functional until they have engine-backed implementations, synchronized
lookups, assets where required, and multiplayer regression coverage.

## Visual Contract

The whisker diffuse preserves Janfon's fractional DXT5 coverage alpha with
texture preprocessing thresholding disabled. At build time the private pipeline
extracts the installed game's Laurel feather material, verifies its diffuse,
normal, and packed-response channels, patches only those resource IDs to
Pusfume maps, and splices it over a mod-owned child. This keeps native character
skinning and alpha-card behavior without redistributing extracted source data.
