# Pusfume Live Test Checklist

Use the **Modded Realm** and the normal Adventure Keep. Pusfume `0.6.30-dev`
intentionally locks itself in Chaos Wastes, Weaves, Versus, and other
mechanisms that snapshot or constrain the vanilla career list.

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
2. Confirm the fixed melee slot resolves **Packmaster Hook (Prototype)** and the
   ranged slot resolves **Warpfire Thrower (Prototype)**. Ranger weapons should
   not appear as Pusfume equipment.
3. Confirm the hook is visible in first person and is attached at the native
   Packmaster right-hand position. In the log, find `First-person weapon armed`
   and confirm `slot=slot_melee`, `claw_nodes=true/true`, and
   `remaining_hide_reasons=none`.
4. Swing the hook into open air, scenery, armor, and a normal enemy. None of
   these hit paths may crash, including an aborted swing against scenery.
5. Open Talents and verify the temporary Ranger Veteran tree renders.
6. Confirm ability, passive, and perk text displays normally with no `<pusfume_...>` placeholders.
7. Use Moulder Ingenuity once. Confirm its 90-second cooldown starts, the armed
   placeholder message appears, and `/pusfume_gameplay` reports one activation;
   no consumable transformation is expected yet.
8. Switch to another Bardin career, then back to Pusfume, checking that neither loadout nor talents disappear.
9. Use `/pusfume` once as a fallback test. The command should print the host request and a `success` response.
10. Confirm the local in-game HUD portrait/name area is present, then open the player list long enough for its portrait to refresh. The log must contain `Live HUD portrait restored texture=portrait_pusfume`, and neither surface may show Ranger Veteran art.
11. Stand still and confirm the new 138-bone body deforms the spine, head, tail, integrated fur, and whiskers.
12. Walk and confirm the controller blends into the restored 25-frame original walk, then returns to Janfon's authored idle after stopping.
13. Confirm Pusfume's atlas remains correctly aligned, no whole-body or dark-region green emissive glow returns, and the whisker cards have no tape-like lighting rectangle.
14. Turn, crouch, jump, dodge, attack, and use the career ability while watching the third-person model. These actions do not yet have dedicated Pusfume clips; record translation without matching pose as missing animation coverage, not a skinning regression.
15. Note any rest-pose offset, detached region, inverted limb, or extreme stretch.

## First-person arms

1. Enter a mission in the normal first-person camera and leave the default weapon equipped for at least ten seconds.
2. Confirm both arms remain continuously visible while looking up, down, left, and right; blinking is a failure of the LOD-bounds fix.
3. Before moving, confirm the fingers retain Janfon's modeled proportions and do not appear as long, thin sticks.
4. Confirm the Packmaster hook and Warpfire Thrower are visible, attached to the
   expected hands, and do not make either arm disappear.
5. Confirm the arms use Pusfume's direct-UV body textures with no green donor glow, atlas scrambling, or opaque whisker-style cards.
6. Attack, block, push, reload, swap weapons, interact, revive, crouch, jump, dodge, and move in every direction.
7. Confirm the arms follow VT2's native first-person poses without remaining in rest pose, separating from the camera rig, changing bone lengths, or stretching fingers.
8. Enable Tweaker: General's third-person camera and confirm the established third-person body still animates and shades correctly.
9. Run `/pusfume_preflight` after spawning. `native first-person arms` must report PASS; preserve the log if it reports WARN or FAIL.
10. Check the log for `First-person donor-rest direct links active`. `First-person rest retarget initialized` must not appear for v0.6.24.
11. Check the delayed `First-person attachment probe`; it must report `direct=true`, `retarget=false`, and near-zero source/target node distances. Runtime anchor and limb corrections should remain zero because Blender already matched the compiled donor rest matrices.
12. Treat Janfon's `positioningtest` clip as an unwired diagnostic asset. His current first-person handoff has no walk cycle; do not expect or report a Janfon-authored first-person walk in this candidate.

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
