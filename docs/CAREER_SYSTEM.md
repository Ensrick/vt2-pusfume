# Vermintide 2 Custom Career Implementation Guide

This guide maps the career system in Vermintide 2 source version 6.11.3 and translates it into a runtime-mod implementation plan for Pusfume. Research was verified against upstream commit `c5e4968b` (`Added Version 6.11.3 06-02-26`). Paths refer to the local `Vermintide-2-Source-Code` checkout. The game source is research material and is not copied into this repository.

## Executive summary

A career is not one self-contained class. It is a name shared across several registries that are normally assembled during game startup:

1. `CareerSettings` describes identity, attributes, UI, breed, slots, ability, passive, skin, and package roots.
2. `SPProfiles[profile_index].careers[career_index]` gives the career its authoritative numeric network identity.
3. `ActivatedAbilitySettings`, `PassiveAbilitySettings`, `TalentTrees`, `Talents`, and buff templates provide gameplay.
4. PlayFab-backed item and talent interfaces provide loadout state for official career names.
5. `PlayerBreeds`, cosmetics, item templates, action templates, packages, and network lookups provide spawnable resources.
6. UI, bot behavior, and each game mechanism maintain additional career-indexed data.

Official DLC careers are loaded before global lookup tables and derived state lists are finalized. A Workshop mod loads later, so it must reproduce every relevant side effect itself. The safest route is incremental:

1. Append a distinct career that reuses an official donor's gameplay and assets.
2. Prove host/client selection, spawn, death, respawn, hot join, and bot takeover.
3. Replace backend aliasing with local per-career loadout and talent persistence.
4. Add original passive and talent behavior using deterministic network registrations.
5. Add the original ability and only then introduce custom networked units or projectiles.
6. Replace donor presentation with compiled first-person, third-person, portrait, icon, and audio assets.

The current Pusfume prototype is at step 1. It appends Bardin career index 5, reuses Ranger Veteran, aliases PlayFab calls to `dr_ranger`, exposes a modern Hero View card and `/pusfume`, and fails closed outside Adventure.

## 1. Boot order and official registration

### 1.1 Career settings

`scripts/settings/profiles/career_settings.lua` performs the main career bootstrap:

1. Requires the base ability settings and player breeds.
2. Defines `CareerActionNames` and the 15 base `CareerSettings` entries.
3. Calls `DLCUtils.require_list("career_setting_files")` to load DLC careers.
4. Copies the final table into `CareerSettingsOriginal`.

Each premium career follows the same pattern in one career settings file:

- Engineer: `scripts/settings/dlcs/cog/career_settings_cog.lua`
- Grail Knight: `scripts/settings/dlcs/lake/career_settings_lake.lua`
- Sister of the Thorn: `scripts/settings/dlcs/woods/career_settings_woods.lua`
- Warrior Priest: `scripts/settings/dlcs/bless/career_settings_bless.lua`
- Necromancer: `scripts/settings/dlcs/shovel/career_settings_shovel.lua`

Action-driven DLC careers append their action template name to the hero's `CareerActionNames` list before defining the career. `scripts/settings/action_templates.lua` later validates all listed action templates.

### 1.2 Profile insertion and reverse lookups

`scripts/settings/profiles/sp_profiles.lua` defines the five hero profiles and then:

1. Builds `PROFILES_BY_NAME` and affiliation maps.
2. Exposes `add_career_to_profile(profile_name, career)`.
3. Loads DLC `profile_files`.
4. Rebuilds profile maps.
5. Builds `PROFILES_BY_CAREER_NAMES`.
6. Exposes `career_index_from_name` and `hero_and_career_name_from_index`.
7. Derives a `character_state_list` and `camera_state_list` for every career.

Official DLC profile files contain only an insertion call. For example, `scripts/settings/dlcs/cog/cog_profiles.lua` adds `dr_engineer` to `dwarf_ranger`.

The profile array position, not `sort_order`, is the career's network index. Appending Pusfume to Bardin makes it career index 5. Every peer must produce the same array in the same order.

### 1.3 What a runtime registration must repair

A late-loading mod cannot rely on the official boot passes. Registration must be idempotent and update all of these structures:

