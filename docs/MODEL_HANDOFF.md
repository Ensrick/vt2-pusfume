# Pusfume Model Handoff

## Validated payload

The July 2026 handoff is an intentional placeholder built on a slave-rat `.unit`. It contains a complete third-person mesh, a walk-cycle FBX, 23 texture maps, and a Blender 5.2 source project. The armature will be overhauled for the final character, but its material slots and texture assignment are intended to carry forward. The source project was Zstandard-compressed before upload and retained a `.blend` extension; decompress it once before opening it in Blender 5.2 or newer. The FBX exports are immediately readable by Blender 3.6.

The third-person FBX contains:

- One 13,100-vertex, 24,318-triangle mesh named `p_mainbody`.
- One 82-bone armature named `pusfume_slaverat`.
- One UV layer and nine material slots.
- 77 vertex groups with no unweighted vertices.
- 24 vertices with five influences; `tools/prepare_pusfume_fbx.py` reduces these to the VT2 limit of four and normalizes the result.

The walk FBX contains three near-duplicate actions on the same 82-bone rig. Each action covers frames 1 through 25 at 30 FPS and closes cleanly at the loop boundary. Keep one canonical action in future exports. The native build uses the action currently assigned to the imported walk armature and merges it into the skinned model before Stingray compilation.

## Runtime architecture

The closest Fatshark donor is the playable Versus Globadier:

- Base: `units/beings/player/dark_pact_third_person_base/skaven_wind_globadier/chr_third_person_base`
- Husk: `units/beings/player/dark_pact_third_person_base/skaven_wind_globadier/chr_third_person_base_husk`
- Skin pattern: `units/beings/player/dark_pact_skins/skaven_wind_globadier/.../chr_third_person_mesh`
- Career: `CareerSettings.vs_poison_wind_globadier`
- Profile: `vs_poison_wind_globadier` using `player_unit_dark_pact`

Fatshark keeps the animated base and visible skin as separate units. The skin mesh is driven by `World.link_unit` calls for individual skeleton nodes. Pusfume therefore needs to compile as a third-person skin attachment, not as a self-animating replacement player unit.

Pusfume deliberately retains the VT2 slave-rat hierarchy and uses Janfon's symmetrized names such as `j_arm_L`, while the playable Globadier base uses names such as `j_leftarm`. The custom bridge in `_pusfume_assets.lua` maps 52 locomotion, limb, finger, tail, and weapon nodes from the Bardin donor parent to the Pusfume child. Extra Pusfume facial and accessory bones remain under their linked ancestors. Live testing confirms the bridge deforms the placeholder without gross rest-pose failure; it does not constrain the final armature overhaul.

## Material reconstruction

The FBX preserves all nine material slots but only the eye image links. Use this initial diffuse assignment when authoring the compiled material resources:

| Material | Diffuse texture |
| --- | --- |
| `p_main` | `pusfume_body_new_df.png` |
| `p_metal` | `wpn_skaven_set_df.png` |
| `p_glob` | `globadier_outfit_df.png` |
| `p_armor` | `stormvermin_outfit_df.png` |
| `p_ammo_box_limited_a` | `generic_cloth_dirty_df.png` |
| `p_ammo_box_limited_b` | `pup_ammo_box_limited_df.png` |
| `p_whiskers` | `pusfume_whiskers_df.png` |

The eye slots need a deliberate VT2 eye/emissive material rather than the imported Blender graph. Janfon's graph supplies eye color and an emissive mask but no eye normal or response maps, so the native atlas leaves those channels neutral. Normal and specular maps for the other opaque slots use their matching `_nm` and `_s` files. Whiskers need alpha clipping or the engine-equivalent cutout shader.

## Compiler gate

VT2's SDK batch compiler accepts a skinned FBX through a same-name `.dcc_asset` and text `.unit` descriptor. The supported DCC path is the default; the handwritten `.bsi` exporter remains an explicit diagnostic fallback.

The repository now provides `tools/export_blender_bsi.py` as an account-free final hop. On the validated handoff, Blender 5.2 exports 24,318 triangles, nine material slots, 82 skeleton nodes, inverse bind matrices, and normalized four-influence streams. Fatshark's SDK compiler accepts the result and produces one native skin with 82 joint nodes, nine material bone sets, `HALF4` weights, and packed `UINT1` blend indices. The exporter also writes one rest-pose frame for every skeleton and mesh node plus a same-name `.bones` skeleton source.

The `.bones` resource only identifies nodes controlled by an animation controller; it does not evaluate skin deformation by itself. A static DCC model compiled 82 valid skin binds but no unit animation group, and remained rigid while Lua successfully advanced the separate clip. `tools/prepare_animated_pusfume_fbx.py` now merges Janfon's baked action onto the skinned model before DCC import and verifies deformation in Blender. The resulting unit preserves the 82 DCC binds and adds one activation group covering all 86 scene nodes. The native build still compiles `pusfume_3p_walk.fbx` through a same-name `.animation` recipe, packages a minimal same-path `.state_machine`, and points the unit at that controller.

