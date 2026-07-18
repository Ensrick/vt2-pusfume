# Pusfume for Vermintide 2

An experimental, friends-only Vermintide 2 custom-career project by Ensrick and Janfon.

Steam Workshop development item: [Pusfume - Custom Career Prototype](https://steamcommunity.com/sharedfiles/filedetails/?id=3764954245)

The current milestone registers **Pusfume** as Bardin's fifth career. It uses Ranger Veteran's game-owned unit, animation set, talent tree, ability, and backend loadout as temporary adapters. A full-size Pusfume card is placed one virtual UI row above Saltzpyre in the five-row selector and keeps the game's normal click, preview, and confirmation flow. Registration checks, backend checks, UI tracking, and Ranger Veteran bot-takeover aliases are included. Every player in a lobby must install the same version.

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

Contributions must follow [CONTRIBUTING.md](CONTRIBUTING.md), including issue-linked branches, pull requests, verification evidence, and asset-provenance review.

This prototype supports the Adventure Keep and Adventure missions only. Chaos Wastes snapshots its career list before runtime mods register, and Weaves/Versus use separate career and loadout paths; Pusfume therefore locks itself in those mechanisms instead of risking an invalid spawn.

## Blender authoring

The repository includes an installable **VT2 Content Tools** extension for
Blender **5.2.0 LTS**. It validates character rigs, UVs, material slots,
four-influence skin weights, and active animation clips, then exports the model,
active clip, referenced textures, and a hash-verified handoff report with the
FBX settings confirmed by Pusfume. It also mirrors `j_left*` and `j_right*`
bones directly in Pose Mode without renaming the VT2 rig. This removes Maya and Autodesk accounts from
Janfon's authoring/export path; VT2's SDK/VMB compiler is still required for
the final runtime resources.

Build the installable ZIP with `py -3 tools\package_blender_addon.py` and follow
[BLENDER_CONTENT_TOOLS.md](docs/BLENDER_CONTENT_TOOLS.md) for installation and
the artist workflow.

## Build

From this repository:

```powershell
node ..\vmb\vmb.js build pusfume --cwd --clean
```

Run the source compatibility check before building:

```powershell
.\tools\Test-PusfumeSource.ps1
```

The output is written to `pusfume/bundleV2`. See [LIVE_TEST_CHECKLIST.md](docs/LIVE_TEST_CHECKLIST.md) for the first in-game pass, [CAREER_SYSTEM.md](docs/CAREER_SYSTEM.md) for the reverse-engineered architecture, [ASSET_PIPELINE.md](docs/ASSET_PIPELINE.md) for Janfon's art handoff, and [BLENDER_CONTENT_TOOLS.md](docs/BLENDER_CONTENT_TOOLS.md) for the no-Maya Blender workflow.

## Asset policy

This public repository accepts original or properly licensed source assets only. Do not commit extracted Fatshark meshes, rigs, textures, sounds, animations, or other game files.