- `CareerSettings[career_name]`
- `CareerSettingsOriginal[career_name]`
- `PROFILES_BY_NAME[profile_name].careers`
- `PROFILES_BY_CAREER_NAMES[career_name]`
- `career.character_state_list`
- `career.camera_state_list`
- `CareerActionNames[profile_name]` when introducing a new action-driven ability
- Career-indexed compatibility tables used by UI, bots, constants, achievements, and modes

Do not insert the same career twice after VMF reloads. Find by `career.name`, replace the existing table in place, and append only when absent.

## 2. The career settings contract

The following fields form the practical minimum for a normal hero career.

| Field | Purpose |
| --- | --- |
| `name` | Stable internal identity and most runtime table key lookups. |
| `display_name` | Localization key; usually the same as `name`. |
| `description` | Localization key for the career description. |
| `profile_name` | Owning profile, such as `dwarf_ranger`. |
| `playfab_name` | Official backend identity. A new mod career should not invent one. |
| `sort_order` | Presentation metadata; does not set the network index. |
| `talent_tree_index` | Index into `TalentTrees[profile_name]`. |
| `breed` | Player breed used for health/status and spawn setup. |
| `attributes` | Base HP, critical chance, and optional movement/attack values. |
| `activated_ability` | One or more entries from `ActivatedAbilitySettings`. |
| `passive_ability` | Entry from `PassiveAbilitySettings`. |
| `base_skin` | Cosmetic key used when no backend skin is equipped. |
| `package_name` | Optional root resource package loaded by the profile synchronizer. |
| `item_slot_types_by_slot_name` | Allowed item categories for each backend slot. |
| `loadout_equipment_slots` | Equipment categories shown and initialized for the career. |
| `is_unlocked_function` | Returns availability and an optional reason. |
| `is_dlc_unlocked` | DLC ownership gate; custom friends-only careers can return true. |
| `override_available_for_mechanism` | Final per-mechanism availability gate. |
| `portrait_image` | HUD and Hero View portrait texture key. |
| `portrait_image_picking` | Character-selection portrait texture key. |
| `portrait_thumbnail` | Compact portrait key. |
| `picking_image` | Medium selection portrait key. |
| `preview_animation` | Career-select animation on the preview unit. |
| `preview_idle_animation` | Idle animation after selection. |
| `preview_wield_slot` | Previewed melee or ranged slot. |
| `preview_items` | Optional fixed preview weapon, hat, or props. |
| `sound_character` | Dialogue/voice identity. Donor reuse is valid initially. |

Optional fields are capability switches, not generic requirements:

- `additional_character_states_list` and `additional_camera_states_list` extend state machines.
- `requires_packages` adds packages globally or for talents.
- `talent_packages` computes packages from the selected talent IDs.
- `additional_inventory` inserts fixed utility/career items at spawn.
- `additional_item_slots` increases consumable capacity and is mirrored by husk inventory.
- `should_reload_career_weapon` supports Engineer-style ability weapons.
- `animation_variables` seeds custom animation graph variables.
- `overcharge_ui`, `OverchargeData[career_name]`, and `EnergyData[career_name]` add resources.
- `show_pet_ui` and `additional_ui_info_file` enable Necromancer-style HUD extensions.
- `preview_props` adds non-item preview units.
- `unique_subtitles` maps alternate dialogue subtitle sets.
- `mechanism_overrides` replaces nested settings in specific mechanisms.

Clone a donor deeply. A shallow copy shares nested `attributes`, slot maps, abilities, and preview tables and will silently mutate the official career.

## 3. Numeric identity and the network path

`scripts/utils/profile_requester.lua` is the supported selection path:

1. `request_profile(peer_id, local_player_id, profile_name, career_name, force_respawn)` resolves names to numeric indexes.
2. `rpc_request_profile` sends only `profile_index` and `career_index` to the host.
3. The host checks mechanism availability and profile reservation.
4. `ProfileSynchronizer` assigns the full profile and broadcasts the numeric indexes.
5. The requester receives `rpc_request_profile_reply` and updates the player.
6. A forced change despawns and respawns the unit.

`scripts/managers/player/player_manager.lua`, `bulldozer_player.lua`, and `player_bot.lua` then use those indexes to select `profile.careers[career_index]`.

