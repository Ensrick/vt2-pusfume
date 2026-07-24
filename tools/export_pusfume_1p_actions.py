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
from mathutils import Matrix


TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
if TOOLS_DIR not in sys.path:
    sys.path.insert(0, TOOLS_DIR)

import prepare_pusfume_1p_blend as preparation  # noqa: E402


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
MAXIMUM_POSED_VERTEX_DISPLACEMENT = 1.5


def arguments_after_separator():
    return sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else []


def validate_armature(armature):
    if len(armature.data.bones) != EXPECTED_BONES:
        raise RuntimeError(
            "Janfon claw animation contract requires %d bones, found %d"
            % (EXPECTED_BONES, len(armature.data.bones))
        )


def duplicate_source_armature(armature):
    source = armature.copy()
    source.data = armature.data.copy()
    source.name = "pusfume_1p_source_animation_rig"
    bpy.context.scene.collection.objects.link(source)
    source.animation_data_clear()
    source.data.pose_position = "POSE"
    for pose_bone in source.pose.bones:
        pose_bone.matrix_basis = Matrix.Identity(4)
    bpy.context.view_layer.update()
    contaminated = [
        pose_bone.name
        for pose_bone in source.pose.bones
        if not pose_bone.matrix_basis.is_identity
    ]
    if contaminated:
        raise RuntimeError(
            "Duplicated Assassin source retained a saved pose: %s"
            % contaminated[:12]
        )
    return source


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


def nla_action_ranges(armature):
    animation_data = armature.animation_data
    ranges = {}
    for track in animation_data.nla_tracks if animation_data else ():
        for strip in track.strips:
            if strip.action is None or strip.action.name not in ACTION_NAMES:
                continue
            action_name = strip.action.name
            frame_range = (
                int(round(strip.action_frame_start)),
                int(round(strip.action_frame_end)),
            )
            if action_name in ranges and ranges[action_name] != frame_range:
                raise RuntimeError(
                    "Action %s has conflicting NLA windows: %s and %s"
                    % (action_name, ranges[action_name], frame_range)
                )
            ranges[action_name] = frame_range

    missing = sorted(set(ACTION_NAMES) - set(ranges))
    if missing:
        raise RuntimeError(
            "Janfon claw handoff is missing authored NLA windows: %s" % missing
        )
    return ranges


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


def local_rest_matrix(bone):
    if bone.parent is None:
        return bone.matrix_local.copy()
    return bone.parent.matrix_local.inverted() @ bone.matrix_local


def retarget_action(source, target, mesh, action, rest_points, authored_range):
    assign_action(source, action)
    transform_audit = sanitize_pose_transforms(source, action)
    keyed_start, keyed_end = (int(round(value)) for value in action.frame_range)
    # NLA strips are Janfon's authored gameplay windows. Several looping
    # actions intentionally retain helper keys outside them.
    frame_start, frame_end = authored_range
    if frame_end <= frame_start:
        raise RuntimeError("Action %s has no usable duration" % action.name)
    if frame_start < keyed_start or frame_end > keyed_end:
        raise RuntimeError(
            "Action %s NLA window %s leaves keyed range %s"
            % (action.name, authored_range, (keyed_start, keyed_end))
        )

    bpy.context.scene.render.fps = FPS
    bpy.context.scene.frame_start = frame_start
    bpy.context.scene.frame_end = frame_end

    source_rest = {
        bone.name: local_rest_matrix(bone) for bone in source.data.bones
    }
    target_rest = {
        bone.name: local_rest_matrix(bone) for bone in target.data.bones
    }
    if set(source_rest) != set(target_rest):
        raise RuntimeError("Source and donor-rest Assassin skeletons differ")

    target.animation_data_clear()
    target.animation_data_create()
    first_pose = None
    maximum_pose_delta = 0.0
    maximum_vertex_displacement = 0.0
    maximum_vertex_radius = 0.0
    for frame in range(frame_start, frame_end + 1):
        bpy.context.scene.frame_set(frame)
        for pose_bone in target.pose.bones:
            pose_bone.matrix_basis = Matrix.Identity(4)

        for bone_name in source_rest:
            source_basis = source.pose.bones[bone_name].matrix_basis
            parent_space_delta = (
                source_rest[bone_name]
                @ source_basis
                @ source_rest[bone_name].inverted()
            )
            target_basis = (
                target_rest[bone_name].inverted()
                @ parent_space_delta
                @ target_rest[bone_name]
            )
            target_pose = target.pose.bones[bone_name]
            target_pose.rotation_mode = "QUATERNION"
            target_pose.location = (0.0, 0.0, 0.0)
            target_pose.scale = (1.0, 1.0, 1.0)
            target_pose.rotation_quaternion = target_basis.to_quaternion()

        bpy.context.view_layer.update()
        if first_pose is None:
            first_pose = {
                bone.name: bone.matrix.copy() for bone in target.pose.bones
            }
        else:
            maximum_pose_delta = max(
                maximum_pose_delta,
                max(
                    abs(first_pose[bone.name][row][column] - bone.matrix[row][column])
                    for bone in target.pose.bones
                    for row in range(4)
                    for column in range(4)
                ),
            )

        posed_points = preparation.evaluated_vertex_positions(mesh)
        maximum_vertex_displacement = max(
            maximum_vertex_displacement,
            max(
                (posed_points[index] - rest_points[index]).length
                for index in range(len(rest_points))
            ),
        )
        maximum_vertex_radius = max(
            maximum_vertex_radius,
            max((point.length for point in posed_points), default=0.0),
        )

        for pose_bone in target.pose.bones:
            pose_bone.keyframe_insert(
                data_path="rotation_quaternion", frame=frame, group=pose_bone.name
            )

    target_action = target.animation_data and target.animation_data.action
    if target_action is None:
        raise RuntimeError("Action %s produced no retargeted action" % action.name)
    target_action.name = action.name + "_donor_rest"
    if maximum_pose_delta < 0.001:
        raise RuntimeError(
            "Action %s does not move the donor-rest rig: %.8f"
            % (action.name, maximum_pose_delta)
        )
    if maximum_vertex_displacement > MAXIMUM_POSED_VERTEX_DISPLACEMENT:
        raise RuntimeError(
            "Action %s leaves the first-person envelope: %.6f m"
            % (action.name, maximum_vertex_displacement)
        )

    return target_action, {
        "maximum_pose_delta": maximum_pose_delta,
        "maximum_vertex_displacement": maximum_vertex_displacement,
        "maximum_vertex_radius": maximum_vertex_radius,
        "transform_audit": transform_audit,
    }, frame_start, frame_end, keyed_start


