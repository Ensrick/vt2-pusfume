"""Export Janfon's authored 99-bone claw actions as Stingray animation FBXs.

Run through Blender 5.2:
    blender --background --factory-startup --disable-autoexec \
        --python tools/export_pusfume_1p_actions.py -- INPUT.blend OUTPUT_DIR
"""

from __future__ import annotations

import json
import os
import sys

import bpy


ACTION_NAMES = (
    "claws_equip",
    "claws_idle",
    "claws_run",
    "claws_block",
    "claws_light_attack_right_first",
    "claws_light_attack_right_second",
    "claws_light_attack_stab_left",
    "claws_light_attack_stab_left_hit",
    "claws_light_attack_last",
)
EXPECTED_BONES = 99
FPS = 30
TRANSFORM_PROPERTIES = ("location", "scale")


def arguments_after_separator():
    return sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []


def find_armature():
    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    if len(armatures) != 1:
        raise RuntimeError("Expected one armature, found %d" % len(armatures))
    armature = armatures[0]
    if len(armature.data.bones) != EXPECTED_BONES:
        raise RuntimeError(
            "Janfon claw animation contract requires %d bones, found %d"
            % (EXPECTED_BONES, len(armature.data.bones))
        )
    return armature


def assign_action(armature, action):
    animation_data = armature.animation_data_create()
    animation_data.action = action
    if hasattr(action, "slots") and len(action.slots):
        animation_data.action_slot = action.slots[0]


def action_fcurves(action):
    if hasattr(action, "layers"):
        return [
            curve
            for layer in action.layers
            for strip in layer.strips
            for channelbag in strip.channelbags
            for curve in channelbag.fcurves
        ]
    return list(action.fcurves)


def sanitize_pose_transforms(armature, action):
    """Remove Blender-only pose translation/scale from Janfon's VT2 clips."""
    removed = []
    for layer in action.layers:
        for strip in layer.strips:
            for channelbag in strip.channelbags:
                for curve in list(channelbag.fcurves):
                    property_name = curve.data_path.rsplit(".", 1)[-1]
                    if property_name not in TRANSFORM_PROPERTIES:
                        continue
                    neutral = 0.0 if property_name == "location" else 1.0
                    maximum_delta = max(
                        (abs(point.co[1] - neutral) for point in curve.keyframe_points),
                        default=0.0,
                    )
                    removed.append(
                        {
                            "data_path": curve.data_path,
                            "index": curve.array_index,
                            "maximum_delta": maximum_delta,
                        }
                    )
                    channelbag.fcurves.remove(curve)

    for pose_bone in armature.pose.bones:
        pose_bone.location = (0.0, 0.0, 0.0)
        pose_bone.scale = (1.0, 1.0, 1.0)

    remaining = [
        curve.data_path
        for curve in action_fcurves(action)
        if curve.data_path.rsplit(".", 1)[-1] in TRANSFORM_PROPERTIES
    ]
    if remaining:
        raise RuntimeError(
            "Action %s retained unsafe transform channels: %s"
            % (action.name, sorted(set(remaining)))
        )
    return {
        "maximum_removed_delta": max(
            (entry["maximum_delta"] for entry in removed), default=0.0
        ),
        "removed_channels": len(removed),
    }


def maximum_pose_delta(armature, frame_start, frame_end):
    bpy.context.scene.frame_set(frame_start)
    first = {bone.name: bone.matrix.copy() for bone in armature.pose.bones}
    maximum = 0.0
    for frame in range(frame_start + 1, frame_end + 1):
        bpy.context.scene.frame_set(frame)
        maximum = max(
            maximum,
            max(
                abs(first[bone.name][row][column] - bone.matrix[row][column])
                for bone in armature.pose.bones
                for row in range(4)
                for column in range(4)
            ),
        )
    return maximum


def export_action(armature, action, output_dir):
    assign_action(armature, action)
    transform_audit = sanitize_pose_transforms(armature, action)
    keyed_start, keyed_end = (int(round(value)) for value in action.frame_range)
    # Janfon retained negative helper keys on the looping clips. Gameplay clips
    # begin at frame 1; trimming the lead-in avoids a negative Stingray timeline.
    frame_start = max(1, keyed_start)
    frame_end = keyed_end
    if frame_end <= frame_start:
        raise RuntimeError("Action %s has no usable duration" % action.name)

    bpy.context.scene.render.fps = FPS
    bpy.context.scene.frame_start = frame_start
    bpy.context.scene.frame_end = frame_end
    motion = maximum_pose_delta(armature, frame_start, frame_end)
    if motion < 0.001:
        raise RuntimeError("Action %s does not move the rig: %.8f" % (action.name, motion))

    output_path = os.path.join(output_dir, action.name + ".fbx")
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
    return {
        "action": action.name,
        "duration": (frame_end - frame_start) / FPS,
        "frame_end": frame_end,
        "frame_start": frame_start,
        "keyed_frame_start": keyed_start,
        "maximum_pose_delta": motion,
        "output": output_path,
        "output_bytes": os.path.getsize(output_path),
        "transform_audit": transform_audit,
    }


def main(input_path, output_dir):
    bpy.ops.wm.open_mainfile(filepath=input_path, load_ui=False)
    armature = find_armature()
    actions = {action.name: action for action in bpy.data.actions}
    missing = sorted(set(ACTION_NAMES) - set(actions))
    if missing:
        raise RuntimeError("Janfon claw handoff is missing actions: %s" % missing)

    # Weapon reference meshes and the skinned arm display are not animation
    # resources. Removing them from this in-memory copy keeps FBXs armature-only.
    for scene_object in list(bpy.context.scene.objects):
        if scene_object is not armature:
            bpy.data.objects.remove(scene_object, do_unlink=True)

    os.makedirs(output_dir, exist_ok=True)
    exported = [
        export_action(armature, actions[action_name], output_dir)
        for action_name in ACTION_NAMES
    ]
    manifest_path = os.path.join(output_dir, "pusfume_1p_claw_actions.json")
    manifest = {
        "actions": exported,
        "bones": len(armature.data.bones),
        "fps": FPS,
        "source": input_path,
    }
    with open(manifest_path, "w", encoding="ascii", newline="\n") as stream:
        json.dump(manifest, stream, indent=2, sort_keys=True)
        stream.write("\n")
    print("PUSFUME_1P_ACTION_EXPORT=" + json.dumps(manifest, sort_keys=True))


arguments = arguments_after_separator()
if len(arguments) != 2:
    raise SystemExit("usage: export_pusfume_1p_actions.py -- INPUT.blend OUTPUT_DIR")
main(*(os.path.abspath(argument) for argument in arguments))
