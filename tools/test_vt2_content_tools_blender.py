"""Blender 5.2 integration fixture for VT2 Content Tools."""

from __future__ import annotations

import importlib
import json
import os
from pathlib import Path
import sys

import bpy
from mathutils import Matrix, Quaternion


def create_fixture(texture_path, reset_factory=True):
    if reset_factory:
        bpy.ops.wm.read_factory_settings(use_empty=True)
    else:
        for obj in list(bpy.data.objects):
            bpy.data.objects.remove(obj, do_unlink=True)

    armature_data = bpy.data.armatures.new("fixture_rig")
    armature = bpy.data.objects.new("fixture_rig", armature_data)
    bpy.context.scene.collection.objects.link(armature)
    bpy.context.view_layer.objects.active = armature
    armature.select_set(True)
    bpy.ops.object.mode_set(mode="EDIT")
    root = armature_data.edit_bones.new("j_root")
    root.head = (0.0, 0.0, 0.0)
    root.tail = (0.0, 0.0, 0.5)
    child_specs = (
        ("j_leftarm", (0.2, 0.0, 0.5), (0.7, 0.0, 0.8)),
        ("j_rightarm", (-0.2, 0.0, 0.5), (-0.7, 0.0, 0.8)),
        ("j_leftforearm", (0.7, 0.0, 0.8), (1.1, 0.0, 0.8)),
        ("j_test1", (0.0, 0.0, 0.5), (0.0, 0.2, 1.0)),
        ("j_test2", (0.0, 0.0, 0.5), (0.0, -0.2, 1.0)),
    )
    for name, head, tail in child_specs:
        bone = armature_data.edit_bones.new(name)
        bone.head = head
        bone.tail = tail
        bone.parent = root
        if name == "j_leftforearm":
            bone.parent = armature_data.edit_bones["j_leftarm"]
            bone.use_connect = True
    bpy.ops.object.mode_set(mode="OBJECT")

    mesh_data = bpy.data.meshes.new("fixture_body")
    mesh_data.from_pydata(
        [(-0.5, 0.0, 0.0), (0.5, 0.0, 0.0), (0.0, 0.0, 1.0)],
        [],
        [(0, 1, 2)],
    )
    mesh_data.update()
    uv_layer = mesh_data.uv_layers.new(name="UVMap")
    for loop, uv in zip(uv_layer.data, ((0.0, 0.0), (1.0, 0.0), (0.5, 1.0))):
        loop.uv = uv
    material = bpy.data.materials.new("p_fixture")
    material.use_nodes = True
    texture_path.parent.mkdir(parents=True, exist_ok=True)
    image = bpy.data.images.new("fixture_df", width=1, height=1)
    image.generated_color = (0.25, 0.5, 0.75, 1.0)
    image.filepath_raw = str(texture_path)
    image.file_format = "PNG"
    image.save()
    image_node = material.node_tree.nodes.new("ShaderNodeTexImage")
    image_node.image = image
    mesh_data.materials.append(material)

    mesh = bpy.data.objects.new("fixture_body", mesh_data)
    bpy.context.scene.collection.objects.link(mesh)
    modifier = mesh.modifiers.new("fixture_armature", "ARMATURE")
    modifier.object = armature
    # Extracted VT2 scenes can retain an unresolved Armature modifier. It must
    # not inject None into the validator's referenced-object collection.
    mesh.modifiers.new("unbound_armature_reference", "ARMATURE")
    for bone in armature.data.bones:
        group = mesh.vertex_groups.new(name=bone.name)
        group.add([0, 1, 2], 0.2, "REPLACE")

    armature.animation_data_create()
    action = bpy.data.actions.new("fixture_idle")
    armature.animation_data.action = action
    pose_bone = armature.pose.bones["j_root"]
    pose_bone.rotation_mode = "QUATERNION"
    pose_bone.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
    pose_bone.keyframe_insert("rotation_quaternion", frame=1)
    pose_bone.rotation_quaternion = (0.995, 0.0, 0.1, 0.0)
    pose_bone.keyframe_insert("rotation_quaternion", frame=10)
    constant_bone = armature.pose.bones["j_leftarm"]
    constant_bone.location = (0.0, 0.0, 0.0)
    constant_bone.scale = (1.0, 1.0, 1.0)
    constant_bone.keyframe_insert("location", frame=1)
    constant_bone.keyframe_insert("location", frame=10)
    constant_bone.keyframe_insert("scale", frame=1)
    constant_bone.keyframe_insert("scale", frame=10)

    bpy.context.scene.render.fps = 30
    bpy.ops.object.select_all(action="SELECT")
    bpy.context.view_layer.objects.active = mesh
    return armature, mesh


