# Pusfume for Vermintide 2

An experimental, friends-only Vermintide 2 custom-career project by Ensrick and Janfon.

Steam Workshop development item: [Pusfume - Custom Career Prototype](https://steamcommunity.com/sharedfiles/filedetails/?id=3764954245)

The current milestone registers **Pusfume** as Bardin's fifth career. Ranger
Veteran's talent tree, backend loadout, weapons, and bot behavior remain
temporary adapters. Pusfume now owns his v2 identity, Aggressive Iteration
special-kill capture, Moulder Ingenuity consumable-augmentation state, and
three career perks. A full-size Pusfume card is placed one virtual UI row above Saltzpyre
in the five-row selector and keeps the game's normal click, preview, and
confirmation flow. The friends-only native build renders and deforms Janfon's
textured third-person placeholder in the selector and in game, with a generated
idle and Janfon's walk cycle. Every player in a lobby must install the same
version.

The successful native-character architecture, evidence, rejected approaches,
and reproduction steps are recorded in
[NATIVE_CHARACTER_MILESTONE.md](docs/NATIVE_CHARACTER_MILESTONE.md).

## Current development status

The current local build candidate is **v0.6.15-dev**. The preceding uploaded
candidate was v0.6.14-dev, source commit `ee26fcf`, Steam ManifestID
`3997686606515825820`.
Live logs have confirmed mod startup, zero-failure
preflight, selector-card creation, native hero preview, normal profile
confirmation, player spawn, model/material/controller attachment, weapon setup,
and idle/walk playback through v0.6.4. The v0.6.5 candidate bridges every
career-kit string into vanilla's global localization path and gives
`p_whiskers` the game's skinned Laurel alpha binding while preserving Janfon's
fractional coverage alpha. v0.6.7 makes Janfon's dedicated first-person arms
replace the equipped Ranger Veteran attachment before vanilla spawns it; their
visibility, deformation, and direct-UV material now require live verification
before upload. v0.6.8 adopts the authoritative career specification v2.0 with
100 HP, a 90-second Moulder Ingenuity cooldown, Aggressive Iteration capture,
melee-only Scaredy-rat activation, and Swift Claws reload speed.
v0.6.9 reset Janfon's first-person mesh to its authored bind pose, eliminating
the stretched stick-hand export but rendering no arms in the first live test.
v0.6.10 retains that clean bind and isolates Janfon's spine adapter while
logging the live attachment geometry needed for the next decision.
v0.6.11 makes that probe follow the real source/target spine pair after the
first v0.6.10 test asserted on a nonexistent target node. Its live probe proved
the mesh was present and enabled, but absolute bone links collapsed the arms
into blinking sticks. v0.6.12 replaces those links with a rest-relative
rotation retarget that preserves Janfon's bind offsets and copies donor LOD
bounds to the custom attachment.
The v0.6.12 live test initialized all retarget pairs but left the clean rest-pose
arms roughly half a metre outside VT2's live hand anchors. v0.6.13 rigidly
aligns the two-hand midpoint after retargeting and disables mesh-bound culling
for the first-person renderable; both changes preserve Janfon's bone lengths.
The v0.6.13 live probe reduced midpoint error to `0.0044m`, but the two hands
remained about `0.18m` from their corresponding donor hands and appeared as two
tiny black specks. v0.6.14 independently translates each complete arm at its
root to close those final offsets without scaling or collapsing the skeleton.
The v0.6.14 live test exposed a lazy world-transform ordering error: the spine
and each arm root repeated the same `~0.441m` translation, producing vague
transparent strands. v0.6.15 subtracts inherited midpoint motion from each arm
correction and measures residuals only after Stingray resolves the frame.

The first-person material uses the same proven compiled skinned-child technique
as the working third-person model. Animation cannot yet use the identical
root-controller path because third person has Pusfume-authored idle/walk clips,
while first person must inherit VT2's full weapon-action set from a donor with a
different rest rig. The durable simplification is to rebind Janfon's arm mesh
offline to the exact donor first-person rest skeleton, then remove runtime
retargeting; current candidates are collecting the transform data needed for
that conversion.

Moulder Ingenuity currently arms the next consumable selection and starts its
cooldown, but it does not yet transform inventory. Aggressive Iteration records
the killed Special and displays its ready state, while its ranged-shot payloads
remain guarded. The custom talent rows, weapons, consumable assets, and
animation coverage beyond idle/walk remain deferred.

## Install and test

1. Subscribe to Vermintide Mod Framework and place it first in the launcher mod order.
2. Subscribe to Pusfume and place it below VMF.
3. Start the Modded Realm.
4. Enter `/pusfume_preflight` in the Adventure Keep. The unopened-card warning is expected; failures are not.
5. Open Heroes and click the gold-trimmed Pusfume card at the top right of the career grid.
6. Enter `/pusfume_status` to confirm `UI(card=true selected=true)` and then rerun `/pusfume_preflight`.
7. After spawning, enter `/pusfume_gameplay` to inspect poison blocks, Scaredy-rat, Aggressive Iteration, and guarded augmentation state.
8. If the UI hook is unavailable after a game update, enter `/pusfume` in chat while in the Keep.

Pusfume currently shares Ranger Veteran's equipped items and talents. Changing Pusfume's loadout therefore changes Ranger Veteran's donor loadout until custom persistence is implemented.

Do not select Pusfume in a multiplayer lobby unless every connected player has the same Pusfume build enabled. The career uses a new synchronized career index; an unmodded peer cannot resolve it.

Contributions must follow [CONTRIBUTING.md](CONTRIBUTING.md), including issue-linked branches, pull requests, verification evidence, changelog discipline, and asset-provenance review. See [CHANGELOG.md](CHANGELOG.md) for the current development history and known limitations.

This prototype supports the Adventure Keep and Adventure missions only. Chaos Wastes snapshots its career list before runtime mods register, and Weaves/Versus use separate career and loadout paths; Pusfume therefore locks itself in those mechanisms instead of risking an invalid spawn.

## Build

From this repository:

```powershell
node ..\vmb\vmb.js build pusfume --cwd --clean
```

Run the source compatibility check before building:

```powershell
.\tools\Test-PusfumeSource.ps1
```

The output is written to `pusfume/bundleV2`. The public source build does not
include the private native handoff. With the reviewed private assets and local
game tooling present, the known-good native build is:

```powershell
py -m unittest discover -s tests -v
.\tools\Test-PusfumeSource.ps1
.\tools\Build-NativePusfume.ps1 -HeroPreview -SplicedGameChild
```

See [LIVE_TEST_CHECKLIST.md](docs/LIVE_TEST_CHECKLIST.md) for the in-game pass,
[CAREER_SYSTEM.md](docs/CAREER_SYSTEM.md) for the reverse-engineered career
architecture, and [ASSET_PIPELINE.md](docs/ASSET_PIPELINE.md) for Janfon's art
handoff.

Active work is tracked in [native integration issue #6](https://github.com/Ensrick/vt2-pusfume/issues/6),
[career-kit issue #15](https://github.com/Ensrick/vt2-pusfume/issues/15),
[localization issue #17](https://github.com/Ensrick/vt2-pusfume/issues/17),
[whisker rendering issue #18](https://github.com/Ensrick/vt2-pusfume/issues/18),
[native integration PR #11](https://github.com/Ensrick/vt2-pusfume/pull/11),
and [career-kit draft PR #16](https://github.com/Ensrick/vt2-pusfume/pull/16).

## Asset policy

This public repository accepts original or properly licensed source assets only. Do not commit extracted Fatshark meshes, rigs, textures, sounds, animations, or other game files.
