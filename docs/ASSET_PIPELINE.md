# Pusfume Asset Pipeline

Commit only original or authorized assets. Keep extracted game assets outside this public repository.

Recommended handoff layout:

```text
art_source/pusfume.blend
art_source/textures/*.png
pusfume/units/pusfume/pusfume_3p.fbx
pusfume/units/pusfume/pusfume_1p_arms.fbx
```

For Blender, export binary FBX 7.4/2014 with Selected Objects, Forward `-Y`, Up `Z`, no embedded media, no leaf bones, deform bones only, and animation baking disabled. Triangulate meshes, preserve custom normals, normalize weights, use no more than four influences per vertex, and keep the root at the origin.

The third-person body, first-person arms, hats, and equipment should be separate exports. Preserve compatible VT2 bone names, hierarchy, and rest pose exactly. Send raw albedo, normal, emissive, roughness, metallic, and mask maps instead of relying on embedded FBX materials.

