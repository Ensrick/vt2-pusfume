"""Non-destructive animation transfer from an animator rig to a VT2 rig."""

from __future__ import annotations

import json

import bpy
from mathutils import Matrix


REST_SIGNATURE_PROPERTY = "vt2_ik_rest_signature"
CONTROL_FOR_PROPERTY = "vt2_ik_control_for"
REST_TOLERANCE = 1e-6
POSITION_TOLERANCE = 1e-4
ROTATION_TOLERANCE = 1e-4
SCALE_TOLERANCE = 1e-4


def _vector_values(value):
    return [float(component) for component in value]


def _matrix_values(matrix):
    return [
        [float(matrix[row][column]) for column in range(4)]
        for row in range(4)
    ]


def rest_signature(armature):
    """Capture every export-relevant property of an armature's rest skeleton."""
    if armature is None or armature.type != "ARMATURE":
        raise ValueError("A VT2 armature is required")
    return {
        bone.name: {
            "head": _vector_values(bone.head_local),
            "tail": _vector_values(bone.tail_local),
            "matrix": _matrix_values(bone.matrix_local),
            "parent": bone.parent.name if bone.parent else None,
            "use_connect": bool(bone.use_connect),
        }
        for bone in armature.data.bones
    }


def store_rest_signature(armature):
    signature = rest_signature(armature)
    armature[REST_SIGNATURE_PROPERTY] = json.dumps(signature, sort_keys=True)
    return signature


def stored_rest_signature(armature):
    payload = armature.get(REST_SIGNATURE_PROPERTY)
    if not payload:
        return None
    try:
        return json.loads(payload)
    except (TypeError, json.JSONDecodeError):
        return None


def _maximum_nested_error(first, second):
    if isinstance(first, list) and isinstance(second, list):
        if len(first) != len(second):
            return float("inf")
        return max(
            (_maximum_nested_error(left, right) for left, right in zip(first, second)),
            default=0.0,
        )
    return abs(float(first) - float(second))


def compare_rest_signatures(expected, actual, tolerance=REST_TOLERANCE):
    expected_names = set(expected)
    actual_names = set(actual)
    differences = []
    for name in sorted(expected_names - actual_names):
        differences.append(f"missing bone {name}")
    for name in sorted(actual_names - expected_names):
        differences.append(f"added bone {name}")
    for name in sorted(expected_names & actual_names):
        for field in ("parent", "use_connect"):
            if expected[name][field] != actual[name][field]:
                differences.append(f"{name}: {field} changed")
        for field in ("head", "tail", "matrix"):
            error = _maximum_nested_error(expected[name][field], actual[name][field])
            if error > tolerance:
                differences.append(f"{name}: {field} changed ({error:.8g})")
    return differences


def create_control_rig(context, game_rig):
    """Duplicate a game rig so its Edit Mode skeleton can be changed safely."""
    if context.mode != "OBJECT":
        raise RuntimeError("Switch to Object Mode before creating an IK control rig")
    if game_rig is None or game_rig.type != "ARMATURE":
        raise RuntimeError("Select the VT2 game armature first")

    baseline = store_rest_signature(game_rig)
    control = game_rig.copy()
    control.data = game_rig.data.copy()
    control.name = game_rig.name + "_CTRL"
    control.data.name = control.name
    control[CONTROL_FOR_PROPERTY] = game_rig.name

    collection = game_rig.users_collection[0] if game_rig.users_collection else context.collection
    collection.objects.link(control)
    if control.animation_data:
        source_action = control.animation_data.action
        control.animation_data_clear()
        if source_action is not None:
            control.animation_data_create()
            control.animation_data.action = source_action.copy()

    control.show_in_front = True
    game_rig.hide_set(True)
    for obj in context.selected_objects:
        obj.select_set(False)
    control.select_set(True)
    context.view_layer.objects.active = control
    return control, baseline


def _local_rest_matrix(bone):
    if bone.parent is None:
        return bone.matrix_local.copy()
    return bone.parent.matrix_local.inverted_safe() @ bone.matrix_local


def _matrix_error(first, second):
    return max(
        abs(first[row][column] - second[row][column])
        for row in range(4)
        for column in range(4)
    )