def matrix_error(first, second):
    return max(
        abs(first[row][column] - second[row][column])
        for row in range(4)
        for column in range(4)
    )


def expected_mirror(source, target, axis="X"):
    reflection = Matrix.Identity(4)
    index = {"X": 0, "Y": 1, "Z": 2}[axis]
    reflection[index][index] = -1.0
    mirrored_pose = reflection @ source.matrix @ reflection
    mirrored_rest = reflection @ source.bone.matrix_local @ reflection
    return mirrored_pose @ mirrored_rest.inverted_safe() @ target.bone.matrix_local


def test_pose_mirroring(armature, settings, operators, live_mirror):
    live_mirror.unregister_handlers()
    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    bpy.ops.object.mode_set(mode="POSE")
    left = armature.pose.bones["j_leftarm"]
    right = armature.pose.bones["j_rightarm"]
    for pose_bone in armature.pose.bones:
        pose_bone.select = False

    left.select = True
    armature.data.bones.active = left.bone
    left.rotation_mode = "QUATERNION"
    left.rotation_quaternion = Quaternion((0.0, 1.0, 0.0), 0.35)
    bpy.context.view_layer.update()
    expected_right = expected_mirror(left, right)
    settings.mirror_direction = "LEFT_TO_RIGHT"
    settings.mirror_axis = "X"
    settings.mirror_selected_only = True
    if bpy.ops.vt2.mirror_pose() != {"FINISHED"}:
        raise RuntimeError("Left-to-right VT2 pose mirror failed")
    if matrix_error(right.matrix, expected_right) > 1e-5:
        raise RuntimeError("Left-to-right VT2 pose mirror produced the wrong matrix")

    left.select = False
    right.select = True
    armature.data.bones.active = right.bone
    right.rotation_mode = "QUATERNION"
    right.rotation_quaternion = Quaternion((1.0, 0.0, 0.0), -0.2)
    bpy.context.view_layer.update()
    expected_left = expected_mirror(right, left)
    settings.mirror_direction = "RIGHT_TO_LEFT"
    if bpy.ops.vt2.mirror_pose() != {"FINISHED"}:
        raise RuntimeError("Right-to-left VT2 pose mirror failed")
    if matrix_error(left.matrix, expected_left) > 1e-5:
        raise RuntimeError("Right-to-left VT2 pose mirror produced the wrong matrix")

    try:
        for pose_bone in armature.pose.bones:
            pose_bone.matrix_basis.identity()
            pose_bone.select = False
        right.select = True
        armature.data.bones.active = right.bone
        settings.live_mirror_enabled = True
        live_mirror.reset_live_mirror_state(armature)
        live_mirror.apply_live_pose_mirror(bpy.context)

        right.rotation_mode = "QUATERNION"
        right.rotation_quaternion = Quaternion((0.0, 0.0, 1.0), 0.27)
        bpy.context.view_layer.update()
        expected_left = expected_mirror(right, left)
        live = live_mirror.apply_live_pose_mirror(bpy.context)
        if live["changed"] != 1 or matrix_error(left.matrix, expected_left) > 1e-5:
            raise RuntimeError("Live j_right-to-j_left VT2 pose mirror failed")

        right.select = False
        left.select = True
        armature.data.bones.active = left.bone
        left.rotation_quaternion = Quaternion((1.0, 0.0, 0.0), 0.31)
        bpy.context.view_layer.update()
        expected_right = expected_mirror(left, right)
        live = live_mirror.apply_live_pose_mirror(bpy.context)
        if live["changed"] != 1 or matrix_error(right.matrix, expected_right) > 1e-5:
            raise RuntimeError("Live j_left-to-j_right VT2 pose mirror failed")

        bpy.context.scene.tool_settings.use_keyframe_insert_auto = True
        left.rotation_quaternion = Quaternion((0.0, 1.0, 0.0), -0.23)
        bpy.context.view_layer.update()
        live = live_mirror.apply_live_pose_mirror(bpy.context)
        if live["keyed"] != 1:
            raise RuntimeError("Live VT2 mirror did not honor Blender Auto Key")
    finally:
        bpy.context.scene.tool_settings.use_keyframe_insert_auto = False
        settings.live_mirror_enabled = False
        live_mirror.reset_live_mirror_state(armature)
        live_mirror.register_handlers()

    for pose_bone in armature.pose.bones:
        pose_bone.matrix_basis.identity()
        pose_bone.select = True
    bpy.context.view_layer.update()
    bpy.ops.object.mode_set(mode="OBJECT")