Consequences for a custom career:

- The host and every client need the mod before selection.
- Identical mod versions are not enough if another mod changes profile career order differently.
- A client missing Pusfume may interpret index 5 as nil or as a different future career.
- Hot join requires the same registry before profile synchronization arrives.
- The host must remain authoritative for ability state and any spawned gameplay units.
- A pre-selection handshake should reject mismatched protocol/registry versions instead of attempting a spawn.

VMF `mod:network_register` is suitable for custom mod messages such as a version handshake or an ability's small scalar state. Vanilla RPCs and `NetworkLookup` IDs are still required when using engine systems that serialize buff, item, damage-profile, effect, sound, or game-object IDs.

## 4. Spawn and player-unit construction

The main spawn sequence is split between `scripts/managers/player/bulldozer_player.lua` and `player_bot.lua`:

1. Resolve the profile and career from numeric indexes.
2. Resolve the selected skin, frame, pose, weapons, and initial inventory.
3. Resolve `career.breed` or fall back to `profile.breed`.
4. Read `OverchargeData[career_name]` and `EnergyData[career_name]`.
5. Convert career state-name lists into actual state classes.
6. Build extension initialization data.
7. Spawn the first-person or bot unit and its third-person representation.

A custom breed can be small. Official career breeds in `player_breeds_cog.lua` and `player_breeds_shovel.lua` primarily set armor category, threat, hero flags, status settings, and `PlayerBreedHitZones.player_breed_hit_zones`. Missing `hit_zones` is a hard spawn problem.

For the donor milestone, reusing the donor breed is safer than creating a nominal custom breed. Introduce a custom breed only when Pusfume needs distinct breed-keyed behavior.

## 5. Package synchronization and asset loading

`scripts/game_state/components/profile_synchronizer.lua` builds two package sets for every player: owner first-person packages and remote third-person packages. It includes:

- Every equipped weapon or career-skill weapon package
- Attachment units and material-change packages
- Skin first-person, bot, third-person, husk, and attachment units
- `career.package_name`
- `career.requires_packages`
- Packages required by selected talents
- Packages returned by `career.talent_packages`
- Every item in `career.additional_inventory`

The combined package names are hashed. Every peer loads the required set and acknowledges the same inventory generation before the player is considered synchronized. A bad package path can stall or fail multiplayer spawning even when the local preview appears to work.

Package rules for Pusfume:

- Keep a stable `resource_packages/pusfume/pusfume` root in `pusfume.mod`.
- List all custom unit, material, texture, effect, and sound-bank dependencies in the package source.
- Separate first-person and third-person assets where possible so remote clients do not load owner-only resources.
- Test package unload/reload by changing hero, returning to Keep, and hot joining.
- Never reference extracted game assets from this public repository. Reference installed game resources by path or ship only authorized originals.

## 6. Units, skins, and cosmetics

`scripts/settings/profiles/base_units.lua` defines shared player containers:

- All heroes use the same first-person base and first-person bot base.
- Each hero profile has its own third-person, bot, and husk base containers.

The selected entry in `Cosmetics[skin_name]` supplies the visible meshes:

- `first_person` and `first_person_bot`
- `third_person`, `third_person_bot`, and `third_person_husk`
- `first_person_attachment.unit` and its node-linking table
- `third_person_attachment.unit` and its hero-specific node-linking table
- Optional material-change package and first/third-person material substitutions

Official examples are `scripts/settings/dlcs/cog/cosmetics_cog.lua` and `scripts/settings/dlcs/shovel/cosmetics_shovel.lua`. Their base containers remain Bardin/Sienna containers while the attachment units contain the career-specific visible bodies.

A complete original Pusfume visual requires:

1. A compiled first-person arms/weapon-contact mesh unit.
2. A compiled third-person body mesh unit.
3. Bardin-compatible skeleton names, hierarchy, rest pose, and attachment nodes, or a deliberately custom player container and animation graph.
4. A `Cosmetics.pusfume_skin` entry using Bardin's base containers and node linking.
5. An `ItemMasterList.pusfume_skin` cosmetic item with `can_wield = { "pusfume" }`.
6. Packages containing both mesh units, materials, textures, and dependencies.
7. A valid fallback `base_skin` so the career can spawn without backend cosmetic data.