def bake_control_action(context, control, game_rig, action, output_name):
    """Bake an evaluated control pose onto an immutable VT2 rest skeleton."""
    if context.mode != "OBJECT":
        raise RuntimeError("Switch to Object Mode before baking the IK bridge")
    if control is None or control.type != "ARMATURE":
        raise RuntimeError("Choose an animator control armature")
    if game_rig is None or game_rig.type != "ARMATURE":
        raise RuntimeError("Choose the untouched VT2 game armature")
    if control == game_rig:
        raise RuntimeError("The control and VT2 game rigs must be different objects")
    if action is None:
        raise RuntimeError("Choose the control rig Action to bake")

    target_names = {bone.name for bone in game_rig.data.bones}
    source_names = {bone.name for bone in control.data.bones}
    missing = sorted(target_names - source_names)
    if missing:
        preview = ", ".join(missing[:8])
        suffix = "..." if len(missing) > 8 else ""
        raise RuntimeError(
            f"Control rig is missing {len(missing)} VT2 bone(s): {preview}{suffix}"
        )

    constrained_targets = [
        pose_bone.name for pose_bone in game_rig.pose.bones if pose_bone.constraints
    ]
    if constrained_targets:
        raise RuntimeError(
            "VT2 game rig must remain unconstrained; found constraints on "
            + ", ".join(constrained_targets[:8])
        )

    baseline = stored_rest_signature(game_rig)
    current_signature = rest_signature(game_rig)
    if baseline is None:
        baseline = store_rest_signature(game_rig)
    else:
        differences = compare_rest_signatures(baseline, current_signature)
        if differences:
            raise RuntimeError(
                "VT2 rest skeleton changed after pairing: " + "; ".join(differences[:6])
            )

    original_frame = context.scene.frame_current
    original_source_action = (
        control.animation_data.action if control.animation_data else None
    )
    original_target_action = (
        game_rig.animation_data.action if game_rig.animation_data else None
    )
    frame_start = int(round(action.frame_range[0]))
    frame_end = int(round(action.frame_range[1]))
    if frame_end < frame_start:
        raise RuntimeError("The selected Action has an invalid frame range")

    control.animation_data_create()
    control.animation_data.action = action
    game_rig.animation_data_create()
    baked_action = bpy.data.actions.new(output_name or action.name + "_VT2")
    game_rig.animation_data.action = baked_action
    game_rig.data.pose_position = "POSE"

    target_rest = {
        bone.name: _local_rest_matrix(bone) for bone in game_rig.data.bones
    }
    ordered_targets = sorted(
        game_rig.pose.bones,
        key=lambda pose_bone: len(pose_bone.parent_recursive),
    )
    target_from_control = game_rig.matrix_world.inverted_safe() @ control.matrix_world
    maximum_position_error = 0.0
    maximum_rotation_error = 0.0
    maximum_position_bone = None
    maximum_source_scale_error = 0.0
    first_pose = None
    maximum_motion = 0.0

    try:
        for frame in range(frame_start, frame_end + 1):
            context.scene.frame_set(frame)
            context.view_layer.update()
            desired = {
                name: target_from_control @ control.pose.bones[name].matrix.copy()
                for name in target_names
            }
            maximum_source_scale_error = max(
                maximum_source_scale_error,
                max(
                    max(abs(component - 1.0) for component in desired[name].to_scale())
                    for name in target_names
                ),
            )
            composed = {}
            for target_pose in ordered_targets:
                name = target_pose.name
                parent_matrix = (
                    composed[target_pose.parent.name]
                    if target_pose.parent
                    else Matrix.Identity(4)
                )
                rest_frame = parent_matrix @ target_rest[name]
                basis = rest_frame.inverted_safe() @ desired[name]
                rotation = basis.to_quaternion()
                rotation.normalize()
                # VT2 locomotion clips are rotation-only. A modified control
                # rig may have different bone lengths, but connected game
                # bones cannot and must not be translated to those new heads.
                offset = basis.translation if target_pose.parent is None else (0, 0, 0)

                target_pose.rotation_mode = "QUATERNION"
                target_pose.location = offset
                target_pose.rotation_quaternion = rotation
                target_pose.scale = (1.0, 1.0, 1.0)
                composed[name] = (
                    rest_frame
                    @ Matrix.Translation(offset)
                    @ rotation.to_matrix().to_4x4()
                )

            context.view_layer.update()
            frame_position_errors = {
                name: (
                    game_rig.pose.bones[name].matrix.translation
                    - desired[name].translation
                ).length
                for name in target_names
                if game_rig.pose.bones[name].parent is None
            }
            frame_position_bone = max(
                frame_position_errors, key=frame_position_errors.get
            )
            if frame_position_errors[frame_position_bone] > maximum_position_error:
                maximum_position_error = frame_position_errors[frame_position_bone]
                maximum_position_bone = frame_position_bone
            maximum_rotation_error = max(
                maximum_rotation_error,
                max(
                    game_rig.pose.bones[name]
                    .matrix.to_quaternion()
                    .rotation_difference(desired[name].to_quaternion())
                    .angle
                    for name in target_names
                ),
            )
            if first_pose is None:
                first_pose = {
                    name: game_rig.pose.bones[name].matrix.copy()
                    for name in target_names
                }
            else:
                maximum_motion = max(
                    maximum_motion,
                    max(
                        _matrix_error(game_rig.pose.bones[name].matrix, first_pose[name])
                        for name in target_names
                    ),
                )

            for target_pose in game_rig.pose.bones:
                target_pose.keyframe_insert(
                    data_path="location", frame=frame, group=target_pose.name
                )
                target_pose.keyframe_insert(
                    data_path="rotation_quaternion",
                    frame=frame,
                    group=target_pose.name,
                )

        if (
            maximum_position_error > POSITION_TOLERANCE
            or maximum_rotation_error > ROTATION_TOLERANCE
            or maximum_source_scale_error > SCALE_TOLERANCE
        ):
            raise RuntimeError(
                "IK bake fidelity failed "
                f"(position {maximum_position_error:.6g} m, "
                f"rotation {maximum_rotation_error:.6g} rad, "
                f"root {maximum_position_bone}, "
                f"source scale delta {maximum_source_scale_error:.6g})"
            )
        differences = compare_rest_signatures(baseline, rest_signature(game_rig))
        if differences:
            raise RuntimeError(
                "Bake modified the VT2 rest skeleton: " + "; ".join(differences[:6])
            )
    except Exception:
        game_rig.animation_data.action = original_target_action
        bpy.data.actions.remove(baked_action)
        raise
    finally:
        control.animation_data.action = original_source_action
        context.scene.frame_set(original_frame)
        context.view_layer.update()

    game_rig.animation_data.action = baked_action
    return {
        "action": baked_action,
        "bones": len(target_names),
        "frames": frame_end - frame_start + 1,
        "maximum_motion": maximum_motion,
        "maximum_position_error": maximum_position_error,
        "maximum_rotation_error": maximum_rotation_error,
        "maximum_source_scale_error": maximum_source_scale_error,
    }
