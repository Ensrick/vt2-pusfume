# Pusfume Live Test Checklist

Use the **Modded Realm** and the normal Adventure Keep. Pusfume `0.6.4-dev`
intentionally locks itself in Chaos Wastes, Weaves, Versus, and other
mechanisms that snapshot or constrain the vanilla career list.

Known-good native visual baseline: commit `0ffdf5a`, Workshop ManifestID
`2405082174877027150`. Current career-kit candidate: commit `055cc66`, Workshop
ManifestID `5314442994604280740`.

## Before opening Heroes

1. Put Vermintide Mod Framework above Pusfume in the launcher mod order.
2. Enter the Adventure Keep and run `/pusfume_preflight`.
3. Expect zero failures, including PASS results for `career color` and `native third-person unit`. A warning that the five-row grid card has not rendered is normal at this stage.
4. If backend data is still marked as not initialized, wait for the Keep to finish loading and rerun the command.
5. Confirm `spawn weapons` passes and names resolved melee and ranged items before selecting Pusfume.

## Hero selector

1. Open **Heroes**.
2. Confirm a full-size gold-trimmed card appears one row above Saltzpyre, to the right of the career heading.
3. Confirm the five existing hero rows and their career cards retain their original size and positions.
4. Click the card. The center preview should show Janfon's textured Pusfume model while the career heading says **Pusfume**.
5. Confirm no Ranger Veteran body, beard, or hat is visible with the Pusfume mesh.
6. Watch the preview long enough to confirm the generated spine/head/tail idle is visible and there is no green glow beneath dark texture regions.
7. Run `/pusfume_status`; `UI(card=true selected=true)` confirms both UI hooks executed.
8. Run `/pusfume_preflight` again. The five-row card, preview hook, native hero preview, native third-person unit, and spawn weapon checks should pass.
9. Confirm the selection through the normal Hero-menu button.

## Spawn smoke test

1. Run `/pusfume_status` and confirm `active=pusfume`.
2. Equip a Ranger Veteran-compatible melee and ranged weapon.
3. Open Talents and verify the temporary Ranger Veteran tree renders.
4. Use the career ability once. Confirm the cooldown starts, the station
   placeholder message appears, and `/pusfume_gameplay` reports one deployment;
   no visible or interactable bag is expected yet.
5. Switch to another Bardin career, then back to Pusfume, checking that neither loadout nor talents disappear.
6. Use `/pusfume` once as a fallback test. The command should print the host request and a `success` response.
7. Open the in-game player list and keep it visible long enough for the portrait to refresh; confirm Pusfume's row renders without a Lua error.
8. Stand still and confirm the placeholder idle deforms the spine, head, and tail.
9. Walk and confirm the controller blends into Janfon's walk cycle, then returns to idle after stopping.
10. Confirm Pusfume's atlas remains correctly aligned and that no whole-body or dark-region green emissive glow returns.
11. Turn, crouch, jump, dodge, attack, and use the career ability while watching the third-person model. These actions do not yet have dedicated Pusfume clips; record translation without matching pose as missing animation coverage, not a skinning regression.
12. Note any rest-pose offset, detached region, inverted limb, or extreme stretch.

## Career-kit smoke test

1. Remain spawned as Pusfume for at least 30 seconds and confirm Insider
   Knowledge no longer raises a `BuffExtension.add_buff` error.
2. Take non-poison damage and verify Scaredy-rat grants 20% movement speed for
   3 seconds, then expires.
3. Enter Poison Wind gas and verify Hell Pit Native blocks its poison damage.
4. Damage a Skaven enemy with and without Pusfume present to validate the
   party-wide 5% Skaven power modifier.
5. Confirm The Great Scheme shows its two placeholder Skaven objectives and
   advances only for the intended kill categories.

## Failure capture

Do not continue into a mission after any preflight failure. Keep the newest log from `%APPDATA%\Fatshark\Vermintide 2\console_logs` and note the last checklist step completed. Confirm the log's Workshop `last_updated` value before treating a visual result as evidence. Warnings about an unopened card or backend loadouts that have not materialized yet are expected; Lua errors or any FAIL line are not.