The low-risk art path is to preserve Bardin's skeleton and base containers. Replacing the complete animated player base is much larger than replacing the attached visible meshes.

## 7. Activated abilities

`scripts/unit_extensions/default_player_unit/careers/career_extension.lua` initializes one or more activated abilities. Every entry must choose exactly one implementation style.

### 7.1 Action-driven ability

An action-driven entry has `action_name`, cooldown, UI text/icon, and optionally a career-skill weapon. It needs:

- An action name in `CareerActionNames[profile_name]`
- A corresponding `ActionTemplates[action_name]`
- Action implementation classes loaded before use
- Career-skill weapon item/template and packages when applicable
- Any action/sub-action, item, damage, effect, or sound lookup IDs used over the network

Ranger Veteran, Engineer, Grail Knight, Sister, Warrior Priest, and Necromancer all demonstrate action-driven career weapons or actions.

### 7.2 Class-driven ability

A class-driven entry has `ability_class` instead of `action_name`. The class owns activation, update, and cleanup behavior. Slayer is a compact base-game example. This is attractive for a first custom ability because it can avoid a new weapon/action template, but custom state still needs explicit host/client synchronization.

### 7.3 Career extension behavior

The extension manages:

- Cooldown and maximum cooldown
- Charges and extra uses
- Ability UI game-object fields
- Career skill weapon selection
- Passive-class lifetime
- Activation notifications and RPC routing through `career_system.lua`

For Pusfume's first original ability, prefer one host-authoritative ability with no custom projectile or spawned game object. Add a custom unit only after cooldown, interruption, death cleanup, and late-join state are proven.

## 8. Passive abilities, talents, and buffs

### 8.1 Passive settings

`PassiveAbilitySettings[career_key]` can contain:

- Local/server `buffs`
- Remote `husk_buffs`
- UI display name, description, icon, and perk descriptions
- One or more `passive_ability_classes` with optional initialization data

`CareerExtension:extensions_ready` applies the appropriate buffs based on server, local-owner, bot, or husk role and creates passive classes.

### 8.2 Talent registry construction

`scripts/managers/talents/talent_settings.lua` loads base and DLC talent files, then builds the global `TalentIDLookup`. The standard shape is six rows by three columns, unlocked at hero levels 5, 10, 15, 20, 25, and 30.

An official talent file:

1. Defines buff tweak data and buff templates.
2. Appends one six-by-three tree to `TalentTrees[hero_name]`.
3. Appends 18 talent records to `Talents[hero_name]`.
4. Merges templates into `TalentBuffTemplates[hero_name]`.
5. Optionally defines `WeaveLoadoutSettings[career_name]`.

A runtime mod must perform the post-load bookkeeping itself:

- Every talent name must be globally unique.
- Append talent records in deterministic order.
- Add a `TalentIDLookup[name] = { talent_id, hero_name }` entry.
- Annotate tree/row/column when code or UI expects those fields.
- Register every new buff template before selected talents are synchronized.
- Add localization for name, description, and description values.

### 8.3 Runtime application and synchronization

`talent_extension.lua` asks the backend talent interface for talent IDs, applies client/server/all buffs, loads talent packages, and sends IDs through `rpc_sync_talents`. `husk_talent_extension.lua` applies the synchronized IDs on remote units.

Selected values are columns, but the networked values are hero-local talent IDs. A different `Talents[hero_name]` append order between peers makes the same numeric ID refer to different behavior.

Buff names used by vanilla buff RPCs must exist in both directions in `NetworkLookup.buff_templates`. Use one deterministic registration helper and make it idempotent. Do the same for custom damage profiles, item names, effects, sounds, actions, sub-actions, projectiles, and game-object types whenever those engine systems serialize the name as an integer.

## 9. Items, loadouts, and the PlayFab boundary

`scripts/managers/backend_playfab/backend_interface_item_playfab.lua` iterates `CareerSettings` entries with a non-nil `playfab_name` and asks the backend mirror for character data in each loadout slot. `backend_interface_talents_playfab.lua` does the same for six talent columns.

