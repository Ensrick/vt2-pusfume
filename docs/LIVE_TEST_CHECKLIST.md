# Pusfume Live Test Checklist

Use the **Modded Realm** and the normal Adventure Keep. Pusfume `0.6.65-dev`
intentionally locks itself in Chaos Wastes, Weaves, Versus, and other
mechanisms that snapshot or constrain the vanilla career list.

The v0.6.50 native-weight transfer retained the separation and introduced
finger strings. v0.6.51 restored Janfon's authored weights and corrected the
placement, but its isolated native-human 1P material rendered black and shiny.
v0.6.52 kept the corrected geometry but showed that the compiled material also
changes deformation, and its shared override altered both hand rigs. v0.6.53
uses the native-human first-person contract with corrected diffuse, normal,
and response bindings only on the hero-compatible hands. v0.6.54's native-arm
substitution is superseded. v0.6.55 restores Janfon-99 and changes only its
mesh-to-bone surface offset by the measured Packmaster comparison. Prioritize
steps 4-5 under **Spawn smoke test** and compare the rat-weapon grip against
v0.6.53. That candidate is source commit `b5ff287`, Workshop ManifestID
`5620515288318076233`, and its eight live files are hash-identical to staging.
The dark third-person body was intentionally unchanged in v0.6.55.

v0.6.56 is the shared Janfon diffuse-color-space test. Compare the selector,
third-person body, human-compatible hands, rat-weapon hands, fur, and whiskers
against Janfon's Blender/video reference. Diffuse maps now preserve his linear
`Non-Color` sampling instead of being sRGB-decoded by Stingray; normal, packed
response, emission, UV, skinning, and animation data are unchanged. Test source
commit `41b6b28`, Workshop ManifestID `8120410193085696537`; all eight live
files are hash-identical to staging.

The v0.6.56 result was split: Janfon-160 hero hands improved substantially,
the third-person body became pitch black except for emissive eyes, and the
Janfon-99 attachment logged one shown mesh with identity transforms and zero
limb error but rendered invisibly. v0.6.57 preserves the hero-hand path,
gamma-encodes diffuse for the third-person and Laurel sRGB donor contracts, and
applies a dedicated Packmaster-skin child to Janfon-99. Test all three paths.
v0.6.58 preserves those successful material paths, removes the disproven
whole-mesh Versus offset, and removes the extra gamma transfer from dalokraff's
fur. Test source commit `c57728d`, Workshop ManifestID
`6145712826462103701`; compare grip placement and fur brightness directly
against v0.6.57.
v0.6.59 is the same visual candidate with a crash guard for hook right-click:
press and release block once and confirm unsupported `parry_pose` and
`parry_finished` events are skipped without ending the session. Test source
commit `e590554`, Workshop ManifestID `9187838202506746820`.

v0.6.60 is the Assassin-animation and material-contract test. Equip the
Assassin Blade, then verify its equip motion, idle motion, held block, chained
light attacks, heavy attack, and push-stab are visibly distinct and do not
crash. The log should contain `Janfon assassin 1P clip` entries naming the
corresponding `claws_*` clips. Compare ordinary hero-weapon hands against the
Versus hands: both now use the proven Packmaster child material. Compare fur in
the inventory, sunlight, and shadow; it now uses native Skaven fur response
with unchanged texture pixels. The third-person body's darker gameplay lighting
is not claimed fixed in this candidate. Test source commit `1e6993a`, Workshop
ManifestID `3946661979316079793`; all eight live files are hash-identical to
staging.

The first v0.6.60 live test confirmed that both Janfon hand rigs look correct
and native Skaven fur response removes the neon fur. It also proved only
`claws_equip` reached Janfon's custom pipeline: attacks resolved to skipped Elf
events, and releasing block played generic `parry_finished` directly and
crashed. v0.6.61 is the dispatch correction. Re-run equip, each light branch,
heavy, push-stab, hold block, and release block. Every exercised action should
log `Janfon assassin 1P clip`; block release must log `claws_idle` and remain
in session. The inventory item is now `Assassin Blades (Janfon Prototype)`.
Test source commit `829c026`, Workshop ManifestID `3816877228129224808`; all
eight live files are hash-identical to staging and GitHub source preflight
passed. This candidate preserves the confirmed correct hero hands, Versus
hands, inventory body, and non-neon fur. Record opaque body appearance in Keep
sunlight and deep shadow separately; low-ambient gameplay darkness is not
claimed fixed.

