# VT2 Content Tools

VT2 Content Tools is a Blender extension for preparing character source assets
for Vermintide 2 without Maya. It validates the contracts confirmed by the
Pusfume native-character pipeline and exports predictable FBX handoffs.

## Features

- Character mesh, armature, UV, material, naming, and transform checks.
- Four-influence skin-weight validation and opt-in repair.
- Active-action checks for missing bones, scale channels, non-root translation,
  and the verified 30 FPS handoff rate.
- Model and active-clip FBX export using `-Y` forward, `Z` up, no leaf bones,
  and unsimplified baked animation.
- Optional collection of externally referenced or packed Blender textures.
- A JSON handoff manifest with validation results, file sizes, and SHA-256
  hashes, but no absolute machine paths.
- Material tags for opaque skin, skinned alpha cards, and eye/emissive surfaces.
- One-shot and live Pose Mode mirroring for VT2 `j_left*`/`j_right*` names
  without renaming bones, with either direction, selectable mirror axis,
  selected-only scope, and optional one-shot keyframe insertion.

## Boundary

This extension replaces Maya for Blender-side preparation and export. It does
not redistribute Fatshark content and cannot replace Vermintide 2's SDK/VMB
compiler. The receiving mod project still creates and compiles `.unit`,
`.animation`, `.state_machine`, `.material`, texture, and package resources.

Install the packaged ZIP through **Edit > Preferences > Get Extensions >
Install from Disk**, then open **3D View > Sidebar > VT2**.
