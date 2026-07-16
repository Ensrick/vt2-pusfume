# Pusfume for Vermintide 2

An experimental, friends-only Vermintide 2 custom-career project by Ensrick and Janfon.

Steam Workshop development item: [Pusfume - Custom Career Prototype](https://steamcommunity.com/sharedfiles/filedetails/?id=3764954245)

The current milestone registers **Pusfume** as Bardin's fifth career. Ranger
Veteran's talent tree, backend loadout, weapons, and bot behavior remain
temporary adapters, while Pusfume now owns his identity, placeholder Great
Scheme quests, three career perks, and a guarded Skaven Ingenuity station
scaffold. A full-size Pusfume card is placed one virtual UI row above Saltzpyre
in the five-row selector and keeps the game's normal click, preview, and
confirmation flow. The friends-only native build renders and deforms Janfon's
textured third-person placeholder in the selector and in game, with a generated
idle and Janfon's walk cycle. Every player in a lobby must install the same
version.

The successful native-character architecture, evidence, rejected approaches,
and reproduction steps are recorded in
[NATIVE_CHARACTER_MILESTONE.md](docs/NATIVE_CHARACTER_MILESTONE.md).

## Current development status

The current friends-only test build is **v0.6.4-dev**, Steam ManifestID
`5314442994604280740`. Live logs have confirmed mod startup, zero-failure
preflight, selector-card creation, native hero preview, normal profile
confirmation, player spawn, model/material/controller attachment, weapon setup,
and idle/walk playback. v0.6.4 fixes the first gameplay-frame crash caused by
missing vanilla-generated metadata on the runtime-registered Insider Knowledge
buff; that fix still requires live stability verification.

Skaven Ingenuity currently records a 20-second station and starts its cooldown,
but it does not yet spawn an interactable bag or modify inventory. Potion
enchantments, gas bombs, gas traps, final quest rewards, and animation coverage
beyond idle/walk remain guarded or deferred.

## Install and test

1. Subscribe to Vermintide Mod Framework and place it first in the launcher mod order.
2. Subscribe to Pusfume and place it below VMF.
3. Start the Modded Realm.
4. Enter `/pusfume_preflight` in the Adventure Keep. The unopened-card warning is expected; failures are not.
5. Open Heroes and click the gold-trimmed Pusfume card at the top right of the career grid.
6. Enter `/pusfume_status` to confirm `UI(card=true selected=true)` and then rerun `/pusfume_preflight`.
7. After spawning, enter `/pusfume_gameplay` to inspect poison blocks and the guarded station state.
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
[native integration PR #11](https://github.com/Ensrick/vt2-pusfume/pull/11),
and [career-kit draft PR #16](https://github.com/Ensrick/vt2-pusfume/pull/16).

## Asset policy

This public repository accepts original or properly licensed source assets only. Do not commit extracted Fatshark meshes, rigs, textures, sounds, animations, or other game files.
