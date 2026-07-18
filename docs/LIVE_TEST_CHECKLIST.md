# Pusfume Live Test Checklist

Use the **Modded Realm** and the normal Adventure Keep. Pusfume `0.6.14-dev`
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
root after midpoint alignment; its source commit and manifest are pending.

## Before opening Heroes

1. Put Vermintide Mod Framework above Pusfume in the launcher mod order.
2. Enter the Adventure Keep and run `/pusfume_preflight`.
3. Expect zero failures, including PASS results for `career color`, `career localization`, and `native third-person unit`. A warning that the five-row grid card has not rendered is normal at this stage.
4. If backend data is still marked as not initialized, wait for the Keep to finish loading and rerun the command.
5. Confirm `spawn weapons` passes and names resolved melee and ranged items before selecting Pusfume.

## Hero selector

1. Open **Heroes**.
2. Confirm a full-size gold-trimmed card appears one row above Saltzpyre, to the right of the career heading.
3. Confirm the five existing hero rows and their career cards retain their original size and positions.
4. Click the card. The center preview should show Janfon's textured Pusfume model while the career heading says **Pusfume**.
5. Confirm the card itself uses the close-up orange-eyed Pusfume portrait, not Ranger Veteran.
6. Confirm no Ranger Veteran body, beard, or hat is visible with the Pusfume mesh.
7. Watch the preview long enough to confirm the generated spine/head/tail idle is visible and there is no green glow beneath dark texture regions.
8. Confirm the whiskers move with the head and no lit rectangular alpha card is visible around them.
9. Run `/pusfume_status`; `UI(card=true selected=true)` confirms both UI hooks executed.
10. Run `/pusfume_preflight` again. The five-row card, preview hook, native hero preview, native third-person unit, whisker material, and spawn weapon checks should pass.
11. Confirm the selection through the normal Hero-menu button.

## Spawn smoke test

1. Run `/pusfume_status` and confirm `active=pusfume`.
2. Equip a Ranger Veteran-compatible melee and ranged weapon.
3. Open Talents and verify the temporary Ranger Veteran tree renders.
4. Confirm ability, passive, and perk text displays normally with no `<pusfume_...>` placeholders.
5. Use Moulder Ingenuity once. Confirm its 90-second cooldown starts, the armed
   placeholder message appears, and `/pusfume_gameplay` reports one activation;
   no consumable transformation is expected yet.
6. Switch to another Bardin career, then back to Pusfume, checking that neither loadout nor talents disappear.
7. Use `/pusfume` once as a fallback test. The command should print the host request and a `success` response.
8. Open the in-game player list and keep it visible long enough for the portrait to refresh; confirm the close-up Pusfume portrait renders inside the frame with no clipping or Ranger Veteran art.
9. Stand still and confirm the placeholder idle deforms the spine, head, tail, and whiskers.
10. Walk and confirm the controller blends into Janfon's walk cycle, then returns to idle after stopping.
11. Confirm Pusfume's atlas remains correctly aligned, no whole-body or dark-region green emissive glow returns, and the whisker cards have no tape-like lighting rectangle.
12. Turn, crouch, jump, dodge, attack, and use the career ability while watching the third-person model. These actions do not yet have dedicated Pusfume clips; record translation without matching pose as missing animation coverage, not a skinning regression.
13. Note any rest-pose offset, detached region, inverted limb, or extreme stretch.

## First-person arms

1. Enter a mission in the normal first-person camera and leave the default weapon equipped for at least ten seconds.
2. Confirm both arms remain continuously visible while looking up, down, left, and right; blinking is a failure of the LOD-bounds fix.
3. Before moving, confirm the fingers retain Janfon's modeled proportions and do not appear as long, thin sticks.
4. Confirm the arms use Pusfume's direct-UV body textures with no green donor glow, atlas scrambling, or opaque whisker-style cards.
5. Attack, block, push, reload, swap weapons, interact, revive, crouch, jump, dodge, and move in every direction.
6. Confirm the arms follow VT2's native first-person poses without remaining in rest pose, separating from the camera rig, changing bone lengths, or stretching fingers.
7. Enable Tweaker: General's third-person camera and confirm the established third-person body still animates and shades correctly.
8. Run `/pusfume_preflight` after spawning. `native first-person arms` must report PASS; preserve the log if it reports WARN or FAIL.
9. Check the log for `First-person rest retarget initialized`; it must report a nonzero pair count, `lods=0/0`, and `anchors=2`. `bounds_copied=false` is expected for the generated attachment.
10. Check the delayed `First-person attachment probe`; it must report `retarget=true`, `lods=0/0`, finite midpoint and limb corrections, and near-zero `limb_residual` values with no invalid-pose error. `bounds=false` is expected because neither first-person unit exposes an LOD object.
11. Treat Janfon's `positioningtest` clip as an unwired diagnostic asset in this candidate, not an expected looping gameplay animation.

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