Fatshark's backend does not know a new `pusfume` character record. Setting `playfab_name = "pusfume"` does not create one and causes empty or invalid cache paths.

`scripts/managers/backend/backend_utils.lua` routes all item requests through the career name. Missing cosmetic IDs do not automatically produce a backend record; spawn code falls back to `base_skin`, frame, and pose where possible.

### 9.1 Donor adapter

The current prototype leaves `playfab_name` nil and translates Pusfume item/talent interface methods to `dr_ranger`. This makes the first network/spawn test practical, but changing Pusfume equipment or talents can also change Ranger Veteran data.

### 9.2 Recommended local persistence

The production adapter should maintain independent VMF settings:

- Six talent column selections under a Pusfume-specific key
- Backend item IDs for melee, ranged, necklace, ring, trinket, skin, hat, frame, and pose
- Validation that each stored item still exists and can be wielded
- Donor/default fallback when an item was removed or ownership changed
- Separate bot selections if bots can use the career

The public `dalokraff/noback` repository proves the viability of replacing PlayFab talent and item state with `mod:get`/`mod:set` data. It is a useful persistence reference, not a complete custom-career implementation.

### 9.3 Item permissions and new items

Every usable item has a `can_wield` list. Donor weapons must add `pusfume` at runtime, except global sentinel tables such as `CanWieldAllItemTemplates` that must not be mutated.

A completely new item additionally needs:

- `ItemMasterList[item_name]`
- `NetworkLookup.item_names` in both directions
- Damage-source lookup when it can deal damage
- Weapon/item template registration
- First- and third-person units and packages
- Action/sub-action lookup coverage
- Backend representation or a local fake/mod-item interface

The public `Aussiemon/VT2-More-Items-Library` repository documents and implements these runtime item registrations. It explicitly warns that peers with mismatched item lists can crash.

## 10. UI surfaces

### 10.1 Modern Hero View

`scripts/ui/views/hero_view/windows/hero_window_character_selection_console.lua` iterates every profile's complete `careers` array and creates one widget per career. It therefore creates a real fifth Bardin widget. The Pusfume hook moves that widget to the first row's unused top-right position while retaining vanilla click, preview, lock, and selection data.

The widget path expects valid localization and portrait keys. Donor textures can be used until original UI atlases are compiled.

### 10.2 Five-row character selection grid

`scripts/ui/views/character_selection_view/states/character_selection_state_character.lua` contains a literal `for j = 1, 4` while constructing career widgets, so vanilla never creates a widget for career index 5. Its later update loops already iterate all careers, allowing a carefully ordered fifth widget to reuse native selection behavior.

Pusfume supplies the missing fifth Bardin widget with the same `UIWidgets.create_hero_widget` definition used by the game. It inserts the widget immediately after Bardin's four careers in the flattened `_hero_widgets` array and increments only Bardin's `_num_hero_columns` entry. The card remains logically career index 5 for native mouse and controller selection, while its scenegraph offset places the full-size `110x130` widget at column 5 and one `144`-unit row above Saltzpyre. These are virtual UI coordinates and scale through VT2's normal resolution lookup at 4K.

The `/pusfume` command remains the safe fallback because it uses the vanilla host-mediated `ProfileRequester` path.

### 10.3 Other UI assumptions

Audit these surfaces whenever Pusfume stops being a pure donor:

- Hero summary and loadout windows
- Talent window and talent-tree descriptions
- Cosmetics inventory and world hero previewer
- HUD ability cooldown and charge display
- Additional resource/pet HUD components
- End screen, scoreboard, player portrait, and social UI
- Bot-career and bot-priority selection

`unit_frame_ui.lua` falls back to the career extension's cooldown when `playfab_name` is nil, which is helpful for a custom career.

## 11. Bot behavior

`scripts/settings/player_bots_settings.lua` defines `BotActions.default.use_ability[career_name]`. `scripts/entity_system/systems/behaviour/nodes/bot/bt_bot_conditions.lua` checks:

- Whether the career is in an ability category
- `BTConditions.can_activate[career_name]`
- Optional `BTConditions.reload_ability_weapon[career_name]`

