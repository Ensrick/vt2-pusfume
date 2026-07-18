"""Prepare Janfon's first-person arms as a compiler-readable skinned BSI.

This path avoids the FBX unit-scale conversion entirely. The scene nodes and
inverse bind matrices are emitted from the same donor-rebound Blender scene.
"""

from __future__ import annotations

import json
import os
import sys

import bpy


TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
if TOOLS_DIR not in sys.path:
    sys.path.insert(0, TOOLS_DIR)

import bsi_format  # noqa: E402
import export_blender_bsi as bsi_export  # noqa: E402
import prepare_pusfume_1p_blend as preparation  # noqa: E402


def arguments_after_separator():
    return sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []


def main():
    arguments = arguments_after_separator()
    if len(arguments) != 3:
        raise SystemExit(
            "Usage: prepare_pusfume_1p_bsi.py -- INPUT.blend DONOR.unit OUTPUT.bsi"
        )

    input_path, donor_unit_path, output_path = (
        os.path.abspath(value) for value in arguments
    )
    if input_path == output_path:
        raise SystemExit("Input and output paths must differ; the source blend is never overwritten.")
    if not input_path.lower().endswith(".blend"):
        raise SystemExit("The first-person source must be a .blend file.")
    if not output_path.lower().endswith(".bsi"):
        raise SystemExit("The direct first-person output must be a .bsi file.")

    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    bpy.ops.wm.open_mainfile(filepath=input_path, load_ui=False)
    mesh, armature = preparation.find_arms_and_rig()
    bind_reset = preparation.reset_bind_pose(mesh, armature)
    donor_rebind = preparation.rebind_to_donor_rest(mesh, armature, donor_unit_path)

    bone_names = {bone.name for bone in armature.data.bones}
    orphan_stats = preparation.orphan_group_stats(mesh, bone_names)
    removed_groups = preparation.remove_orphan_groups(mesh, orphan_stats)
    pruned_vertices, removed_influences = preparation.prune_and_normalize_weights(mesh)
    stats = preparation.weight_stats(mesh)
    if (
        stats["over_four_influences"]
        or stats["unnormalized_vertices"]
        or stats["unweighted_vertices"]
    ):
        raise RuntimeError("Weight cleanup failed: %s" % stats)
    if len(armature.data.bones) > 255:
        raise RuntimeError("VT2 supports at most 255 bones; found %d" % len(armature.data.bones))

    material_names = [slot.material.name if slot.material else "" for slot in mesh.material_slots]
    if material_names != ["p_main"]:
        raise RuntimeError("Expected the first-person material contract ['p_main']; found %s" % material_names)

    mesh.name = "pusfume_1p_arms"
    mesh.data.name = "pusfume_1p_arms"
    armature.name = "pusfume_1p_rig"
    armature.data.name = "pusfume_1p_rig"
    for scene_object in list(bpy.context.scene.objects):
        if scene_object not in (armature, mesh):
            bpy.data.objects.remove(scene_object, do_unlink=True)

    geometry_name = mesh.name
    skin_name, bone_indices, skins, nodes = bsi_export.build_skin(
        armature, mesh, geometry_name
    )
    activation_animations = bsi_export.build_skin_activation_animations(
        armature, mesh, geometry_name
    )
    bones_path = bsi_export.write_animation_bones(output_path, armature)
    geometry, triangle_count, exported_vertices = bsi_export.build_geometry(
        mesh, bone_indices, skin_name
    )
    bsi_format.write(
        output_path,
        {
            "geometries": {geometry_name: geometry},
            "nodes": nodes,
            "source_path": os.path.basename(input_path),
            "animations": activation_animations,
            "skins": skins,
        },
    )

    print(
        "PUSFUME_1P_BSI_PREPARE_RESULT="
        + json.dumps(
            {
                "bind_reset": bind_reset,
                "bones": len(armature.data.bones),
                "bones_output": bones_path,
                "donor_rebind": donor_rebind,
                "exported_vertices": exported_vertices,
                "materials": material_names,
                "mesh": mesh.name,
                "orphan_groups": orphan_stats,
                "output": output_path,
                "pruned_vertices": pruned_vertices,
                "removed_groups": removed_groups,
                "removed_influences": removed_influences,
                "triangles": triangle_count,
                "vertices": len(mesh.data.vertices),
                "weights": stats,
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
