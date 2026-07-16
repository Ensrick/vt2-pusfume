"""Generate a placeholder idle FBX from the skinned Pusfume model.

Run this script through Blender. It imports Janfon's model FBX, discards the
mesh, and bakes a two-second rest-pose hold with a subtle breathing rotation on
``j_spine1``. The output is an armature-only clip on the exact model skeleton,
compiled by the same ``.animation`` recipe contract as the walk clip. Replace it
with an authored idle from Janfon when one is supplied on the same rig.
"""

import json
import math
import os
import sys

import bpy


BREATH_BONE = "j_spine1"
BREATH_RADIANS = 0.02
FRAME_START = 1
FRAME_PEAK = 31
FRAME_END = 61


def scene_objects(object_type):
    return [obj for obj in bpy.context.scene.objects if obj.type == object_type]


def key_rest_pose(pose_bone, frame):
    pose_bone.location = (0.0, 0.0, 0.0)
    pose_bone.rotation_mode = "QUATERNION"
    pose_bone.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
    pose_bone.scale = (1.0, 1.0, 1.0)
    pose_bone.keyframe_insert("location", frame=frame)
    pose_bone.keyframe_insert("rotation_quaternion", frame=frame)
    pose_bone.keyframe_insert("scale", frame=frame)


def main(model_path, output_path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    bpy.ops.import_scene.fbx(filepath=model_path, automatic_bone_orientation=False)

    armatures = scene_objects("ARMATURE")
    if len(armatures) != 1:
        raise RuntimeError(
            f"The model FBX must contain exactly one armature: {len(armatures)}"
        )

    armature = armatures[0]
    for mesh in scene_objects("MESH"):
        bpy.data.objects.remove(mesh, do_unlink=True)

    armature.animation_data_clear()
    for stale_action in list(bpy.data.actions):
        bpy.data.actions.remove(stale_action)

    bpy.context.scene.render.fps = 30
    bpy.context.scene.frame_start = FRAME_START
    bpy.context.scene.frame_end = FRAME_END

    for pose_bone in armature.pose.bones:
        key_rest_pose(pose_bone, FRAME_START)
        key_rest_pose(pose_bone, FRAME_END)

    breath_bone = armature.pose.bones.get(BREATH_BONE)
    if breath_bone is None:
        raise RuntimeError(f"The model armature is missing {BREATH_BONE}")

    half = BREATH_RADIANS / 2.0
    breath_bone.rotation_quaternion = (math.cos(half), math.sin(half), 0.0, 0.0)
    breath_bone.keyframe_insert("rotation_quaternion", frame=FRAME_PEAK)

    action = armature.animation_data.action
    action.name = "pusfume_idle"

    bpy.context.scene.frame_set(FRAME_START)
    rest_pose = {bone.name: bone.matrix.copy() for bone in armature.pose.bones}
    bpy.context.scene.frame_set(FRAME_PEAK)
    max_pose_delta = max(
        abs(rest_pose[bone.name][row][column] - bone.matrix[row][column])
        for bone in armature.pose.bones
        for row in range(4)
        for column in range(4)
    )
    if max_pose_delta < 0.0005:
        raise RuntimeError(
            f"Idle breathing did not animate the armature: delta={max_pose_delta}"
        )
    if max_pose_delta > 0.2:
        raise RuntimeError(
            f"Idle breathing moved the armature too far for a rest hold: delta={max_pose_delta}"
        )

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
    )

    result = {
        "action": action.name,
        "bones": len(armature.data.bones),
        "breath_bone": BREATH_BONE,
        "frame_end": FRAME_END,
        "frame_start": FRAME_START,
        "max_pose_delta": max_pose_delta,
        "output": output_path,
        "output_bytes": os.path.getsize(output_path),
    }
    print("PUSFUME_IDLE_FBX=" + json.dumps(result, sort_keys=True))


arguments = sys.argv[sys.argv.index("--") + 1 :]
if len(arguments) != 2:
    raise SystemExit("usage: generate_idle_pusfume_fbx.py -- MODEL_FBX OUTPUT_FBX")

main(*(os.path.abspath(argument) for argument in arguments))
