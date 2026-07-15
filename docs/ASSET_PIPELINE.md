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

After the compiler probe succeeds, stage and deploy the generated BSI without copying it into the public source tree:

```powershell
.\tools\Build-NativePusfume.ps1
```

The command writes only beneath ignored `.build/native-workshop`, enables the native cosmetic in that staged copy, compiles it with VMB, and copies the resulting bundles into Workshop item `3764954245` by default. Use `-NoDeploy` only for CI or an intentional compiler-only check. The tracked config intentionally leaves native mode disabled so a normal public build cannot reference an absent or unreviewed model.

The third-person body, first-person arms, hats, and equipment should be separate exports. Preserve compatible VT2 bone names, hierarchy, and rest pose exactly. Send raw albedo, normal, emissive, roughness, metallic, and mask maps instead of relying on embedded FBX materials.
