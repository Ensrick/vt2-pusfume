# VT2 Career System Map

This map targets Vermintide 2 source version 6.11.3. Paths refer to Fatshark's Lua source tree and are research references; game source is not copied into this repository.

## Boot-time registries

1. `scripts/settings/profiles/career_settings.lua` creates `CareerSettings`, loads DLC career setting files, then snapshots `CareerSettingsOriginal`.
2. `scripts/settings/profiles/sp_profiles.lua` creates `SPProfiles`, loads DLC profile files, and builds `PROFILES_BY_NAME`, `PROFILES_BY_CAREER_NAMES`, `career_index_from_name`, and `hero_and_career_name_from_index`.
3. The same profile file derives each career's character and camera state lists after all official careers are present.
4. DLC careers call `add_career_to_profile(profile_name, career)` from their profile file.

A runtime mod loads after those boot-time passes. It must therefore update the career table, original snapshot, profile career array, reverse lookup, and derived state lists itself. Pusfume's registry does all five idempotently.

## Network identity and spawning

`ProfileRequester:request_profile` resolves a profile name and career name into numeric `profile_index` and `career_index`. Those indexes are sent to the host, reserved by the active mechanism, synchronized to the party, and used to initialize the player unit. Pusfume is appended deterministically as Bardin career index 5, so every peer must run the same Pusfume version before anyone selects it.

The career index selects a `CareerSettings` entry. Its breed, package, skin, abilities, passive, state lists, and profile data drive player initialization. The prototype reuses Ranger Veteran resources while preserving the distinct runtime identity `pusfume`.

## Backend boundary

PlayFab only returns server-defined character records. A client mod cannot add a durable `pusfume` record to Fatshark's backend. Official item and talent interfaces populate their caches by official career name, and direct writes to an unknown career would be invalid.

The prototype solves this with a narrow adapter:

- Pusfume item reads and writes are translated to `dr_ranger` at `BackendInterfaceItemPlayfab`.
- Pusfume talent reads and writes are translated to `dr_ranger` at `BackendInterfaceTalentsPlayfab`.
- Items usable by Ranger Veteran receive `pusfume` in their runtime `can_wield` list.
- `playfab_name` remains unset on Pusfume so vanilla cache refresh loops do not query a nonexistent backend character.

The next persistence milestone should keep a Pusfume loadout in VMF settings and store owned backend item IDs locally instead of writing through to Ranger Veteran.

## UI boundary

The modern Hero career selector iterates `profile.careers` and can display a fifth entry. The older character-selection screen contains a literal `for j = 1, 4`, so it does not expose Pusfume. The `/pusfume` command calls the same host-mediated `ProfileRequester` used by vanilla UI and is the supported fallback.

## Talent and ability boundary

A career points at `TalentTrees[profile_name][talent_tree_index]`, `ActivatedAbilitySettings`, and `PassiveAbilitySettings`. Selected columns are converted through `TalentIDLookup` into buff IDs at spawn. Pusfume initially points at Ranger Veteran's tree and ability tables. A custom tree can be added once every talent has unique names, buff templates, localization, and host/client-safe proc behavior.

## Replacement milestones

1. Replace the donor loadout adapter with local Pusfume persistence.
2. Add a Pusfume talent tree and passive buff templates.
3. Add Moulder Ingenuity as a synchronized ability with explicit consumable state.
4. Import original third-person and first-person units and replace the donor skin/unit resources.
5. Add portraits, icons, audio policy, bot conditions, and Chaos Wastes/Weaves compatibility.
6. Add peer-version enforcement before allowing career selection.