def test_ik_bridge(armature, settings, ik_bridge):
    bpy.ops.object.select_all(action="DESELECT")
    armature.hide_set(False)
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature
    baseline = ik_bridge.rest_signature(armature)

    if bpy.ops.vt2.create_ik_control_rig() != {"FINISHED"}:
        raise RuntimeError("Could not create the IK-safe animator rig")
    control = settings.ik_control_rig
    if control is None or settings.ik_game_rig != armature:
        raise RuntimeError("IK bridge did not pair the control and VT2 game rigs")

    # Deliberately make the animator skeleton incompatible as a game skeleton.
    # The evaluated poses must still bake back without changing the VT2 rest rig.
    bpy.context.view_layer.objects.active = control
    bpy.ops.object.mode_set(mode="EDIT")
    upper = control.data.edit_bones["j_leftarm"]
    forearm = control.data.edit_bones["j_leftforearm"]
    upper.tail = (0.65, 0.1, 0.95)
    forearm.head = upper.tail
    forearm.tail = (1.25, 0.1, 0.95)
    forearm.parent = upper
    forearm.use_connect = True
    bpy.ops.object.mode_set(mode="POSE")

    target = bpy.data.objects.new("fixture_ik_target", None)
    bpy.context.scene.collection.objects.link(target)
    target.location = (1.0, 0.1, 0.9)
    target.keyframe_insert("location", frame=1)
    target.location = (0.35, 0.8, 1.15)
    target.keyframe_insert("location", frame=10)
    constraint = control.pose.bones["j_leftforearm"].constraints.new("IK")
    constraint.target = target
    constraint.chain_count = 2
    bpy.ops.object.mode_set(mode="OBJECT")

    control.animation_data_create()
    action = bpy.data.actions.new("fixture_ik")
    control.animation_data.action = action
    root = control.pose.bones["j_root"]
    root.rotation_mode = "QUATERNION"
    root.rotation_quaternion = (1.0, 0.0, 0.0, 0.0)
    root.keyframe_insert("rotation_quaternion", frame=1)
    root.keyframe_insert("rotation_quaternion", frame=10)
    settings.ik_source_action = action
    settings.ik_output_name = "fixture_ik_VT2"

    if bpy.ops.vt2.bake_ik_to_game_rig() != {"FINISHED"}:
        raise RuntimeError("Could not bake the evaluated IK motion to the VT2 rig")
    if settings.clip_action is None or settings.clip_action.name != "fixture_ik_VT2":
        raise RuntimeError("IK bake did not create and select its export Action")

    differences = ik_bridge.compare_rest_signatures(
        baseline, ik_bridge.rest_signature(armature)
    )
    if differences:
        raise RuntimeError(f"IK bridge changed the VT2 rest skeleton: {differences}")
    bpy.context.scene.frame_set(1)
    first = armature.pose.bones["j_leftforearm"].matrix.copy()
    bpy.context.scene.frame_set(10)
    last = armature.pose.bones["j_leftforearm"].matrix.copy()
    if matrix_error(first, last) < 0.01:
        raise RuntimeError("Baked VT2 arm did not follow the IK target")
    settings.ik_control_rig = None
    settings.ik_game_rig = None
    bpy.data.objects.remove(control, do_unlink=True)
    bpy.data.objects.remove(target, do_unlink=True)
    armature.hide_set(False)
    armature.select_set(True)
    bpy.context.view_layer.objects.active = armature


