# Pusfume Asset Pipeline

Commit only original or authorized assets. Keep extracted game assets outside this public repository.

The confirmed private build and its publication boundary are documented in
[NATIVE_CHARACTER_MILESTONE.md](NATIVE_CHARACTER_MILESTONE.md).

Recommended handoff layout:

```text
art_source/pusfume.blend
art_source/textures/*.png
pusfume/units/pusfume/pusfume_3p.fbx
pusfume/units/pusfume/pusfume_1p_arms.fbx
```

## Uploading large source assets

Model and source-texture formats are tracked with Git LFS. GitHub's browser uploader cannot accept files over 25 MiB, so large assets must be added from a local clone rather than dragged into the website.

On Windows, install [Git LFS](https://git-lfs.com/) and then run:

```powershell
git clone https://github.com/Ensrick/vt2-pusfume.git
cd vt2-pusfume
git lfs install
git pull --ff-only

New-Item -ItemType Directory -Force art_source
Copy-Item "C:\path\to\pusfume.blend" art_source\pusfume.blend

git add art_source\pusfume.blend
git lfs ls-files
git commit -m "Add Pusfume model source"
git push origin main
```

`git lfs ls-files` must list the model before committing. If the file was already staged before the repository's LFS rules were pulled, run `git rm --cached art_source\pusfume.blend` and then `git add art_source\pusfume.blend` again.

Do not upload a ZIP archive when the original `.blend`, `.fbx`, and source textures can be committed directly. Git LFS lets collaborators retrieve and update the working files normally while Git stores lightweight pointers in repository history.

For Blender, export binary FBX 7.4/2014 with Selected Objects, Forward `-Y`, Up `Z`, no embedded media, no leaf bones, deform bones only, and animation baking disabled. Triangulate meshes, preserve custom normals, normalize weights, use no more than four influences per vertex, and keep the root at the origin.

The repository includes a non-destructive cleanup pass for third-person FBX files. It preserves the source file, removes unrelated scene objects, prunes each vertex to four influences, normalizes the remaining weights, and exports geometry plus the armature without baked animation:

```powershell
& "C:\Program Files\Blender Foundation\Blender 3.6\blender.exe" `
  --background --factory-startup --disable-autoexec `
  --python tools\prepare_pusfume_fbx.py -- `
  "C:\path\to\pusfume_3p.fbx" `
  "C:\path\to\pusfume_3p_clean.fbx"
```

Pusfume's current mesh uses slave-rat bone names rather than the playable Globadier names. Do not rename or retarget it merely to satisfy the stock cosmetic table: `_pusfume_assets.lua` provides the explicit parent-to-child node bridge that now deforms successfully in live testing. A true Globadier-skeleton rebind remains an optimization for the final armature.

The cleaned FBX is an interchange asset, not the final Stingray scene. The successful path gives an animated FBX to Stingray's DCC importer through a same-name `.dcc_asset` and `.unit`; the repository's Blender BSI exporter remains an account-free format diagnostic for geometry, skeleton nodes, inverse bind matrices, and four-influence skin streams. Run that fallback compiler probe with:

```powershell
.\tools\Test-BsiPipeline.ps1 `
  -InputFbx "C:\path\to\pusfume_3p_clean.fbx"
```

The probe writes only to ignored `.build` storage. It emits a compressed `bsiz` scene, creates a private throwaway unit/package, and requires Fatshark's VT2 SDK compiler to build it. A passing compile proves resource structure, not animation compatibility; complete the live deformation checklist before integrating generated assets into the Workshop package.

The exporter intentionally duplicates mesh corners in source BSI to keep UV seams and per-channel indexing unambiguous. Fatshark's compiler deduplicates the current Pusfume mesh from 72,954 source corners to 30,477 native vertices.

## Local native Workshop build

Stage and deploy the native unit without copying generated assets into the public source tree. The native build gives Janfon's FBX to Stingray's supported DCC importer by default; use `-UseBsiSkinFallback` only to reproduce the experimental handwritten BSI path:

```powershell
.\tools\Build-NativePusfume.ps1 `
  -HeroPreview `
  -LegacyFur `
  -SplicedGameChild `
  -FirstPersonBlend ".build\janfon_1p_20260717\pusfume_1p_arms 2.blend" `
  -FirstPersonDonorUnit ".build\donor_1p_extract\units\beings\player\dwarf_ranger\first_person_base\chr_first_person_mesh.unit" `
  -TextureSource ".build\pusfume_handoff\textures conv"
```

The command first runs `tools/prepare_animated_pusfume_fbx.py` through Blender 5.2. That step merges Janfon's skinned model and baked walk into one character FBX, rigidly retargets each licensed legacy fur card to the current body, and fails unless the transferred action moves the armature, body, and fur without changing authored fur edge lengths. The source FBXs remain unchanged; generated output stays under ignored `.build/generated-native`.

The command then writes only beneath ignored `.build/native-workshop`, generates VT2 texture recipes and materials from the untracked handoff, enables the native cosmetic in that staged copy, compiles it with VMB, and copies the resulting bundles into Workshop item `3764954245` by default.

When `-FirstPersonBlend` is supplied, `tools/prepare_pusfume_1p_blend.py`
finds the single armature-bound arm mesh, requires the expected left and right
arm/hand groups, removes only negligible orphan groups, and enforces four
normalized influences. `-FirstPersonDonorUnit` must point to the locally
extracted compiled
`units/beings/player/dwarf_ranger/first_person_base/chr_first_person_mesh.unit`;
the raw game unit remains ignored and must never be committed. The guarded
version-189 parser reads the donor's scene graph, and Blender rebinds every
shared bone to its exact rest matrix while preserving Janfon's world-space
rest mesh. The build rejects missing donor bones, matrix error over `0.0001`,
or mesh movement over `0.00001m`. It then exports the 99-bone attachment
without animation, links its 53 native donor nodes directly, and splices the
proven character-skin binding to Janfon's direct body diffuse and normal maps.
This path requires `-SplicedGameChild`; public source defaults remain disabled.

The 2026-07-17 handoff's `positioningtest` action spans frames 0-342. Its scale
curves are effectively constant, but several shoulder translations are real,
so it is retained as a diagnostic clip rather than installed as the gameplay
controller. Normal first-person movement, attacks, blocks, jumps, and
interactions should drive the linked arms through VT2's native rig.

A local deploy alone is not a release: Steam can re-sync a subscribed item back to the last uploaded manifest at any time, so testers only reliably run the last UPLOAD. The staging root carries a `.vmbrc` so the monorepo's `VMBLauncher.exe` resolves it directly; upload with a settings file whose `ProjectRoot` is the staging root:

```powershell
& "<vermintide-2-tweaker>\tools\vmb-launcher\...\VMBLauncher.exe" upload pusfume --config <settings.json> --no-banner
```

Then confirm `Steam\logs\workshop_log.txt` gained a fresh `Uploaded new content ... for item 3764954245` line; `ugc_tool` prints success even when nothing transferred. Record the ManifestID and verify the next game log's `last_updated` timestamp after a full Steam restart. Use `-HeroPreview` for this intentional private selector build and `-NoDeploy` only for CI or a compiler-only check. Pass `-BlenderExe` if Blender 5.2 is installed outside the default location. The tracked config intentionally leaves native mode and native preview disabled so a normal public build cannot reference absent or unreviewed assets.

The third-person body, first-person arms, hats, and equipment should be separate exports. Preserve compatible VT2 bone names, hierarchy, and rest pose exactly. Send raw albedo, normal, emissive, roughness, metallic, and mask maps instead of relying on embedded FBX materials.

## Stingray animation contract

Autodesk's [character setup workflow](https://help.autodesk.com/cloudhelp/ENU/Stingray-Help/stingray_help/animation/set_up_character.html) requires the character mesh import to enable animation while creating or updating its skeleton, requires later clips to target that same skeleton, and its [controller documentation](https://help.autodesk.com/cloudhelp/ENU/Stingray-Help/stingray_help/animation/animation_controllers.html) requires the controller to be associated with that skeleton. Compiling the static model FBX produced valid skin binds but no embedded animation group, and the runtime skin remained rigid even while the clip playhead advanced. The merged character FBX preserves all 82 DCC skin binds and compiles one animation group covering all 86 scene nodes. The separate unit skeleton, clip sync pose, and clip tracks also contain the same 82 bones; the walk clip is 0.8 seconds and contains 1,109 keyed samples.

At runtime, a valid controller is not sufficient proof of deformation. Stingray's [Unit animation API](https://help.autodesk.com/cloudhelp/ENU/Stingray-Help/lua_ref/obj_stingray_Unit.html) allows evaluated animation to be withheld from bone nodes when the unit's animation bone mode is `ignore`, and bone LOD can freeze unevaluated bones. The native integration therefore sets bone mode to `transform`, selects bone LOD 0, enables the state machine, and logs its current state alongside skeletal articulation. Do not probe an assumed animation layer index: Stingray treats `animation_layer_info` as experimental and asserts inside the engine when the requested layer is absent.

The confirmed `-SplicedGameChild` build loads the installed playable Globadier package and applies a child material carrying the game character-skinning binding. The build replaces the SDK child's payload with the locally extracted game child, patches and verifies Pusfume diffuse and normal resource IDs, retains the donor black emissive texture, and sets the reflected Globadier `emissive_color` to zero. The selector and in-game body share this path, so one live test covers both render contexts. The raw extracted material is never committed, but the generated friends-only bundle embeds its patched 768-byte binding payload; this requires provenance review before wider publication.

When a compiled controller remains in a fixed state, the local native build can isolate the animation blender from the state graph. It disables the controller, starts `pusfume_3p_walk` directly on layer 1, freezes automatic playback, and explicitly sweeps the returned clip ID over its verified 0.8-second range. This diagnostic is enabled only in the staged Workshop build; tracked public configuration keeps it disabled.

With deformation confirmed, the staged controller is state-driven rather than a single looping clip. v0.6.22 uses Janfon's new 96-frame authored idle and retargets the original 25-frame walk from its 82-bone source onto the 138-bone untouched Skaven rig. `tools/validate_pusfume_animation_contract.py` requires both clips to contain the complete target bone-name set and a nonzero action duration before the SDK compiler runs. `tools/generate_idle_pusfume_fbx.py` remains the deterministic fallback when `-IdleAnimationFbx` is omitted. The state machine defaults to `base/idle` and transitions to `base/walk` and back through `walk` and `idle` events with 0.25-second blends. At runtime, the mod measures horizontal speed and fires `walk` above 0.5 m/s and `idle` below 0.2 m/s.
