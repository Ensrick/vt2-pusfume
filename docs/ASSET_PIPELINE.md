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

The third-person body, first-person arms, hats, and equipment should be separate exports. Preserve compatible VT2 bone names, hierarchy, and rest pose exactly. Send raw albedo, normal, emissive, roughness, metallic, and mask maps instead of relying on embedded FBX materials.
