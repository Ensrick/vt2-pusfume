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
        ("j_test1", (0.0, 0.0, 0.5), (0.0, 0.2, 1.0)),
        ("j_test2", (0.0, 0.0, 0.5), (0.0, -0.2, 1.0)),
    )
    for name, head, tail in child_specs:
        bone = armature_data.edit_bones.new(name)
        bone.head = head
        bone.tail = tail
        bone.parent = root
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


def test_pose_mirroring(armature, settings, operators):
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

    for pose_bone in armature.pose.bones:
        pose_bone.matrix_basis.identity()
        pose_bone.select = False
    right.select = True
    armature.data.bones.active = right.bone
    right.rotation_mode = "QUATERNION"
    right.rotation_quaternion = Quaternion((0.0, 0.0, 1.0), 0.27)
    bpy.context.view_layer.update()
    expected_left = expected_mirror(right, left)
    settings.live_mirror_enabled = True
    live = operators.apply_pose_mirror(bpy.context, settings, changed_only=True)
    if live["changed"] != 1 or matrix_error(left.matrix, expected_left) > 1e-5:
        raise RuntimeError("Live j_right-to-j_left VT2 pose mirror failed")
    settings.live_mirror_enabled = False

    for pose_bone in armature.pose.bones:
        pose_bone.matrix_basis.identity()
        pose_bone.select = True
    bpy.context.view_layer.update()
    bpy.ops.object.mode_set(mode="OBJECT")


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
    else:
        sys.path.insert(0, str(Path(repo_root) / "blender_addon"))
        vt2_content_tools = importlib.import_module("vt2_content_tools")
        validation = importlib.import_module("vt2_content_tools.validation")
        operators = importlib.import_module("vt2_content_tools.operators")

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
    test_pose_mirroring(bpy.data.objects["fixture_rig"], settings, operators)

    bpy.ops.object.select_all(action="DESELECT")
    armature.select_set(True)
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
                "pose_mirror": "one-shot and live left-right/right-left",
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