v0.6.62 changes only the third-person body child from the Globadier outfit
shader to the native Globadier skin/flesh shader. Compare the inventory body,
Keep sunlight, and the same deep-shadow location used for v0.6.61. The body
should retain visible brown skin and clothing detail in shadow instead of
becoming a black silhouette. Confirm hero and Versus hands still look correct,
fur remains non-neon, and no unrelated world effect has changed.
Test source commit `73eddfe`, friends-only Workshop ManifestID
`4590557917691442433`; all eight installed files are hash-identical to staging
at `175,304,594` bytes.

The v0.6.62 live result disproved the skin/flesh shader substitution. v0.6.63
keeps that native shader but preserves the body response RGB while zeroing only
its emission alpha. Revisit the same shadow location, then equip the Assassin
Blades and exercise each light attack, heavy attack, push-stab, block, and
release. No action may leave a static twisted mesh over the camera. The log
must enumerate Janfon's `claws_*` clips and return to `claws_idle` after each
non-looping action.
Test source commit `c917c00`, friends-only Workshop ManifestID
`989271468751950746`; all eight installed files hash-match staging at
`177,122,644` bytes.

The v0.6.63 live result was partial: some body surfaces improved, others stayed
black, and the Assassin arms still became a rigid screen-blocking mesh. In
v0.6.64, inspect every opaque third-person surface in the same deep shadow;
the AO-neutral candidate must retain diffuse detail everywhere. Then equip the
Assassin Blades and test equip, idle, all chained lights, heavy, push-stab,
block, and release. These clips now target the compiled donor-rest skeleton,
not Janfon's original rest basis. `/pusfume_preflight` must no longer fail on a
missing Laurel package because the whisker child is embedded in this build.

The v0.6.64 live result rejected atlas-wide AO `255` and normal-speed custom
crossfades. In v0.6.65, one light attack must visibly complete and return to
idle without a rigid mesh remaining on camera; then test a full light chain and
block. Compare the body in inventory, sunlight, and deep shadow: material depth
must return without any surface becoming a black silhouette. Fur and both hand
materials are unchanged from the accepted v0.6.64 result.

The v0.6.44 candidate replaces the native Skaven first-person fallback with
Janfon's human-rigged arms and opens all five heroes' melee and ranged weapons
for hand compatibility testing. Its compiled unit matches 52 donor bones with
a maximum rest error of `0.00000352` against the `0.001` limit. Human hand
visibility, proportions, and native weapon animation are this test's release
priority; complete Packmaster pulling remains deferred.