DLC files such as `cog_bot_conditions.lua` and `shovel_bot_conditions.lua` merge their career into these tables. A custom career without entries simply never activates its ability and can fail behavior-tree expectations.

Pusfume currently aliases Ranger Veteran's action, category, activation condition, and reload behavior. A custom ability needs its own condition based on target validity, threat, nearby allies/enemies, resource state, and cooldown. Test human disconnect takeover, host migration boundaries, death, rescue, and replacement bot spawning.

## 12. Mechanism-specific behavior

### 12.1 Adventure

Adventure is the minimum supported mechanism. Profile reservation, normal backend inventory, spawn, and Hero View paths are the least specialized here.

### 12.2 Chaos Wastes / Deus

`scripts/managers/game_mode/mechanisms/deus_mechanism.lua` snapshots `DEUS_CAREERS` at module load. It then expects each career in that list to have:

- Hero and bot loadouts in backend tables
- Talent selections
- Weapon conversion through `DeusStartingWeaponTypeMapping`
- Fallback entries in `DeusDefaultLoadout`
- Valid career data for run-controller profile synchronization

A runtime-added career may miss the snapshot entirely or enter later code without default loadouts. Supporting Chaos Wastes requires deliberate insertion before setup plus full default weapon/talent mappings.

### 12.3 Weaves

Weaves use fixed `WeaveLoadoutSettings[career_name]` and process each configured tree into talent, property, and trait maps. A custom career needs a complete weave loadout or must set `excluded_from_weave_loadouts` and remain unavailable.

### 12.4 Versus

Versus has separate career settings, loadout selection, party selection, preview, level/progression, and mechanism overrides. It also has balance-specific ability values. Pusfume should remain disabled until every participant, selector, loadout, and network path is explicitly supported.

The current Adventure-only gate is intentional. Unsupported mechanisms should return a clear lock reason before selection, not fail during spawn.

## 13. Mechanism overrides and snapshots

`scripts/managers/game_mode/game_mechanism_manager.lua` restores careers from `CareerSettingsOriginal` and merges `mechanism_overrides[current_mechanism]`. `scripts/managers/game_mode/mechanisms/mechanism_overrides.lua` also resolves nested override tables and caches results.

This is why a runtime career must be present in both `CareerSettings` and `CareerSettingsOriginal`. It must also invalidate or avoid stale mechanism caches after registration. Reapply custom fields after VMF reload because live tables may survive while mod-local state does not.

## 14. Localization, portraits, audio, and dialogue

Localization keys are sufficient for text; VMF's localization file or a narrow `Localize` fallback can provide them. A complete career needs keys for:

- Career name and description
- Passive name, description, and perks
- Ability name and description
- All talent names and descriptions
- Lock reasons and any custom HUD labels

Portraits and icons are texture/material resources, not arbitrary disk PNG paths. Until compiled UI resources exist, donor texture keys are the reliable fallback.

`sound_character` selects the dialogue identity. Official DLC careers also register dialogue lookups, dialogue settings, auto-load files, network sound events, Wwise banks, and optional `unique_subtitles`. Original voice work is therefore a separate content pipeline. Reusing Bardin's sound character is safer than pointing to nonexistent events.

Any sound event sent through vanilla network sound RPCs must be present in `NetworkLookup.sound_events` on every peer. Local-only Wwise events still need the correct bank loaded in the package.

## 15. Advanced career systems

Sister of the Thorn and Necromancer show how quickly a career can expand beyond the core contract. Their DLC common settings register combinations of:

- New systems and entity extensions
- Unit extension templates
- Spawn unit templates and husk mappings
- Network game-object types, templates, initializers, and extractors
- Projectiles, damage types, DOT mappings, effects, and material mappings
- Behavior-tree enter/leave hooks
- Health, prop, area-damage, pet, or commander extensions
- Additional HUD components

Do not copy this complexity preemptively. Add only the subsystem a concrete ability needs. A Pusfume summon, deployable, or persistent concoction would require explicit ownership, husk spawning, late-join reconstruction, death cleanup, and network object serialization.

## 16. Runtime implementation order for Pusfume

### Phase A: prove the distinct career identity

