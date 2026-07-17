# VT2 Content Tools for Blender 5.2

VT2 Content Tools is the supported no-Maya authoring path for Janfon's Pusfume
models and animations. Release `0.2.0` is acceptance-tested against **Blender
5.2.0 LTS** on Windows. Its extension manifest permits Blender 4.3 or newer,
but 5.2.0 LTS is the project's primary tested version.

The extension prepares source assets. Vermintide 2's SDK/VMB compiler remains
the final step that creates `.unit`, `.animation`, `.state_machine`, material,
texture, package, and bundle resources.

## Install

Build the installable package from the repository root:

```powershell
py -3 tools\package_blender_addon.py
```

This writes `.build/dist/vt2_content_tools-0.2.0.zip`. In Blender 5.2:

1. Open **Edit > Preferences > Get Extensions**.
2. Open the menu and choose **Install from Disk**.
3. Select `vt2_content_tools-0.2.0.zip`.
4. Open the 3D Viewport and press `N` to show the sidebar.
5. Select the **VT2** tab.

The package does not need Maya, an Autodesk account, a network service, or a
machine-specific Python installation.

## Character setup

Use **Whole Scene** for a dedicated character `.blend`, or **Selected** while
working in a larger file. The first release expects:

- One armature with one root bone and no more than 255 bones.
- At least one mesh with an active UV map and one Armature modifier targeting
  that rig.
- One to four exported bone influences per vertex, normalized to a total of
  `1.0`.
- Stable object, material, armature, and bone names using letters, numbers, and
  underscores. The Pusfume rig should continue using its established `j_`
  names unless an intentional bridge migration is documented.
- Explicit material slots. Use **Tag Active Material** to record whether a
  Blender material is intended for an opaque character surface, a skinned
  alpha card, or an eye/emissive surface.

**Limit and Normalize Weights** is deliberately opt-in and undoable. It keeps
the four strongest bone assignments, removes weaker exported-bone assignments,
and normalizes the survivors. It does not alter non-bone vertex groups.

Transforms and n-gons are warnings rather than automatic edits. Apply or
triangulate them deliberately after confirming the rest pose; the extension
will not destructively guess at an artist's intent.

## VT2 pose mirroring

In Pose Mode, the **Pose Mirroring** panel pairs VT2 names such as
`j_leftarm`/`j_rightarm` and `j_lefthand`/`j_righthand` without renaming the
rig. Common `.L/.R`, `_L/_R`, and `-L/-R` pairs are also recognized.

Choose **Left to Right** or **Right to Left**, select source-side bones, and
press **Mirror VT2 Pose**. The default X axis is correct for the validated
Pusfume scene; Y and Z remain available for rigs authored in another local
orientation. The operator reflects each source pose in armature space, removes
the reflected source rest transform, and reapplies the result to the actual
destination rest transform. This preserves intentional asymmetry in the rest
rig better than copying Euler values.

**Selected Source Bones Only** prevents accidental whole-rig changes. Enable
**Insert Keyframes** when the mirrored destination should be keyed at the
current frame. Destination constraints can override the result; the operator
reports how many mirrored bones have constraints so the artist can inspect
them rather than silently baking an unexpected pose.

## Animation setup

Assign the clip to the exported armature as its active Action, set the scene to
30 FPS, and choose **Active Clip** or **Model + Active Clip**. Give the clip a
short VT2-safe name such as `idle`, `walk`, `dodge_left`, or `jump_start`.

The verified Pusfume path uses rotation animation. Root translation can be
intentional, but non-root translation and animated scale receive warnings and
must be checked in Stingray/VT2. A channel targeting a bone absent from the
current armature is an export-blocking error.

The animation FBX contains the armature and the active action only. It bakes
all bones over the action range with no curve simplification, `-Y` forward,
`Z` up, `Y` primary bone axis, `X` secondary bone axis, and no leaf bones.

## Handoff output

**Export VT2 Handoff** always validates first. Errors block export; warnings
are allowed only when **Export With Warnings** is enabled. Depending on mode,
the folder contains:

- `<asset>_3p.fbx`: skinned model and armature without animation.
- `<asset>_<clip>.fbx`: active armature clip baked for handoff.
- `<asset>_vt2_handoff.json`: validation results, Blender/add-on versions,
  output sizes, and SHA-256 hashes.
- `textures/`: optional copies of external or packed images referenced by the
  exported Blender materials.

The JSON records only source basenames, never absolute local paths. Material
tags are authoring metadata; they do not pretend to be compiled Stingray
shaders. Skinned alpha cards still require the proven VT2 cutout material path
during SDK/VMB integration.

## Developer verification

Run the normal tests, package validation, and the real Blender 5.2 fixture:

```powershell
py -3 -m unittest discover -s tests -v
py -3 tools\package_blender_addon.py
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" `
  --command extension validate .build\dist\vt2_content_tools-0.2.0.zip
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" `
  --background --factory-startup --disable-autoexec `
  --python tools\test_vt2_content_tools_blender.py -- `
  . .build\blender-addon-fixture
```

The fixture intentionally creates five weights per vertex. A passing run must
detect that failure, repair it to four normalized weights, mirror a VT2 arm
pair accurately in both directions, reach zero errors, and produce both FBXs
plus the handoff JSON under Blender `5.2.0 LTS`.

## Provenance boundary

Do not commit or broadly redistribute extracted Fatshark models, textures,
animations, or compiled game material payloads. The extension itself contains
only source code and generic validation/export rules. Asset permissions remain
the responsibility of the handoff and destination mod.