Known-good native body/animation baseline: commit `0ffdf5a`, Workshop ManifestID
`2405082174877027150`. Current crash-safe first-person A/B candidate: commit
`cb51156`, Workshop ManifestID `5832214133899576087` on
`feat/22-first-person-arms`. That build's live mesh was visible but collapsed
into blinking sticks. Current rest-relative retarget candidate: commit
`b938d14`, Workshop ManifestID `1512228345017462962`. That build initialized
all pairs but placed the clean arm rig outside the first-person view. v0.6.13
adds rigid hand-midpoint camera anchoring and disables mesh-bound culling:
source commit `ccaec5a`, Workshop ManifestID `299222409316147201`.
That live test showed only two tiny black specks: midpoint error was `0.0044m`,
but each hand retained about `0.18m` error. v0.6.14 rigidly corrects each arm
root after midpoint alignment: source commit `ee26fcf`, Workshop ManifestID
`3997686606515825820`.
That test exposed vague transparent strands and a parent/child double
translation of about `0.441m`. v0.6.15 subtracts the inherited midpoint shift
from each arm-root correction and delays residual measurement by one frame; its
source commit is `ecbddd0` and Workshop ManifestID is
`5051999329694268825`. That live probe closed hand errors to
`0.0181/0.0119m`, but the shoulder roots remained `0.4647/0.5126m` away and
stretched the mesh into two strands. v0.6.16 rebinds the mesh offline to the
compiled donor rest skeleton and removes runtime retargeting: source commit
`1b35b11`, Workshop ManifestID `3075372935869158668`.
That build was not visually verified and its compiled bones retained a `100x`
basis despite correct donor positions. v0.6.17 counter-scales the exported
armature and hard-fails unless 54 transforms in the compiled custom unit match
the compiled donor; offline maximum error is now `0.00000263`. It also replaces
the old body with Janfon's repaired 138-bone untouched-rig model.
The current v0.6.23 candidate preserves v0.6.22's third-person animation and
material baseline while changing the first-person donor bind shape and adding
explicit hero-identity/live-HUD portrait guards. Its source commit and Workshop
upload are `6ecf623` and 2026-07-18 16:25 America/Chicago. Steam uploader
reported success; live verification and a refreshed ManifestID remain pending.
The v0.6.25 candidate corrects the prototype weapon hand contract after crash
`c6fadfc5-d61e-4eaf-9d19-ced33b4d75ae`. The hook resolves Fatshark's base
Packmaster item and articulated linking; Warpfire resolves the base Versus
item and its native left-handed actions. Source commit `c59ab62` was compiled
and uploaded at 2026-07-18 17:45 America/Chicago; Steam confirmed ManifestID
`1817442651143246521`. The live result is pending.
The v0.6.26 candidate replaces the remaining Ranger first-person contract with
Fatshark's shared Skaven first-person base and native Packmaster arms. Both
Pusfume inventory records are complete clones of their official Versus base
items, adapted only for Pusfume ownership and Adventure slots. This is an
intentional native-rig baseline: Janfon's arms remain in the source pipeline
but are not displayed until they can be rebound to the exact Skaven rest rig.
Source commit `b059534` was compiled, locally hash-verified, and uploaded at
2026-07-18 18:33 America/Chicago. Steam confirmed ManifestID
`4747837235132942219`. That candidate crashed because Adventure had not made
the Skaven first-person unit packages resident before vanilla player spawn.
v0.6.27 synchronously loads and verifies all three native unit packages before
registering the skin and falls back safely if any package cannot load. Source
commit `182f977` was compiled, locally hash-verified, and uploaded at
2026-07-18 18:55 America/Chicago. Steam confirmed ManifestID
`4012083168238356315`; the live result is pending.
That candidate successfully reached native player spawn, then its delayed
diagnostic asserted because Packmaster arms do not expose the old
Janfon/Ranger `j_spine2` probe node. v0.6.28 guards all probe pairs and logs
unavailable nodes without calling Stingray's assertion-prone lookup.
Source commit `2fa45c5` was compiled, locally hash-verified, and uploaded at
2026-07-18 19:21 America/Chicago. Steam confirmed ManifestID
`2137408449754657186`. The live build spawned without that assertion, and its
first-person probe showed identity scale with `0.0000m` error at all available
arm and hand links. The arms were nevertheless a huge deformed lump because
the Bardin profile installed its hero controller on the Skaven base. It later
crashed while attacking after a swap because the native Warpfire condition
called the Pactsworn-only `is_climbing()` status method.
v0.6.29 guards the adapted Warpfire status/overcharge API and prevents Bardin's
common state machine from replacing the native Skaven controller during spawn
or weapon swaps. This is deliberately a controller-only visual test: no model,
scale, attachment, or material transform changed. Source commit `6c912e3` was
compiled, locally hash-verified, and uploaded at 2026-07-18 19:53
America/Chicago. Steam confirmed ManifestID `3618672643934952388`. The live
result showed coherent animated hands, but the hook was invisible and striking
scenery crashed because the borrowed action sent `attack_hit_alt_effect` to the
Skaven controller. v0.6.30 clears the reversed diagnostic/native hide reasons,
runs the guarded Packmaster armed presentation after the weapon unit exists,
and removes all hero-only hit reactions from the temporary claw action table.
Source commit `be6f63a` was compiled, locally hash-verified, and uploaded at
2026-07-18 20:34 America/Chicago. Steam confirmed ManifestID
`3684913542981979356`. That build was crash-free with coherent native hands
and an armed hook unit, but both weapons were inert and Bardin's weapon catalog
remained visible. v0.6.31 maps normal hero controls to native Warpfire behavior,
adds Adventure targeting/damage, animates the claw during safe melee sweeps,
and career-filters Pusfume's weapon inventory. Its live result is pending.
Source commit `a7cc929` was compiled and hash-verified locally, then uploaded
at 2026-07-18 21:22 America/Chicago as friends-only Workshop ManifestID
`1065739404025473822`.
That build crashed in `WeaponUnitExtension.get_action` because the native
Warpfire synchronized state retained `dark_pact_action_one` after v0.6.31
removed that group. v0.6.32 retains lookup-correct compatibility aliases,
validates every action-chain destination before registration, and stages the
native Packmaster/claw first-person poses. Source commit `b2a42a0` was
compiled and locally hash-verified, then uploaded friends-only at 2026-07-18
22:10 America/Chicago. Steam confirmed ManifestID `1170425049691334215`.
The v0.6.32 live test kept coherent hands and correct native hold poses, but
the hook was inert, Bardin's inventory and dialogue still leaked through, and
the Warpfire heat HUD was absent. v0.6.33 hard-filters the four Pusfume item
identities, adds direct Adventure hook damage, adds Ratling and Globadier
ranged prototypes, routes dialogue to playable Globadier, and registers the
Pactsworn-green Warpfire HUD data. All of these changes remain live-unverified.
Source commit `77341d4` passed CI, native compilation, and the 54-node compiled
rest gate. All eight installed files match staging at `119,874,864` bytes.
Steam confirmed friends-only ManifestID `2481608271187325602` at 2026-07-18
23:49 America/Chicago.