- Keep `pusfume` appended as Bardin career index 5.
- Deep-clone Ranger Veteran settings and retain donor breed, skin, ability, passive, tree, and items.
- Keep `playfab_name` nil.
- Keep Adventure-only availability.
- Use `ProfileRequester` for every selection path.
- Add a protocol handshake before multiplayer selection.

Exit criteria: host and client can select, spawn, die, respawn, rescue, switch away, switch back, hot join, and transfer to a bot with no desync.

### Phase B: independent persistence

- Replace donor write-through with Pusfume-local item IDs and talent columns.
- Keep donor defaults only as fallback values.
- Validate ownership and `can_wield` before exposing stored items.
- Resync packages after every loadout change.

Exit criteria: changing Pusfume no longer changes Ranger Veteran, and reconnecting restores the Pusfume loadout.

### Phase C: original passive and talents

- Append a fifth Bardin talent tree and 18 unique talent records.
- Register buff templates and lookup IDs deterministically.
- Implement host/server/client/husk buff roles deliberately.
- Add localization and donor icons initially.

Exit criteria: all 18 choices apply correctly for host, client, bot, and remote husk after respawn and hot join.

### Phase D: original ability

- Choose class-driven or action-driven architecture.
- Keep the first version host-authoritative and unit-free.
- Add cooldown, charge, cancel, death cleanup, and UI state.
- Add mod RPC state only where vanilla career extension state is insufficient.

Exit criteria: repeated activation is deterministic under latency, interruption, death, and join-in-progress.

### Phase E: original assets and presentation

- Register Pusfume skin cosmetic and local item.
- Compile first-person arms and third-person body attachments.
- Add portrait/icon resources and preview configuration.
- Add hats/props only after the base body works.
- Add original audio last.

Exit criteria: owner, remote client, bot, previewer, inventory, scoreboard, and respawn all show the correct assets with no missing package warnings.

### Phase F: optional mechanisms

- Add Chaos Wastes default weapons, talent/loadout maps, and snapshot insertion.
- Add Weave loadout settings or stay excluded.
- Treat Versus as a separate implementation and balance project.

## 17. Failure modes and likely causes

| Symptom | Likely cause |
| --- | --- |
| Career card exists but selection returns the wrong career | Profile career arrays differ or a name resolved to a different index. |
| Host works but client crashes on selection | Mismatched career, item, buff, action, or damage-profile lookup IDs. |
| Spawn waits forever | A required first/third-person package is missing or never reports loaded. |
| Invisible body or arms | Missing cosmetic attachment unit, package, or node linking. |
| Nil career after mechanism switch | Missing `CareerSettingsOriginal` entry or stale mechanism override cache. |
| Ability icon appears but activation does nothing | Missing action template, ability class, input/action binding, or bot/human condition. |
| Ability works once and sticks | Cooldown, charge, interruption, or death cleanup is incomplete. |
| Talents show but apply the wrong buffs | `TalentIDLookup` or `Talents[hero]` order differs between peers. |
| Remote player lacks passive behavior | Missing `husk_buffs`, passive class handling, or talent RPC registration. |
| Weapons disappear from loadout | `can_wield`, local backend IDs, or slot maps do not include Pusfume. |
| Ranger Veteran changes when Pusfume changes | Donor adapter is still write-through instead of locally persisted. |
| Bot never uses the ability | Missing BotActions category and `BTConditions.can_activate` entry. |
| Chaos Wastes errors on run start | Missing Deus career snapshot, loadout, or weapon conversion defaults. |
| Legacy selection screen cannot find Pusfume | Its widget construction is hardcoded to four careers. |

## 18. Multiplayer test matrix

Run each milestone with matching builds on all peers:

1. Solo Keep selection and repeated career switching.
2. Solo mission spawn, death, ledge, disable, rescue, respawn, and map transition.
3. Host selects Pusfume before a client joins.
4. Client selects Pusfume while host remains another hero.
5. Client hot joins while host is already Pusfume.
6. Pusfume disconnects and is taken over by a bot.
7. Pusfume bot is replaced by a joining human.
8. Loadout and talent changes trigger package resync without disconnect.
9. Ability activation under latency, interruption, death, and repeated use.
10. Deliberately mismatched mod version is rejected before profile selection.
11. Return to Keep and start a second mission without restarting the game.
12. Disable the mod after returning to Keep and confirm official Bardin careers remain valid.