def main(repo_root, output_root, installed=False):
    if installed:
        vt2_content_tools = importlib.import_module(
            "bl_ext.user_default.vt2_content_tools"
        )
        validation = importlib.import_module(
            "bl_ext.user_default.vt2_content_tools.validation"
        )
        operators = importlib.import_module(
            "bl_ext.user_default.vt2_content_tools.operators"
        )
        live_mirror = importlib.import_module(
            "bl_ext.user_default.vt2_content_tools.live_mirror"
        )
        ik_bridge = importlib.import_module(
            "bl_ext.user_default.vt2_content_tools.ik_bridge"
        )
    else:
        sys.path.insert(0, str(Path(repo_root) / "blender_addon"))
        vt2_content_tools = importlib.import_module("vt2_content_tools")
        validation = importlib.import_module("vt2_content_tools.validation")
        operators = importlib.import_module("vt2_content_tools.operators")
        live_mirror = importlib.import_module("vt2_content_tools.live_mirror")
        ik_bridge = importlib.import_module("vt2_content_tools.ik_bridge")

    output_root = Path(output_root)
    texture_path = output_root.parent / f"{output_root.name}-source" / "fixture_df.png"
    armature, mesh = create_fixture(texture_path, reset_factory=not installed)
    if not installed:
        vt2_content_tools.register()
    settings = bpy.context.scene.vt2_content_tools
    settings.asset_name = "fixture"
    settings.clip_name = "idle"
    settings.export_directory = str(output_root.resolve())
    settings.export_mode = "BOTH"
    settings.scope = "ALL"
    settings.include_textures = True
    collected = validation.export_objects(bpy.context, settings.scope)
    if None in collected:
        raise RuntimeError("Unbound Armature modifier injected None into export scope")
    mesh.modifiers.remove(mesh.modifiers["unbound_armature_reference"])
    test_pose_mirroring(
        bpy.data.objects["fixture_rig"], settings, operators, live_mirror
    )
    test_ik_bridge(bpy.data.objects["fixture_rig"], settings, ik_bridge)
    settings.clip_action = bpy.data.actions["fixture_idle"]
    settings.clip_name = "idle"

    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
    armature.hide_set(False)
    bpy.context.view_layer.objects.active = armature
    settings.scope = "SELECTED"
    selected_names = {obj.name for obj in validation.export_objects(bpy.context, settings.scope)}
    if selected_names != {"fixture_body", "fixture_rig"}:
        raise RuntimeError(f"Selected armature did not discover its bound mesh: {selected_names}")

    settings.scope = "ALL"
    settings.clip_action = armature.animation_data.action
    armature.animation_data.action = None
    bpy.ops.object.select_all(action="SELECT")

    before = validation.validate(bpy.context, settings)
    if not any(issue["code"] == "too_many_influences" for issue in before["issues"]):
        raise RuntimeError(f"Fixture did not trigger the weight limit: {before}")
    if bpy.ops.vt2.repair_weights("EXEC_DEFAULT") != {"FINISHED"}:
        raise RuntimeError("VT2 weight repair operator failed")

    after = validation.validate(bpy.context, settings)
    if after["summary"]["errors"]:
        raise RuntimeError(f"Fixture validation failed after repair: {after}")
    noisy_channels = {"animated_scale", "non_root_translation"}
    if noisy_channels.intersection(issue["code"] for issue in after["issues"]):
        raise RuntimeError(f"Constant FBX bake channels produced warnings: {after}")
    if bpy.ops.vt2.export_handoff() != {"FINISHED"}:
        raise RuntimeError("VT2 handoff export operator failed")

    output_root = Path(output_root)
    expected = {
        "fixture_3p.fbx",
        "fixture_idle.fbx",
        "fixture_vt2_handoff.json",
        "textures/fixture_df.png",
    }
    missing = sorted(name for name in expected if not (output_root / name).is_file())
    if missing:
        raise RuntimeError(f"VT2 handoff omitted files: {missing}")
    handoff_text = (output_root / "fixture_vt2_handoff.json").read_text()
    if str(Path(repo_root).resolve()) in handoff_text:
        raise RuntimeError("Handoff manifest leaked an absolute repository path")
    handoff = json.loads(handoff_text)
    if handoff["blender_version"] != "5.2.0 LTS":
        raise RuntimeError(f"Unexpected Blender acceptance version: {handoff['blender_version']}")
    if handoff["validation"]["summary"]["errors"]:
        raise RuntimeError("Exported handoff contains validation errors")
    if handoff["textures"][0]["status"] != "copied":
        raise RuntimeError(f"Texture collection failed: {handoff['textures']}")

    print(
        "VT2_ADDON_BLENDER_TEST="
        + json.dumps(
            {
                "blender": bpy.app.version_string,
                "files": sorted(expected),
                "pre_repair_errors": before["summary"]["errors"],
                "pose_mirror": "automatic bidirectional live mirror with Auto Key",
                "ik_bridge": "altered control rest and evaluated IK baked to immutable VT2 rest",
                "warnings": after["summary"]["warnings"],
            },
            sort_keys=True,
        )
    )
    if not installed:
        vt2_content_tools.unregister()


arguments = sys.argv[sys.argv.index("--") + 1 :]
if len(arguments) not in (2, 3):
    raise SystemExit(
        "usage: test_vt2_content_tools_blender.py -- REPO_ROOT OUTPUT_ROOT [--installed]"
    )
installed = len(arguments) == 3 and arguments[2] == "--installed"
main(
    os.path.abspath(arguments[0]),
    os.path.abspath(arguments[1]),
    installed=installed,
)