## Before opening Heroes

1. Put Vermintide Mod Framework above Pusfume in the launcher mod order.
2. Enter the Adventure Keep and run `/pusfume_preflight`.
3. Expect zero failures, including PASS results for `career color`, `career localization`, and `native third-person unit`. A warning that the five-row grid card has not rendered is normal at this stage.
4. If backend data is still marked as not initialized, wait for the Keep to finish loading and rerun the command.
5. Confirm `spawn weapons` passes and names resolved melee and ranged items before selecting Pusfume.
6. Confirm `Pusfume weapon action hands` passes before attacking or blocking.

## Hero selector

1. Open **Heroes**.
2. Confirm a full-size gold-trimmed card appears one row above Saltzpyre, to the right of the career heading.
3. Confirm the five existing hero rows and their career cards retain their original size and positions.
4. Click the card. The center preview should show Janfon's textured Pusfume model while the name says **Pusfume** and the career heading says **Under-Empire Reject**.
5. Confirm the card itself uses the close-up orange-eyed Pusfume portrait, not Ranger Veteran.
6. Confirm no Ranger Veteran body, beard, or hat is visible with the Pusfume mesh.
7. Watch the preview long enough to confirm Janfon's new 96-frame authored idle is visible and there is no green glow beneath dark texture regions.
8. Confirm the whiskers move with the head and no lit rectangular alpha card is visible around them.
9. Run `/pusfume_status`; confirm the UI card/selection state and check the log for `Hero identity widgets restored`.
10. Run `/pusfume_preflight` again. The five-row card, preview hook, native hero preview, native third-person unit, whisker material, and spawn weapon checks should pass.
11. Confirm the selection through the normal Hero-menu button.

## Spawn smoke test

1. Run `/pusfume_status` and confirm `active=pusfume`.
2. Confirm the default melee slot resolves **Packmaster Hook (Prototype)** and
   the ranged slot initially resolves **Warpfire Thrower (Prototype)**.
3. Open both weapon inventory categories. Confirm the six rat prototypes remain
   available and ordinary weapons from Kruber, Bardin, Kerillian, Saltzpyre,
   and Sienna are visible. Equip at least one melee and one ranged hero weapon
   from different heroes before testing the rat prototypes.
4. With an ordinary hero melee weapon equipped, confirm both human-rigged hands
   sit at its native grip positions instead of appearing stretched or displaced
   far in front of the weapon. Attack, block, push, and inspect with Tweaker's
   third-person camera.
5. Swap to a Versus prototype and back to the ordinary hero weapon. Confirm the
   Versus pose remains unchanged and the corrected human grip placement returns
   without either attachment disappearing or separating from the camera.
6. Confirm the hook is visible in first person and is attached at the native
   Packmaster right-hand position. In the log, find `First-person weapon armed`
   and confirm `slot=slot_melee`, `claw_nodes=true/true`, and
   `remaining_hide_reasons=none`.
7. Swing the hook once into open air and once at a normal enemy. The current
   prototype should damage a nearby enemy without crashing; full disable,
   pulling, and dragging behavior is deferred and is not a release blocker for
   this human-hands candidate.
8. Swap to Warpfire and hold primary fire. Confirm the native flame stream,
   firing sound, heat gain, and repeated enemy damage all occur. Release fire,
   then use reload to vent heat and confirm the cooling state ends at zero.
   Crash `cd33e247-dc5e-4aa6-96ed-840258a1bde5` must not recur, and weapon
   registration in the log must report `action_graph=true`.
9. Equip Ratling Gun, hold primary fire through spin-up, and verify native
   projectiles, ammo use, pose, and reload. Equip Poison Wind Globe and verify
   primary fire throws a network-visible gas globe. Treat friendly gas damage
   as a prototype observation and record it explicitly.
10. Swap among all four weapons repeatedly and confirm each remains visible and
   responsive; neither slot may fall back to a Bardin item.
11. Gain Warpfire heat and confirm an overcharge bar appears using the green
   Pactsworn material. Confirm Pusfume combat grunts no longer use Bardin VO.
12. Open Talents and verify the temporary Ranger Veteran tree renders.
13. Confirm ability, passive, and perk text displays normally with no `<pusfume_...>` placeholders.
14. Use Moulder Ingenuity once. Confirm its 90-second cooldown starts, the armed
   placeholder message appears, and `/pusfume_gameplay` reports one activation;
   no consumable transformation is expected yet.
