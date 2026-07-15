# Pusfume Live Test Checklist

Use the **Modded Realm** and the normal Adventure Keep. Pusfume `0.4.0-dev` intentionally locks itself in Chaos Wastes, Weaves, Versus, and other mechanisms that snapshot or constrain the vanilla career list.

## Before opening Heroes

1. Put Vermintide Mod Framework above Pusfume in the launcher mod order.
2. Enter the Adventure Keep and run `/pusfume_preflight`.
3. Expect zero failures. A warning that the five-row grid card has not rendered is normal at this stage.
4. If backend data is still marked as not initialized, wait for the Keep to finish loading and rerun the command.

## Hero selector

1. Open **Heroes**.
2. Confirm a full-size gold-trimmed card appears one row above Saltzpyre, to the right of the career heading.
3. Confirm the five existing hero rows and their career cards retain their original size and positions.
4. Click the card. The preview should use Bardin/Ranger Veteran visuals while the career heading says **Pusfume**.
5. Run `/pusfume_status`; `UI(card=true selected=true)` confirms both UI hooks executed.
6. Run `/pusfume_preflight` again. `five-row grid card` should pass and report Bardin's row and column 5.
7. Confirm the selection through the normal Hero-menu button.

## Spawn smoke test

1. Run `/pusfume_status` and confirm `active=pusfume`.
2. Equip a Ranger Veteran-compatible melee and ranged weapon.
3. Open Talents and verify the temporary Ranger Veteran tree renders.
4. Use the career ability once and confirm Ranger Veteran's smoke ability completes normally.
5. Switch to another Bardin career, then back to Pusfume, checking that neither loadout nor talents disappear.
6. Use `/pusfume` once as a fallback test. The command should print the host request and a `success` response.

## Failure capture

Do not continue into a mission after any preflight failure. Keep the newest log from `%APPDATA%\Fatshark\Vermintide 2\console_logs` and note the last checklist step completed. Warnings about an unopened card or backend loadouts that have not materialized yet are expected; Lua errors or any FAIL line are not.
