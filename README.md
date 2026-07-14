# Pusfume for Vermintide 2

An experimental, friends-only Vermintide 2 custom-career project by Ensrick and Janfon.

Steam Workshop development item: [Pusfume - Custom Career Prototype](https://steamcommunity.com/sharedfiles/filedetails/?id=3764954245)

The current milestone registers **Pusfume** as Bardin's fifth career. It uses Ranger Veteran's game-owned unit, animation set, talent tree, ability, and backend loadout as temporary adapters. This proves the complete selection and spawn path without redistributing Fatshark assets. Every player in a lobby must install the same version.

## Install and test

1. Subscribe to Vermintide Mod Framework and place it first in the launcher mod order.
2. Subscribe to Pusfume and place it below VMF.
3. Start the Modded Realm.
4. Open Heroes, select Bardin, and select the fifth career.
5. If the UI does not expose the fifth column, enter `/pusfume` in chat while in the keep.
6. Enter `/pusfume_status` to print registration and runtime diagnostics.

Pusfume currently shares Ranger Veteran's equipped items and talents. Changing Pusfume's loadout therefore changes Ranger Veteran's donor loadout until custom persistence is implemented.

Do not select Pusfume in a multiplayer lobby unless every connected player has the same Pusfume build enabled. The career uses a new synchronized career index; an unmodded peer cannot resolve it.

## Build

From this repository:

```powershell
node ..\vmb\vmb.js build pusfume --cwd --clean
```

The output is written to `pusfume/bundleV2`. See [CAREER_SYSTEM.md](docs/CAREER_SYSTEM.md) for the reverse-engineered architecture and [ASSET_PIPELINE.md](docs/ASSET_PIPELINE.md) for Janfon's art handoff.

## Asset policy

This public repository accepts original or properly licensed source assets only. Do not commit extracted Fatshark meshes, rigs, textures, sounds, animations, or other game files.