15. Switch to another Bardin career, then back to Pusfume, checking that neither loadout nor talents disappear.
16. Use `/pusfume` once as a fallback test. The command should print the host request and a `success` response.
17. Confirm the local in-game HUD portrait/name area is present, then open the player list long enough for its portrait to refresh. The log must contain `Live HUD portrait restored texture=portrait_pusfume`, and neither surface may show Ranger Veteran art.
18. Stand still and confirm the new 138-bone body deforms the spine, head, tail, integrated fur, and whiskers.
19. Walk and confirm the controller blends into the restored 25-frame original walk, then returns to Janfon's authored idle after stopping.
20. Confirm Pusfume's atlas remains correctly aligned, no whole-body or dark-region green emissive glow returns, and the whisker cards have no tape-like lighting rectangle. Record the exact body region for any localized mismatch; offline audit found zero escaped loops but a missing expected `p_eye_g` material.
21. Compare the body and both hand rigs under the same Keep lighting. Record
    whether colors are merely underlit together or whether one rig has a
    distinct black/shiny decode failure; do not infer texture gain from a
    different camera or light angle.
21. Turn, crouch, jump, dodge, attack, and use the career ability while watching the third-person model. These actions do not yet have dedicated Pusfume clips; record translation without matching pose as missing animation coverage, not a skinning regression.
22. Note any rest-pose offset, detached region, inverted limb, or extreme stretch.

## First-person arms

1. Enter a mission in the normal first-person camera and leave the default weapon equipped for at least ten seconds.
2. Confirm both arms remain continuously visible while looking up, down, left, and right; blinking is a failure of the LOD-bounds fix.
3. Before moving, confirm the fingers retain Janfon's modeled proportions and do not appear as long, thin sticks.
4. Confirm the hands and weapon occupy the same first-person depth/projection:
   the weapon must not float near the camera while the arms extend beyond it.
5. Equip ordinary hero weapons from multiple heroes. Confirm each is visible,
   attached to the expected hand, and does not make either arm disappear.
6. Attack, block, push, charge, aim, fire, reload, and swap with those hero
   weapons. Confirm Janfon's human hands follow their native hero poses without
   Globadier globe-holding or Packmaster-specific pose residue.
7. Confirm the arms use Pusfume's direct-UV body textures with no green donor glow, atlas scrambling, or opaque whisker-style cards.
8. Attack, block, push, reload, swap weapons, interact, revive, crouch, jump, dodge, and move in every direction.
9. Confirm the arms follow VT2's native first-person poses without remaining in rest pose, separating from the camera rig, changing bone lengths, or stretching fingers.
10. Enable Tweaker: General's third-person camera and confirm the established third-person body still animates and shades correctly.
11. Run `/pusfume_preflight` after spawning. `native first-person arms` must report PASS; preserve the log if it reports WARN or FAIL.
12. Check the log for `First-person donor-rest direct links active`.
    `First-person rest retarget initialized` must not appear for v0.6.44.
13. Check the delayed `First-person attachment probe`; it must report
    `direct=true`, `retarget=false`, and near-zero source/target node distances.
    Runtime anchor and limb corrections should remain zero because Blender
    already matched the compiled donor rest matrices.
14. Treat Janfon's `positioningtest` clip as an unwired diagnostic asset. His current first-person handoff has no walk cycle; do not expect or report a Janfon-authored first-person walk in this candidate.

## Career-kit smoke test

1. Remain spawned as Pusfume for at least 30 seconds and confirm the v2 passive
   buffs register without a `BuffExtension.add_buff` error.
2. Take an enemy melee hit and verify Scaredy-rat grants 20% movement speed for
   3 seconds, then expires. Confirm a ranged hit does not trigger the speed buff.
3. Enter Poison Wind gas and verify Hell Pit Native blocks its poison damage.
4. Reload a ranged weapon and compare timing with Ranger Veteran to verify
   Swift Claws grants 15% faster reload speed.
5. Kill a supported Special and confirm `/pusfume_gameplay` reports its breed
   and mapped Aggressive Iteration effect. The next shot does not apply that
   payload yet.

## Failure capture

Do not continue into a mission after any preflight failure. Keep the newest log from `%APPDATA%\Fatshark\Vermintide 2\console_logs` and note the last checklist step completed. Confirm the log's Workshop `last_updated` value before treating a visual result as evidence. Warnings about an unopened card or backend loadouts that have not materialized yet are expected; Lua errors or any FAIL line are not.
