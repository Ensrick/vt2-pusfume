"""Generate isolated FBX unit-scale variants for the Pusfume 1P rig.

This is an offline diagnostic. It deliberately reuses the production cleanup
and donor-rest rebind, but never changes or deploys the live build output.
"""

from __future__ import annotations

import json
import os
import sys

import bpy
from mathutils import Matrix

TOOLS_ROOT = os.path.dirname(os.path.abspath(__file__))
if TOOLS_ROOT not in sys.path:
    sys.path.insert(0, TOOLS_ROOT)

import prepare_pusfume_1p_blend as production


VARIANTS = {
    "scale_units": {
        "global_scale": 1.0,
        "scale_length": 1.0,
        "apply_unit_scale": True,
        "apply_scale_options": "FBX_SCALE_UNITS",
    },
    "scale_all": {
        "global_scale": 1.0,
        "scale_length": 1.0,
        "apply_unit_scale": True,
        "apply_scale_options": "FBX_SCALE_ALL",
    },
    "global_001_all": {
        "global_scale": 0.01,
        "pre_data_scale": 1.0,
        "scale_length": 1.0,
        "apply_unit_scale": True,
        "apply_scale_options": "FBX_SCALE_ALL",
    },
    "centimeter_units": {
        "global_scale": 1.0,
        "pre_data_scale": 1.0,
        "scale_length": 0.01,
        "apply_unit_scale": True,
        "apply_scale_options": "FBX_SCALE_UNITS",
    },
    "centimeter_all": {
        "global_scale": 1.0,
        "pre_data_scale": 1.0,
        "scale_length": 0.01,
        "apply_unit_scale": True,
        "apply_scale_options": "FBX_SCALE_ALL",
    },
    "pre100_global_001": {
        "global_scale": 0.01,
        "pre_data_scale": 100.0,
        "scale_length": 1.0,
        "apply_unit_scale": True,
        "apply_scale_options": "FBX_SCALE_ALL",
    },
}

for _settings in VARIANTS.values():
    _settings.setdefault("pre_data_scale", 1.0)


def arguments_after_separator():
    if "--" not in sys.argv:
        return []
    return sys.argv[sys.argv.index("--") + 1 :]


def prepare(input_path, donor_path):
    bpy.ops.wm.open_mainfile(filepath=input_path, load_ui=False)
    mesh, armature = production.find_arms_and_rig()
    production.reset_bind_pose(mesh, armature)
    donor_rebind = production.rebind_to_donor_rest(mesh, armature, donor_path)

    bone_names = {bone.name for bone in armature.data.bones}
    orphan_stats = production.orphan_group_stats(mesh, bone_names)
    production.remove_orphan_groups(mesh, orphan_stats)
    production.prune_and_normalize_weights(mesh)
    stats = production.weight_stats(mesh)
    if stats["over_four_influences"] or stats["unnormalized_vertices"] or stats["unweighted_vertices"]:
        raise RuntimeError("Weight cleanup failed: %s" % stats)

    mesh.name = "pusfume_1p_arms"
    mesh.data.name = "pusfume_1p_arms"
    armature.name = "pusfume_1p_rig"
    armature.data.name = "pusfume_1p_rig"
    for scene_object in list(bpy.context.scene.objects):
        if scene_object not in (armature, mesh):
            bpy.data.objects.remove(scene_object, do_unlink=True)
    return mesh, armature, donor_rebind


def export_variant(output_path, settings):
    factor = settings["pre_data_scale"]
    if factor != 1.0:
        mesh = next(obj for obj in bpy.context.scene.objects if obj.type == "MESH")
        armature = next(obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE")
        mesh.data.transform(Matrix.Scale(factor, 4))
        bpy.context.view_layer.objects.active = armature
        armature.select_set(True)
        bpy.ops.object.mode_set(mode="EDIT")
        for edit_bone in armature.data.edit_bones:
            edit_bone.head *= factor
            edit_bone.tail *= factor
        bpy.ops.object.mode_set(mode="OBJECT")
        bpy.context.view_layer.update()

    bpy.context.scene.unit_settings.system = "METRIC"
    bpy.context.scene.unit_settings.length_unit = "METERS"
    bpy.context.scene.unit_settings.scale_length = settings["scale_length"]
    bpy.ops.export_scene.fbx(
        filepath=output_path,
        use_selection=False,
        object_types={"ARMATURE", "MESH"},
        use_mesh_modifiers=True,
        mesh_smooth_type="OFF",
        axis_forward="-Y",
        axis_up="Z",
        add_leaf_bones=False,
        primary_bone_axis="Y",
        secondary_bone_axis="X",
        bake_anim=False,
        global_scale=settings["global_scale"],
        apply_unit_scale=settings["apply_unit_scale"],
        apply_scale_options=settings["apply_scale_options"],
        path_mode="AUTO",
        embed_textures=False,
    )


def main():
    arguments = arguments_after_separator()
    if len(arguments) != 4 or arguments[2] not in VARIANTS:
        raise SystemExit(
            "Usage: experiment_pusfume_1p_scale.py -- INPUT.blend DONOR.unit "
            "VARIANT OUTPUT.fbx\nVariants: " + ", ".join(sorted(VARIANTS))
        )

    input_path, donor_path, variant, output_path = arguments
    input_path, donor_path, output_path = map(os.path.abspath, (input_path, donor_path, output_path))
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    mesh, armature, donor_rebind = prepare(input_path, donor_path)
    settings = VARIANTS[variant]
    export_variant(output_path, settings)
    print(
        "PUSFUME_1P_SCALE_VARIANT="
        + json.dumps(
            {
                "armature_scale": list(armature.scale),
                "donor_rebind": donor_rebind,
                "output": output_path,
                "settings": settings,
                "variant": variant,
                "vertices": len(mesh.data.vertices),
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
