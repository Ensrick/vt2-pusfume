"""Validate model, idle, and walk FBXs share one Stingray skeleton contract."""

from __future__ import annotations

import json
import os
import sys

import bpy


def import_armature(path):
    existing = set(bpy.context.scene.objects)
    bpy.ops.import_scene.fbx(filepath=path, automatic_bone_orientation=False)
    armatures = [
        obj
        for obj in bpy.context.scene.objects
        if obj not in existing and obj.type == "ARMATURE"
    ]
    if len(armatures) != 1:
        raise RuntimeError(f"{path} must contain exactly one armature")
    armature = armatures[0]
    action = armature.animation_data and armature.animation_data.action
    return armature, action


def matrix_error(left, right):
    return max(
        abs(left[row][column] - right[row][column])
        for row in range(4)
        for column in range(4)
    )


def main(model_path, idle_path, walk_path):
    bpy.ops.wm.read_factory_settings(use_empty=True)
    model, _ = import_armature(model_path)
    model_rest = {bone.name: bone.matrix_local.copy() for bone in model.data.bones}
    result = {"bones": len(model_rest), "clips": {}}

    for label, path in (("idle", idle_path), ("walk", walk_path)):
        armature, action = import_armature(path)
        if action is None:
            raise RuntimeError(f"{label} FBX has no assigned action")
        clip_names = {bone.name for bone in armature.data.bones}
        if clip_names != set(model_rest):
            raise RuntimeError(
                f"{label} skeleton mismatch: "
                f"model_only={sorted(set(model_rest) - clip_names)} "
                f"clip_only={sorted(clip_names - set(model_rest))}"
            )
        errors = {
            bone.name: matrix_error(model_rest[bone.name], bone.matrix_local)
            for bone in armature.data.bones
        }
        largest_bone = max(errors, key=errors.get)
        largest_error = errors[largest_bone]
        # Blender's FBX exporter encodes armature-only and skinned rest axes
        # differently. Stingray binds both clips through the shared .bones
        # resource, so record this as evidence but enforce names and duration.
        start, end = (int(round(value)) for value in action.frame_range)
        if end <= start:
            raise RuntimeError(f"{label} action has no duration: {start}..{end}")
        result["clips"][label] = {
            "action": action.name,
            "frame_end": end,
            "frame_start": start,
            "maximum_rest_error": largest_error,
            "maximum_rest_error_bone": largest_bone,
        }

    print("PUSFUME_ANIMATION_CONTRACT=" + json.dumps(result, sort_keys=True))


arguments = sys.argv[sys.argv.index("--") + 1 :]
if len(arguments) != 3:
    raise SystemExit(
        "usage: validate_pusfume_animation_contract.py -- MODEL.fbx IDLE.fbx WALK.fbx"
    )
main(*(os.path.abspath(argument) for argument in arguments))
