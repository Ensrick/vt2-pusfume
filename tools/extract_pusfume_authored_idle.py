"""Extract Janfon's authored idle as an armature-only Stingray animation FBX."""

from __future__ import annotations

import json
import os
import sys

import bpy


def scene_objects(object_type):
    return [obj for obj in bpy.context.scene.objects if obj.type == object_type]


def pose_delta(first, armature):
    return max(
        abs(first[bone.name][row][column] - bone.matrix[row][column])
        for bone in armature.pose.bones
        for row in range(4)
        for column in range(4)
    )


def main(input_path, output_path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=input_path, automatic_bone_orientation=False)
    armatures = scene_objects("ARMATURE")
    if len(armatures) != 1:
        raise RuntimeError(f"Authored idle requires one armature, found {len(armatures)}")

    armature = armatures[0]
    action = armature.animation_data and armature.animation_data.action
    if action is None:
        raise RuntimeError("Authored idle FBX assigned no armature action")
    action.name = "pusfume_idle"
    frame_start = int(round(action.frame_range[0]))
    frame_end = int(round(action.frame_range[1]))
    if frame_end - frame_start < 20:
        raise RuntimeError("Authored idle is unexpectedly short")

    bpy.context.scene.frame_set(frame_start)
    first = {bone.name: bone.matrix.copy() for bone in armature.pose.bones}
    maximum_delta = 0.0
    for frame in range(frame_start + 1, frame_end + 1):
        bpy.context.scene.frame_set(frame)
        maximum_delta = max(maximum_delta, pose_delta(first, armature))
    if maximum_delta < 0.01:
        raise RuntimeError(f"Authored idle does not move the rig: {maximum_delta}")

    for mesh in scene_objects("MESH"):
        bpy.data.objects.remove(mesh, do_unlink=True)
    for candidate in list(bpy.data.actions):
        if candidate != action:
            bpy.data.actions.remove(candidate)

    bpy.context.scene.render.fps = 30
    bpy.context.scene.frame_start = frame_start
    bpy.context.scene.frame_end = frame_end
    os.makedirs(os.path.dirname(output_path), exist_ok=True)
    bpy.ops.export_scene.fbx(
        filepath=output_path,
        use_selection=False,
        axis_forward="-Y",
        axis_up="Z",
        object_types={"ARMATURE"},
        add_leaf_bones=False,
        primary_bone_axis="Y",
        secondary_bone_axis="X",
        bake_anim=True,
        bake_anim_use_all_bones=True,
        bake_anim_use_nla_strips=False,
        bake_anim_use_all_actions=False,
        bake_anim_force_startend_keying=True,
        bake_anim_simplify_factor=0.0,
    )
    print(
        "PUSFUME_AUTHORED_IDLE="
        + json.dumps(
            {
                "action": action.name,
                "bones": len(armature.data.bones),
                "frame_end": frame_end,
                "frame_start": frame_start,
                "maximum_delta": maximum_delta,
                "output": output_path,
                "output_bytes": os.path.getsize(output_path),
            },
            sort_keys=True,
        )
    )


arguments = sys.argv[sys.argv.index("--") + 1 :]
if len(arguments) != 2:
    raise SystemExit("usage: extract_pusfume_authored_idle.py -- INPUT.fbx OUTPUT.fbx")
main(*(os.path.abspath(argument) for argument in arguments))
