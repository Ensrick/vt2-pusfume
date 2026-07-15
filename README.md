# Pusfume for Vermintide 2

An experimental, friends-only Vermintide 2 custom-career project by Ensrick and Janfon.

Steam Workshop development item: [Pusfume - Custom Career Prototype](https://steamcommunity.com/sharedfiles/filedetails/?id=3764954245)

The current milestone registers **Pusfume** as Bardin's fifth career. It uses Ranger Veteran's game-owned unit, animation set, talent tree, ability, and backend loadout as temporary adapters. The generated Pusfume career card is moved into a dedicated top-right slot in the Hero selector and keeps the game's normal click, preview, and confirmation flow. Registration checks, backend checks, UI tracking, and Ranger Veteran bot-takeover aliases are included. Every player in a lobby must install the same version.

## Install and test

1. Subscribe to Vermintide Mod Framework and place it first in the launcher mod order.
2. Subscribe to Pusfume and place it below VMF.
3. Start the Modded Realm.
4. Enter `/pusfume_preflight` in the Adventure Keep. The unopened-card warning is expected; failures are not.
5. Open Heroes and click the gold-trimmed Pusfume card at the top right of the career grid.
6. Enter `/pusfume_status` to confirm `UI(card=true selected=true)` and then rerun `/pusfume_preflight`.
7. If the UI hook is unavailable after a game update, enter `/pusfume` in chat while in the Keep.

Pusfume currently shares Ranger Veteran's equipped items and talents. Changing Pusfume's loadout therefore changes Ranger Veteran's donor loadout until custom persistence is implemented.

Do not select Pusfume in a multiplayer lobby unless every connected player has the same Pusfume build enabled. The career uses a new synchronized career index; an unmodded peer cannot resolve it.

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

The output is written to `pusfume/bundleV2`. See [LIVE_TEST_CHECKLIST.md](docs/LIVE_TEST_CHECKLIST.md) for the first in-game pass, [CAREER_SYSTEM.md](docs/CAREER_SYSTEM.md) for the reverse-engineered architecture, and [ASSET_PIPELINE.md](docs/ASSET_PIPELINE.md) for Janfon's art handoff.

## Asset policy

This public repository accepts original or properly licensed source assets only. Do not commit extracted Fatshark meshes, rigs, textures, sounds, animations, or other game files.