def export_action(
    source, target, mesh, action, rest_points, authored_range, output_dir
):
    target_action, retarget_audit, frame_start, frame_end, keyed_start = (
        retarget_action(
            source, target, mesh, action, rest_points, authored_range
        )
    )

    output_path = os.path.join(output_dir, action.name + ".fbx")
    bpy.ops.object.select_all(action="DESELECT")
    target.select_set(True)
    bpy.context.view_layer.objects.active = target
    bpy.ops.export_scene.fbx(
        filepath=output_path,
        use_selection=True,
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
        "nla_frame_range": list(authored_range),
        "keyed_frame_start": keyed_start,
        "maximum_pose_delta": retarget_audit["maximum_pose_delta"],
        "output": output_path,
        "output_bytes": os.path.getsize(output_path),
        "retarget_audit": retarget_audit,
        "target_action": target_action.name,
    }


def main(input_path, donor_unit_path, output_dir):
    bpy.ops.wm.open_mainfile(filepath=input_path, load_ui=False)
    mesh, target = preparation.find_arms_and_rig()
    validate_armature(target)
    authored_ranges = nla_action_ranges(target)
    source = duplicate_source_armature(target)
    actions = {action.name: action for action in bpy.data.actions}
    missing = sorted(set(ACTION_NAMES) - set(actions))
    if missing:
        raise RuntimeError("Janfon claw handoff is missing actions: %s" % missing)

    bind_reset = preparation.reset_bind_pose(mesh, target)
    donor_conformance = preparation.conform_mesh_to_donor_rest(
        mesh, target, donor_unit_path
    )
    donor_rebind = preparation.rebind_to_donor_rest(
        mesh, target, donor_unit_path
    )
    target.data.pose_position = "REST"
    rest_points = preparation.evaluated_vertex_positions(mesh)
    target.data.pose_position = "POSE"

    # Weapon reference objects are not animation resources. The skinned mesh
    # remains in memory only for deformation-envelope validation; FBX export is
    # selection-scoped to the donor-rest target armature.
    for scene_object in list(bpy.context.scene.objects):
        if scene_object not in (source, target, mesh):
            bpy.data.objects.remove(scene_object, do_unlink=True)

    os.makedirs(output_dir, exist_ok=True)
    exported = [
        export_action(
            source,
            target,
            mesh,
            actions[action_name],
            rest_points,
            authored_ranges[action_name],
            output_dir,
        )
        for action_name in ACTION_NAMES
    ]
    manifest_path = os.path.join(output_dir, "pusfume_1p_claw_actions.json")
    manifest = {
        "actions": exported,
        "bind_reset": bind_reset,
        "bones": len(target.data.bones),
        "donor_conformance": donor_conformance,
        "donor_rebind": donor_rebind,
        "donor_unit": donor_unit_path,
        "fps": FPS,
        "source": input_path,
    }
    with open(manifest_path, "w", encoding="ascii", newline="\n") as stream:
        json.dump(manifest, stream, indent=2, sort_keys=True)
        stream.write("\n")
    print("PUSFUME_1P_ACTION_EXPORT=" + json.dumps(manifest, sort_keys=True))


arguments = arguments_after_separator()
if len(arguments) != 3:
    raise SystemExit(
        "usage: export_pusfume_1p_actions.py -- INPUT.blend DONOR.unit OUTPUT_DIR"
    )
main(*(os.path.abspath(argument) for argument in arguments))
