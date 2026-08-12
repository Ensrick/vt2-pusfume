"""Generate a placeholder idle FBX from the skinned Pusfume model.

Run this script through Blender. It imports Janfon's model FBX, discards the
mesh, and bakes a two-second breathing idle on the exact model skeleton:
sinusoidal spine and head breathing plus a visible tail sway. The output is an
armature-only clip compiled by the same ``.animation`` recipe contract as the
walk clip. Replace it with an authored idle from Janfon when one is supplied on
the same rig.
"""

import json
import math
import os
import sys

import bpy


FRAME_START = 1
FRAME_END = 61
FRAME_STEP = 5
FPS = 30

# axis is the pose bone's local rotation axis; amplitude is radians; phase is a
# fraction of the loop. The live test showed a single 0.02-radian channel is
# imperceptible in game, so the idle must read clearly at third-person range.
BONE_MOTIONS = {
    "j_spine": {"axis": "x", "amplitude": 0.035, "phase": 0.0},
    "j_spine1": {"axis": "x", "amplitude": 0.05, "phase": 0.05},
    "j_neck": {"axis": "x", "amplitude": 0.04, "phase": 0.2},
    "j_head": {"axis": "x", "amplitude": 0.06, "phase": 0.3},
    "j_tail1": {"axis": "z", "amplitude": 0.12, "phase": 0.0},
    "j_tail2": {"axis": "z", "amplitude": 0.18, "phase": 0.25},
}


def scene_objects(object_type):
    return [obj for obj in bpy.context.scene.objects if obj.type == object_type]


def rotation_for(axis, angle):
    half = angle / 2.0
    sin_half = math.sin(half)

    if axis == "x":
        return (math.cos(half), sin_half, 0.0, 0.0)
    elif axis == "y":
        return (math.cos(half), 0.0, sin_half, 0.0)

    return (math.cos(half), 0.0, 0.0, sin_half)


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

    bpy.context.scene.render.fps = FPS
    bpy.context.scene.frame_start = FRAME_START
    bpy.context.scene.frame_end = FRAME_END

    missing = sorted(set(BONE_MOTIONS) - {bone.name for bone in armature.pose.bones})
    if missing:
        raise RuntimeError(f"The model armature is missing idle bones: {missing}")

    loop_frames = FRAME_END - FRAME_START

    for pose_bone in armature.pose.bones:
        motion = BONE_MOTIONS.get(pose_bone.name)

        if motion is None:
            key_rest_pose(pose_bone, FRAME_START)
            key_rest_pose(pose_bone, FRAME_END)
            continue

        pose_bone.location = (0.0, 0.0, 0.0)
        pose_bone.rotation_mode = "QUATERNION"
        pose_bone.scale = (1.0, 1.0, 1.0)
        pose_bone.keyframe_insert("location", frame=FRAME_START)
        pose_bone.keyframe_insert("scale", frame=FRAME_START)

        for frame in range(FRAME_START, FRAME_END + 1, FRAME_STEP):
            progress = (frame - FRAME_START) / loop_frames
            angle = motion["amplitude"] * math.sin(
                2.0 * math.pi * (progress + motion["phase"])
            )

            pose_bone.rotation_quaternion = rotation_for(motion["axis"], angle)
            pose_bone.keyframe_insert("rotation_quaternion", frame=frame)

    action = armature.animation_data.action
    action.name = "pusfume_idle"

    bpy.context.scene.frame_set(FRAME_START)
    first_pose = {bone.name: bone.matrix.copy() for bone in armature.pose.bones}
    max_pose_delta = 0.0

    for frame in range(FRAME_START + FRAME_STEP, FRAME_END, FRAME_STEP):
        bpy.context.scene.frame_set(frame)
        max_pose_delta = max(
            max_pose_delta,
            max(
                abs(first_pose[bone.name][row][column] - bone.matrix[row][column])
                for bone in armature.pose.bones
                for row in range(4)
                for column in range(4)
            ),
        )

    if max_pose_delta < 0.02:
        raise RuntimeError(
            f"Idle motion is too small to read in game: delta={max_pose_delta}"
        )
    if max_pose_delta > 0.5:
        raise RuntimeError(
            f"Idle motion moved the armature too far for a rest hold: delta={max_pose_delta}"
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
        "animated_bones": sorted(BONE_MOTIONS),
        "bones": len(armature.data.bones),
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
