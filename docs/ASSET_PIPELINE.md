# Pusfume Asset Pipeline

Commit only original or authorized assets. Keep extracted game assets outside this public repository.

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

Pusfume's current mesh uses slave-rat bone names rather than the playable Globadier names. Do not rename or retarget it merely to satisfy the stock cosmetic table: `_pusfume_assets.lua` provides the explicit parent-to-child node bridge needed for the first in-game deformation test. A true Globadier-skeleton rebind remains an optimization if the bridge exposes rest-pose differences.

The cleaned FBX is an interchange asset, not the final Stingray scene. VT2's SDK requires a `.bsi` payload beside the `.unit` descriptor. This repository includes an account-free Blender 5.2 exporter for geometry, skeleton nodes, inverse bind matrices, and four-influence skin streams. Run the complete export and compiler probe with:

```powershell
.\tools\Test-BsiPipeline.ps1 `
  -InputFbx "C:\path\to\pusfume_3p_clean.fbx"
```

The probe writes only to ignored `.build` storage. It emits a compressed `bsiz` scene, creates a private throwaway unit/package, and requires Fatshark's VT2 SDK compiler to build it. A passing compile proves resource structure, not animation compatibility; complete the live deformation checklist before integrating generated assets into the Workshop package.

The exporter intentionally duplicates mesh corners in source BSI to keep UV seams and per-channel indexing unambiguous. Fatshark's compiler deduplicates the current Pusfume mesh from 72,954 source corners to 30,477 native vertices.

## Local native Workshop build

After the compiler probe succeeds, stage and deploy the native unit without copying generated assets into the public source tree. The native build now gives Janfon's FBX to Stingray's supported DCC importer by default; use `-UseBsiSkinFallback` only to reproduce the experimental handwritten BSI path:

```powershell
.\tools\Build-NativePusfume.ps1 `
  -TextureSource ".build\pusfume_handoff\textures conv"
```

The command first runs `tools/prepare_animated_pusfume_fbx.py` through Blender 5.2. That step merges Janfon's skinned model and baked walk into one character FBX and fails unless the transferred action moves both the armature and evaluated mesh vertices. The source FBXs remain unchanged; generated output stays under ignored `.build/generated-native`.

The command then writes only beneath ignored `.build/native-workshop`, generates VT2 texture recipes and materials from the untracked handoff, enables the native cosmetic in that staged copy, compiles it with VMB, and copies the resulting bundles into Workshop item `3764954245` by default. Use `-HeroPreview` only for an intentional 3D selector test and `-NoDeploy` only for CI or a compiler-only check. Pass `-BlenderExe` if Blender 5.2 is installed outside the default location. The tracked config intentionally leaves native mode and native preview disabled so a normal public build cannot reference an absent or unreviewed model.

The third-person body, first-person arms, hats, and equipment should be separate exports. Preserve compatible VT2 bone names, hierarchy, and rest pose exactly. Send raw albedo, normal, emissive, roughness, metallic, and mask maps instead of relying on embedded FBX materials.

## Stingray animation contract

Autodesk's [character setup workflow](https://help.autodesk.com/cloudhelp/ENU/Stingray-Help/stingray_help/animation/set_up_character.html) requires the character mesh import to enable animation while creating or updating its skeleton, requires later clips to target that same skeleton, and its [controller documentation](https://help.autodesk.com/cloudhelp/ENU/Stingray-Help/stingray_help/animation/animation_controllers.html) requires the controller to be associated with that skeleton. Compiling the static model FBX produced valid skin binds but no embedded animation group, and the runtime skin remained rigid even while the clip playhead advanced. The merged character FBX preserves all 82 DCC skin binds and compiles one animation group covering all 86 scene nodes. The separate unit skeleton, clip sync pose, and clip tracks also contain the same 82 bones; the walk clip is 0.8 seconds and contains 1,109 keyed samples.

At runtime, a valid controller is not sufficient proof of deformation. Stingray's [Unit animation API](https://help.autodesk.com/cloudhelp/ENU/Stingray-Help/lua_ref/obj_stingray_Unit.html) allows evaluated animation to be withheld from bone nodes when the unit's animation bone mode is `ignore`, and bone LOD can freeze unevaluated bones. The native integration therefore sets bone mode to `transform`, selects bone LOD 0, enables the state machine, and logs its current state alongside skeletal articulation. Do not probe an assumed animation layer index: Stingray treats `animation_layer_info` as experimental and asserts inside the engine when the requested layer is absent.

The local diagnostic build replaces opaque material slots at runtime with the installed playable Globadier's `mtr_outfit` resource, then restores Pusfume's diffuse, normal, and packed response channels. The donor's inventory-listed `chr_third_person_mesh` package is loaded before assignment. This preserves the game-owned full-character shader permutation without copying extracted shader binaries into the repository or Workshop item. The selector and in-game body share this material path, so one live test covers both render contexts.

When a compiled controller remains in a fixed state, the local native build can isolate the animation blender from the state graph. It disables the controller, starts `pusfume_3p_walk` directly on layer 1, freezes automatic playback, and explicitly sweeps the returned clip ID over its verified 0.8-second range. This diagnostic is enabled only in the staged Workshop build; tracked public configuration keeps it disabled.