The mesh materials must also select a full-character skinning shader permutation. In live testing, both the generic `core/stingray_renderer/shader_import/standard` parent and the embedded standard-base graph adapted from Tweaker: Cosmetics rendered Pusfume's textures while the evaluated 82-bone skin remained visually rigid. Laurel's auxiliary plume was not sufficient proof for a complete player body. The successful Track D-E build loads the installed Globadier package, resolves the child against the game-owned character parent, and replaces the SDK child's generated payload with a locally extracted 768-byte game child binding table. It then patches and verifies `texture_map_02af90f8` as Pusfume diffuse, leaves `texture_map_27b67fd2` on the donor black emissive map, patches `texture_map_8bf37d8e` to Pusfume normal-plus-gloss, and neutralizes the donor `emissive_color`. Whiskers retain the existing cutout graph. Every resource is preflighted and both packages are released on unload.

Because one donor resource cannot retain different texture values for eight material slots, the native build generates a 4096-square atlas and remaps the opaque FBX loops before compilation. The body keeps its full 2048x4096 source resolution. Eye, ammo-box, and Globadier regions receive repeated guard tiles so Janfon's UVs outside the 0-1 range preserve wrapping without sampling a neighboring surface. The successful child payload binds the atlas resource IDs directly; earlier runtime `Material.set_texture` and `Unit.set_texture_for_materials` attempts reported success but did not rebind game-owned character materials. With every opaque slot on one shared atlas, identical per-slot values make material-instance sharing harmless.

The donor-material direction matches the only known precedent of a visibly animated custom-FBX character in retail VT2. The original public `dalokraff/pusfume` inn NPC compiled custom skinned geometry with hand-authored `.unit`, `.bones`, `.state_machine`, and `.animation` recipes, and every one of its `.unit` files points its surfaces at donor game materials rather than mod-compiled ones (`wpn_we_dagger_01_t1_runed_01_3p` for the body set, `mtr_outfit_black_and_gold_3p` for fur). No `.material` source exists anywhere in that project. The current donor path is hash-verified offline: Murmur64(`units/beings/player/dark_pact_skins/skaven_wind_globadier/skin_1001/third_person/mtr_outfit`) = `90BDF3BAC6F81BA8`, and the decompiled material with that ID carries the three confirmed texture channels and no embedded shader payload.

Dalokraff's fur source consists of 510 disconnected alpha-card triangles on a skeleton unrelated to Janfon's 82-bone rig, so its original skin weights cannot be reused directly. The Blender merge strips the duplicate legacy whiskers, moves each fur triangle as one rigid island from the legacy body surface to Janfon's body, and transfers Janfon's nearest-surface weights afterward. The merge fails if average body fit does not improve, any authored edge changes by more than `0.00001` units, any vertex remains unweighted, or the walk action does not deform the fur. The validated probe improved mean surface distance from `0.10691` to `0.03179`, retained all 510 triangles within `0.00000012` maximum edge error, and remained attached in rest and mid-walk audit renders.

Use `tools/Build-NativePusfume.ps1 -HeroPreview -LegacyFur` for the confirmed private native build and deployment. `-LegacyFur` selects the Pusfume-named skinned-cutout material and forces the verified game-child binding path. Add `-NoDeploy` only for an intentional offline compiler pass. Use `tools/Test-BsiPipeline.ps1` only to reproduce the handwritten BSI fallback. Maya is no longer required for Pusfume's geometry, skin, or baked-action merge. A Maya trial can still serve as a reference exporter if later animation or edge-case parity work needs an independent comparison.

Compiler success alone does not prove deformation, but ManifestID `2405082174877027150` now provides the live visual baseline: textured hero preview, textured in-game attachment, generated idle, Janfon walk cycle, and no inherited green underglow. Remote-husk deformation and all states beyond idle/walk remain unverified.

## Publication boundary

Keep this handoff outside Git. Janfon confirmed that the placeholder is assembled from exported VT2 Skaven assets; only Pusfume's skin base color and eyes are original. The friends-only native Workshop build currently contains compiled output from those private assets and a patched game child binding payload. Preserve friends-only visibility and complete provenance review before broader publication. The final public path should package only original or clearly redistributable content.

## Remaining asset acceptance

1. Preserve the confirmed idle/walk baseline while adding clips one state at a time.
2. Test sprint, crouch, jump/fall, dodge, ledge hang, downed, death, and weapon actions.
3. Test remote-husk deformation with a second player on the identical manifest.
4. Request separate first-person arms and weapon hand poses from Janfon.
5. Repeat the material and atlas regression checks after the final armature overhaul.