Collect host and client logs for every failure. The first useful values are profile index, career index, registry protocol version, inventory hash/generation, package name, and lookup name/ID.

## 19. Source reference index

Core registration:

- `scripts/settings/profiles/career_settings.lua`
- `scripts/settings/profiles/sp_profiles.lua`
- `scripts/settings/dlcs/*/*_common_settings.lua`
- `scripts/settings/dlcs/*/*_profiles.lua`

Selection, synchronization, and spawn:

- `scripts/utils/profile_requester.lua`
- `scripts/game_state/components/profile_synchronizer.lua`
- `scripts/managers/player/player_manager.lua`
- `scripts/managers/player/bulldozer_player.lua`
- `scripts/managers/player/player_bot.lua`

Abilities, passives, and talents:

- `scripts/unit_extensions/default_player_unit/careers/career_extension.lua`
- `scripts/unit_extensions/default_player_unit/careers/career_utils.lua`
- `scripts/entity_system/systems/career/career_system.lua`
- `scripts/unit_extensions/default_player_unit/careers/career_ability_settings.lua`
- `scripts/managers/talents/talent_settings.lua`
- `scripts/unit_extensions/default_player_unit/talents/talent_extension.lua`
- `scripts/unit_extensions/default_player_unit/talents/husk_talent_extension.lua`

Inventory, backend, and packages:

- `scripts/managers/backend/backend_utils.lua`
- `scripts/managers/backend_playfab/backend_interface_item_playfab.lua`
- `scripts/managers/backend_playfab/backend_interface_talents_playfab.lua`
- `scripts/unit_extensions/default_player_unit/inventory/simple_inventory_extension.lua`
- `scripts/unit_extensions/default_player_unit/inventory/simple_husk_inventory_extension.lua`
- `scripts/network_lookup/network_lookup.lua`

Units, cosmetics, and UI:

- `scripts/settings/profiles/base_units.lua`
- `scripts/utils/cosmetics_utils.lua`
- `scripts/settings/dlcs/cog/cosmetics_cog.lua`
- `scripts/settings/dlcs/shovel/cosmetics_shovel.lua`
- `scripts/ui/views/hero_view/windows/hero_window_character_selection_console.lua`
- `scripts/ui/views/character_selection_view/states/character_selection_state_character.lua`
- `scripts/ui/views/world_hero_previewer.lua`

Bots and mechanisms:

- `scripts/settings/player_bots_settings.lua`
- `scripts/entity_system/systems/behaviour/nodes/bot/bt_bot_conditions.lua`
- `scripts/settings/dlcs/*/*_bot_conditions.lua`
- `scripts/managers/game_mode/game_mechanism_manager.lua`
- `scripts/managers/game_mode/mechanisms/mechanism_overrides.lua`
- `scripts/managers/game_mode/mechanisms/deus_mechanism.lua`
- `scripts/settings/weaves/weave_loadout/weave_loadout_settings.lua`

## 20. Public repository findings

- [Aussiemon/Vermintide-2-Source-Code](https://github.com/Aussiemon/Vermintide-2-Source-Code) is the primary source mirror used for this map.
- [Vermintide-Mod-Framework/Vermintide-Mod-Framework](https://github.com/Vermintide-Mod-Framework/Vermintide-Mod-Framework) supplies the runtime hook, settings, localization, package, and mod-network layer.
- [dalokraff/noback](https://github.com/dalokraff/noback) demonstrates local loadout and talent persistence without PlayFab.
- [Aussiemon/VT2-More-Items-Library](https://github.com/Aussiemon/VT2-More-Items-Library) demonstrates runtime item and lookup registration.
- [Janoti1/Vermintide2_Mods](https://github.com/Janoti1/Vermintide2_Mods) demonstrates runtime talent replacement, buff registration, and VMF setting synchronization.

No reviewed public repository implements a complete new VT2 hero career end to end. Existing projects mostly modify official careers or replace backend behavior. The official DLC career files are therefore the authoritative architecture, and the public mods are implementation precedents for specific runtime gaps.
