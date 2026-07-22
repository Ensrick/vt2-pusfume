# Pusfume for Vermintide 2

An experimental, friends-only Vermintide 2 custom-career project by Ensrick and Janfon.

Steam Workshop development item: [Pusfume - Custom Career Prototype](https://steamcommunity.com/sharedfiles/filedetails/?id=3764954245)

The current milestone registers **Pusfume** as Bardin's fifth career. Ranger
Veteran's talent tree and bot behavior remain temporary adapters. Pusfume now
owns fixed prototype Packmaster-hook and Warpfire-Thrower items, his v2 identity, Aggressive Iteration
special-kill capture, Moulder Ingenuity consumable-augmentation state, and
three career perks. A full-size Pusfume card is placed one virtual UI row above Saltzpyre
in the five-row selector and keeps the game's normal click, preview, and
confirmation flow. The friends-only native build renders and deforms Janfon's
textured third-person placeholder in the selector and in game, with Janfon's
authored idle and the restored original walk cycle. Every player in a lobby must install the same
version.

The successful native-character architecture, evidence, rejected approaches,
and reproduction steps are recorded in
[NATIVE_CHARACTER_MILESTONE.md](docs/NATIVE_CHARACTER_MILESTONE.md).

## Current development status

The next friends-only live-test candidate is **v0.6.58-dev**. It retains the
weapon-aware dual first-person system using Janfon's assets: prototype Versus
weapons use his 99-bone Skaven attachment, while ordinary hero weapons use his
160-bone donor-rest human attachment.
Fatshark's hero first-person unit remains the sole
camera/controller base; weapon swaps change only the visible attachment and
weapon animation target, preventing Skaven locomotion from moving the hands
independently of the camera. Post-compile checks verify Janfon's 52 shared
human bones; the shipping build uses Fatshark's already-compiled Skaven arms
only as an alignment reference and renders Janfon's 99-bone Skaven mesh.
The v0.6.48 correction bypasses external all-or-nothing attachment wrappers
that left both Janfon meshes at world origin when one optional fingertip node
was absent, and reconciles the initially wielded weapon after inventory init.
The v0.6.49 live test disproved rest-surface alignment as the cause of the
outstretched ordinary-weapon arms. The v0.6.50 live test rejected nearest-
surface native weight transfer because it retained the separation and pulled
finger vertices into visible strings. v0.6.51 restored Janfon's authored skin
weights and corrected the hand placement, but its isolated native-human 1P
material test rendered the arms black and mirror-like. v0.6.52 proved that the
compiled material also affects first-person deformation, but its shared
override contaminated both hand rigs. v0.6.53 restores the native-human
skinning contract with correctly typed diffuse, normal, and response maps and
leaves the Skaven attachment's authored material untouched. The third-person
body's unnatural darkness remains a separate shading investigation.
v0.6.54 briefly substituted Fatshark's arms and is superseded. v0.6.55 restores
Janfon's 99-bone mesh and applies a measured mesh-only correction against the
compiled Packmaster skin. Its bones already matched within `0.00000025 m`; no
bone, weight, UV, material, or edge-length data is changed. This candidate is
source commit `b5ff287`, Workshop ManifestID `5620515288318076233`.
v0.6.56 corrects the shared darkness affecting Janfon's body, both first-person
hand meshes, fur, whiskers, and reused outfit textures. His Blender files feed
all diffuse images into the V2 Ubershader as linear `Non-Color` data, while the
native build had incorrectly compiled them as sRGB. The new candidate preserves
that authored linear sampling and removes the old body/fur gain compensation;
normal, packed response, emission, geometry, UV, weight, and animation data are
unchanged. The candidate is source commit `41b6b28`, Workshop ManifestID
`8120410193085696537`.
The v0.6.56 live test confirmed linear sampling improves Janfon's hero-rigged
hands, but disproved a single shared texture contract: the Globadier-derived
third-person child rendered pitch black and Janfon-99 was engine-visible but
produced no pixels. v0.6.57 keeps the improved hero hands, gamma-encodes the
linear-authored body/fur/whisker diffuse before their required sRGB donor
bindings, and gives Janfon-99 a dedicated Packmaster-skin child material.
The v0.6.57 live test confirms that material makes Janfon-99 visible and that
the body base color is normal in the inventory, but exposes neon standalone
fur and an off-position Versus grip. v0.6.58 keeps all successful material
contracts, removes the old whole-mesh correction that moved already-matching
hand centroids about `0.087 m` away from Packmaster's, and treats dalokraff's
fur diffuse as its original sRGB-authored data. Hero-hand darkness and the
darker gameplay-world body remain separate lighting/response investigations.
Exact Packmaster dragging remains a larger career-state feature. The localized
chest UV/material seam is tracked separately in issue #28.
The v0.6.26 live test proved Adventure did not make the Skaven first-person
inventory packages resident before vanilla spawned Pusfume. v0.6.27 loads and
verifies those unit packages synchronously with a dedicated reference before
skin registration and rechecks residency immediately before player spawn.
The v0.6.27 candidate is source commit `182f977`, Workshop ManifestID
`4012083168238356315`; live gameplay validation remains pending.
That test reached a successful native spawn, then v0.6.27's delayed diagnostic
asserted on a Janfon/Ranger-only probe node. v0.6.28 guards every probe node;
missing diagnostic pairs no longer affect gameplay.
The v0.6.28 candidate is source commit `2fa45c5`, Workshop ManifestID
`2137408449754657186`. Its live attachment probe reported identity scale and
zero error at every available arm/hand link, but the arms were grossly
deformed. Source comparison found that the shared Bardin profile was applying
the hero common state machine to the native Skaven base at spawn and after
weapon swaps; real Pactsworn profiles intentionally do not do this. v0.6.29
suppresses only that mismatched controller and capability-guards the Versus
Warpfire callbacks after crash
`3e42f9dd-5fbe-495d-8d55-d44ab5d0b062`. Its live test produced coherent,
animated native Skaven hands and spawned the real Packmaster hook unit, but the
hook remained invisible and striking scenery crashed ActionSweep while playing
the hero-only `attack_hit_alt_effect` event on the Pactsworn controller. v0.6.30
corrects a reversed visibility helper, performs Fatshark's guarded Packmaster
`to_armed` handshake after the weapon exists, and strips every hero-only hit
reaction from the temporary claw attacks. Source commit `be6f63a` was compiled,
locally hash-verified, and uploaded as Workshop ManifestID
`3684913542981979356`. Its live result was crash-free with coherent hands and
the armed hook unit, but neither weapon had usable Adventure actions and
Bardin's weapon catalog remained visible. v0.6.31 addresses those boundaries.
Source commit `a7cc929` was compiled, locally hash-verified, and uploaded as
friends-only Workshop ManifestID `1065739404025473822`; live gameplay
verification is pending.
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
transparent strands. v0.6.15 removed that duplicate translation, but its live
probe proved the corrected hands (`0.0181/0.0119m` error) were stretching from
incompatible shoulder roots (`0.4647/0.5126m` error). v0.6.16 therefore removes
runtime correction entirely: Blender rebinds Janfon's mesh to the exact rest
matrices extracted from VT2's compiled Ranger Veteran first-person unit, and
the game uses its normal direct node links.

Offline analysis then found the remaining defect after that rebind: the VT2
SDK preserved donor bone positions but compiled every Blender bone basis at
approximately `100x`. v0.6.17-v0.6.18 counter-scaled the armature object, while
v0.6.19 corrected compiled scene nodes but still produced malformed live finger
deformation. v0.6.21 bypasses that FBX unit conversion: its direct BSI export
writes scene nodes and inverse binds from one donor-rebound Blender scene.
v0.6.23 additionally conforms the weighted mesh to donor joint positions before
the rebind, so those exact pivots no longer rotate inside Janfon's old shape. The
build rejects the compiled unit unless all 54 donor-linked transforms match. It
also requires the dedicated fur material whenever Janfon's untouched 138-bone
body contains the integrated `p_fur` geometry.

The first-person material uses the same proven compiled skinned-child technique
as the working third-person model. Animation cannot yet use the identical
root-controller path because third person has Pusfume-authored idle/walk clips,
while first person must inherit VT2's full weapon-action set from a donor with a
different rest rig. The build parses the compiled donor unit, conforms and
rebinds Janfon's arm mesh offline to its exact first-person rest skeleton, and
rejects target-pose, matrix, weight, or post-rebind mesh drift before and after
Stingray compilation.

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

Pusfume currently shares Ranger Veteran's talents and non-weapon backend
adapters. His melee and ranged slots are fixed to the two Pusfume-only
prototype items until custom persistence and a larger authored roster exist.

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
.\tools\Build-NativePusfume.ps1 -HeroPreview -IntegratedFur -SplicedGameChild `
  -ModelFbx ".build\pusfume_handoff\pusfume_3p_authored_idle.fbx" `
  -AnimationFbx ".build\generated-native\pusfume_3p_retargeted_walk.fbx" `
  -IdleAnimationFbx ".build\generated-native\pusfume_3p_authored_idle_clip.fbx" `
  -FirstPersonBlend ".build\janfon_1p_human_20260719\pusfume_1p_human.blend" `
  -FirstPersonDonorUnit ".build\donor_human_1p_extract\units\beings\player\empire_soldier\first_person_base\chr_first_person_mesh.unit" `
  -FirstPersonMaterialDonor ".build\donor_human_1p_extract\046F5616B1180D05.material" `
  -VersusFirstPersonBlend ".build\janfon_1p_claws_20260719\pusfume_1p_arms claws base.blend" `
  -VersusFirstPersonDonorUnit ".build\donor_skaven_1p_extract\B62B2EB36EEED507.unit" `
  -Upload
```

`-IntegratedFur` uses the reviewed handoff fur maps under `-TextureSource` by
default. `-IntegratedFurTextureRoot` may select the licensed legacy map set for
a controlled visual-baseline build without changing the integrated mesh.

This is the only native ship entry point. It runs Blender, VMBLauncher, the VT2
SDK, deploy, and upload as redirected `CreateNoWindow` children, preserving the
desktop while retaining captured diagnostics. Do not invoke `vmb.js`,
VMBLauncher, or `ugc_tool` separately for Pusfume.

See [LIVE_TEST_CHECKLIST.md](docs/LIVE_TEST_CHECKLIST.md) for the in-game pass,
[CAREER_SYSTEM.md](docs/CAREER_SYSTEM.md) for the reverse-engineered career
architecture, and [ASSET_PIPELINE.md](docs/ASSET_PIPELINE.md) for Janfon's art
handoff. Janfon's source-referenced production inventory is maintained in the
[Pusfume Career Asset Checklist](outputs/pusfume-career-assets/Pusfume_Career_Asset_Checklist.xlsx).

Active work is tracked in [native integration issue #6](https://github.com/Ensrick/vt2-pusfume/issues/6),
[career-kit issue #15](https://github.com/Ensrick/vt2-pusfume/issues/15),
[localization issue #17](https://github.com/Ensrick/vt2-pusfume/issues/17),
[whisker rendering issue #18](https://github.com/Ensrick/vt2-pusfume/issues/18),
[native integration PR #11](https://github.com/Ensrick/vt2-pusfume/pull/11),
and [career-kit draft PR #16](https://github.com/Ensrick/vt2-pusfume/pull/16).

## Asset policy

This public repository accepts original or properly licensed source assets only. Do not commit extracted Fatshark meshes, rigs, textures, sounds, animations, or other game files.
