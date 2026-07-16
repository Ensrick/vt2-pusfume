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

Pusfume deliberately retains the VT2 slave-rat hierarchy and uses Janfon's symmetrized names such as `j_arm_L`, while the playable Globadier base uses names such as `j_leftarm`. The custom bridge in `_pusfume_assets.lua` maps 52 locomotion, limb, finger, tail, and weapon nodes from the Bardin donor parent to the Pusfume child. Extra Pusfume facial and accessory bones remain under their linked ancestors. The first live test must check rest-pose distortion; this bridge is for the placeholder and does not constrain the final armature overhaul.

## Material reconstruction

The FBX preserves all nine material slots but only the eye image links. Use this initial diffuse assignment when authoring the compiled material resources:

| Material | Diffuse texture |
| --- | --- |
| `p_main` | `pusfume_body_new_df.png` |
| `p_metal` | `wpn_skaven_set_df.png` |
| `p_glob` | `globadier_outfit_df.png` |
| `p_armor` | `stormvermin_outfit_df.png` |
| `p_ammo_box_limited_a` | `pup_ammo_box_limited_df.png` |
| `p_ammo_box_limited_b` | `pup_ammo_box_limited_df.png` |
| `p_whiskers` | `pusfume_whiskers_df.png` |

The eye slots need a deliberate VT2 eye/emissive material rather than the imported Blender graph. Normal and specular maps should use their matching `_nm` and `_s` files. Whiskers need alpha clipping or the engine-equivalent cutout shader.

## Compiler gate

VT2's SDK batch compiler accepts a skinned FBX through a same-name `.dcc_asset` and text `.unit` descriptor. The supported DCC path is the default; the handwritten `.bsi` exporter remains an explicit diagnostic fallback.

The repository now provides `tools/export_blender_bsi.py` as an account-free final hop. On the validated handoff, Blender 5.2 exports 24,318 triangles, nine material slots, 82 skeleton nodes, inverse bind matrices, and normalized four-influence streams. Fatshark's SDK compiler accepts the result and produces one native skin with 82 joint nodes, nine material bone sets, `HALF4` weights, and packed `UINT1` blend indices. The exporter also writes one rest-pose frame for every skeleton and mesh node plus a same-name `.bones` skeleton source.

The `.bones` resource only identifies nodes controlled by an animation controller; it does not evaluate skin deformation by itself. A static DCC model compiled 82 valid skin binds but no unit animation group, and remained rigid while Lua successfully advanced the separate clip. `tools/prepare_animated_pusfume_fbx.py` now merges Janfon's baked action onto the skinned model before DCC import and verifies deformation in Blender. The resulting unit preserves the 82 DCC binds and adds one activation group covering all 86 scene nodes. The native build still compiles `pusfume_3p_walk.fbx` through a same-name `.animation` recipe, packages a minimal same-path `.state_machine`, and points the unit at that controller.

The mesh materials must also select a full-character skinning shader permutation. In live testing, both the generic `core/stingray_renderer/shader_import/standard` parent and the embedded standard-base graph adapted from Tweaker: Cosmetics rendered Pusfume's textures while the evaluated 82-bone skin remained visually rigid. Laurel's auxiliary plume was not sufficient proof for a complete player body. The SDK cannot compile a child material against a compiled-only game parent, so the local diagnostic build instead uses VT2's proven runtime material-change path: it loads the installed Globadier `chr_third_person_mesh` package, assigns its `mtr_outfit` material to Pusfume's opaque slots, and restores Pusfume's verified diffuse (`texture_map_02af90f8`), normal (`texture_map_27b67fd2`), and packed response (`texture_map_8bf37d8e`) channels. Whiskers retain the existing cutout graph. Every resource is preflighted, the package reference is released on unload, and no extracted shader binary is committed or packaged.

Use `tools/Build-NativePusfume.ps1 -NoDeploy` to run the animated DCC preparation and SDK compilation together. Use `tools/Test-BsiPipeline.ps1` only to reproduce the handwritten BSI fallback. Maya is no longer required for Pusfume's geometry, skin, or baked-action merge. A Maya trial can still serve as a reference exporter if later animation or edge-case parity work needs an independent comparison.

Compiler success does not prove that the slave-rat rest pose matches the playable Globadier animation base. Do not ship or commit the generated placeholder until idle, locomotion, attachment, and remote-husk deformation have passed in game.

## Publication boundary

Keep this handoff outside Git. Janfon confirmed that the placeholder is assembled from exported VT2 Skaven assets; only Pusfume's skin base color and eyes are original. The public repository may eventually contain the original work through Git LFS, but it must not redistribute extracted game textures or models. Prefer compiled materials that reference resources already installed with VT2, while packaging only the genuinely original maps needed by Pusfume.

## First asset test

1. Run `tools/prepare_pusfume_fbx.py` and verify the cleaned FBX still has 13,100 vertices, 82 bones, no unweighted vertices, and at most four influences per vertex.
2. Compile the mesh as a third-person skin unit with all bridge target nodes preserved.
3. Register a temporary Pusfume skin template using `AttachmentNodeLinking.pusfume_third_person_attachment` and the stock playable Globadier base.
4. Test idle, walk, sprint, crouch, jump, dodge, ledge hang, downed, death, weapon wield, and remote husk deformation.
5. Only after third-person deformation passes, request separate first-person arms and weapon hand poses from Janfon.
