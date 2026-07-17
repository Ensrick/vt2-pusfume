"""Operators for validating, repairing, and exporting VT2 handoffs."""

from __future__ import annotations

import hashlib
import json
import math
import os
from pathlib import Path
import shutil

import bpy

from . import core
from . import validation


REPORT_TEXT_NAME = "VT2 Validation Report"


def _write_report_text(report):
    text = bpy.data.texts.get(REPORT_TEXT_NAME) or bpy.data.texts.new(REPORT_TEXT_NAME)
    text.clear()
    text.write(json.dumps(report, indent=2, sort_keys=True))


def _update_status(settings, report, message):
    settings.last_errors = report["summary"]["errors"]
    settings.last_warnings = report["summary"]["warnings"]
    settings.last_report = message
    _write_report_text(report)


def _sha256(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for block in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(block)
    return digest.hexdigest()


def _export_selection(context, objects, output_path, animation):
    selected_before = list(context.selected_objects)
    active_before = context.view_layer.objects.active
    frame_start = context.scene.frame_start
    frame_end = context.scene.frame_end

    try:
        bpy.ops.object.select_all(action="DESELECT")
        for obj in objects:
            obj.select_set(True)
        armatures = [obj for obj in objects if obj.type == "ARMATURE"]
        context.view_layer.objects.active = armatures[0] if armatures else objects[0]

        if animation:
            armature = armatures[0]
            action = armature.animation_data.action
            context.scene.frame_start = math.floor(action.frame_range[0])
            context.scene.frame_end = math.ceil(action.frame_range[1])

        result = bpy.ops.export_scene.fbx(
            filepath=str(output_path),
            check_existing=False,
            use_selection=True,
            object_types={"ARMATURE"} if animation else {"ARMATURE", "EMPTY", "MESH"},
            use_mesh_modifiers=True,
            mesh_smooth_type="OFF",
            axis_forward="-Y",
            axis_up="Z",
            add_leaf_bones=False,
            primary_bone_axis="Y",
            secondary_bone_axis="X",
            use_armature_deform_only=False,
            bake_anim=animation,
            bake_anim_use_all_bones=True,
            bake_anim_use_nla_strips=False,
            bake_anim_use_all_actions=False,
            bake_anim_force_startend_keying=True,
            bake_anim_simplify_factor=0.0,
            path_mode="AUTO",
            embed_textures=False,
        )
        if "FINISHED" not in result:
            raise RuntimeError(f"Blender FBX export failed: {sorted(result)}")
    finally:
        context.scene.frame_start = frame_start
        context.scene.frame_end = frame_end
        bpy.ops.object.select_all(action="DESELECT")
        for obj in selected_before:
            if obj.name in context.view_layer.objects:
                obj.select_set(True)
        context.view_layer.objects.active = active_before


def _material_images(meshes):
    images = set()
    for mesh in meshes:
        for material in mesh.data.materials:
            if material is None or not material.use_nodes or material.node_tree is None:
                continue
            for node in material.node_tree.nodes:
                image = getattr(node, "image", None)
                if image is not None:
                    images.add(image)
    return sorted(images, key=lambda item: item.name)


def _copy_textures(meshes, output_root):
    texture_root = output_root / "textures"
    records = []
    used_names = set()

    for image in _material_images(meshes):
        source = Path(bpy.path.abspath(image.filepath)) if image.filepath else None
        extension = source.suffix if source and source.suffix else ".png"
        base_name = core.safe_name(source.stem if source else image.name, "texture")
        destination_name = base_name + extension.lower()
        if destination_name.lower() in used_names:
            suffix = hashlib.sha256((image.name + str(source)).encode("utf-8")).hexdigest()[:8]
            destination_name = f"{base_name}_{suffix}{extension.lower()}"
        used_names.add(destination_name.lower())
        destination = texture_root / destination_name

        status = "missing"
        if source and source.is_file():
            texture_root.mkdir(parents=True, exist_ok=True)
            shutil.copy2(source, destination)
            status = "copied"
        elif getattr(image, "packed_files", None):
            payload = bytes(image.packed_files[0].data)
            texture_root.mkdir(parents=True, exist_ok=True)
            destination.write_bytes(payload)
            status = "unpacked"

        record = {
            "image": image.name,
            "output": f"textures/{destination_name}" if status != "missing" else None,
            "source": source.name if source else None,
            "status": status,
        }
        if status != "missing":
            record["bytes"] = destination.stat().st_size
            record["sha256"] = _sha256(destination)
        records.append(record)
    return records


def _repair_mesh_weights(mesh, armature, maximum_influences):
    bone_names = {bone.name for bone in armature.data.bones}
    group_names = {group.index: group.name for group in mesh.vertex_groups}
    repaired_vertices = 0
    removed_influences = 0

    for vertex in mesh.data.vertices:
        assignments = [
            (assignment.group, assignment.weight)
            for assignment in vertex.groups
            if assignment.weight > 1e-6
            and group_names.get(assignment.group) in bone_names
        ]
        assignments.sort(key=lambda item: item[1], reverse=True)
        kept = assignments[:maximum_influences]
        removed = assignments[maximum_influences:]
        total = sum(weight for _, weight in kept)
        changed = bool(removed) or (kept and abs(total - 1.0) > 1e-6)

        for group_index, _ in removed:
            mesh.vertex_groups[group_index].remove([vertex.index])
        if total > 0:
            for group_index, weight in kept:
                mesh.vertex_groups[group_index].add(
                    [vertex.index], weight / total, "REPLACE"
                )
        if changed:
            repaired_vertices += 1
            removed_influences += len(removed)
    return repaired_vertices, removed_influences


class VT2_OT_validate(bpy.types.Operator):
    bl_idname = "vt2.validate"
    bl_label = "Validate VT2 Handoff"
    bl_description = "Validate the current export scope against VT2 character contracts"
    bl_options = {"REGISTER"}

    def execute(self, context):
        settings = context.scene.vt2_content_tools
        report = validation.validate(context, settings)
        summary = report["summary"]
        message = f"{summary['errors']} error(s), {summary['warnings']} warning(s)"
        _update_status(settings, report, message)
        if summary["errors"]:
            self.report({"ERROR"}, "VT2 validation failed: " + message)
        elif summary["warnings"]:
            self.report({"WARNING"}, "VT2 validation passed with " + message)
        else:
            self.report({"INFO"}, "VT2 validation passed")
        return {"FINISHED"}


class VT2_OT_repair_weights(bpy.types.Operator):
    bl_idname = "vt2.repair_weights"
    bl_label = "Limit and Normalize Weights"
    bl_description = "Prune exported bone weights to the configured limit and normalize them"
    bl_options = {"REGISTER", "UNDO"}

    def invoke(self, context, event):
        return context.window_manager.invoke_confirm(self, event)

    def execute(self, context):
        settings = context.scene.vt2_content_tools
        objects = validation.export_objects(context, settings.scope)
        meshes = [obj for obj in objects if obj.type == "MESH"]
        armatures = validation.armatures_for_objects(objects)
        if len(armatures) != 1 or not meshes:
            self.report({"ERROR"}, "Weight repair requires meshes and exactly one armature")
            return {"CANCELLED"}
        if context.mode != "OBJECT":
            self.report({"ERROR"}, "Switch to Object Mode before repairing weights")
            return {"CANCELLED"}

        repaired = 0
        removed = 0
        for mesh in meshes:
            mesh_repaired, mesh_removed = _repair_mesh_weights(
                mesh, armatures[0], settings.maximum_influences
            )
            repaired += mesh_repaired
            removed += mesh_removed
        report = validation.validate(context, settings)
        _update_status(
            settings,
            report,
            f"Repaired {repaired} vertices; removed {removed} influences",
        )
        self.report(
            {"INFO"},
            f"Repaired {repaired} vertices and removed {removed} excess influences",
        )
        return {"FINISHED"}


class VT2_OT_tag_material(bpy.types.Operator):
    bl_idname = "vt2.tag_material"
    bl_label = "Tag Active Material"
    bl_description = "Record the intended VT2 surface contract on the active material"
    bl_options = {"REGISTER", "UNDO"}

    @classmethod
    def poll(cls, context):
        return context.object is not None and context.object.active_material is not None

    def execute(self, context):
        settings = context.scene.vt2_content_tools
        material = context.object.active_material
        material["vt2_surface"] = settings.material_surface
        self.report({"INFO"}, f"Tagged {material.name} as {settings.material_surface}")
        return {"FINISHED"}


class VT2_OT_export_handoff(bpy.types.Operator):
    bl_idname = "vt2.export_handoff"
    bl_label = "Export VT2 Handoff"
    bl_description = "Validate and export VT2-oriented FBX files and a handoff manifest"
    bl_options = {"REGISTER"}

    def execute(self, context):
        settings = context.scene.vt2_content_tools
        report = validation.validate(context, settings)
        summary = report["summary"]
        _update_status(
            settings,
            report,
            f"{summary['errors']} error(s), {summary['warnings']} warning(s)",
        )
        if summary["errors"]:
            self.report({"ERROR"}, "Export blocked by VT2 validation errors")
            return {"CANCELLED"}
        if summary["warnings"] and not settings.allow_warnings:
            self.report({"ERROR"}, "Export blocked by warnings; enable Export With Warnings")
            return {"CANCELLED"}

        objects = validation.export_objects(context, settings.scope)
        meshes = [obj for obj in objects if obj.type == "MESH"]
        armature = validation.armatures_for_objects(objects)[0]
        output_root = Path(bpy.path.abspath(settings.export_directory)).resolve()
        output_root.mkdir(parents=True, exist_ok=True)
        outputs = []

        try:
            if settings.export_mode in {"MODEL", "BOTH"}:
                model_path = output_root / core.export_filename(settings.asset_name, "model")
                _export_selection(context, objects, model_path, animation=False)
                outputs.append(model_path)
            if settings.export_mode in {"ANIMATION", "BOTH"}:
                animation_path = output_root / core.export_filename(
                    settings.asset_name, "animation", settings.clip_name
                )
                _export_selection(context, [armature], animation_path, animation=True)
                outputs.append(animation_path)
        except Exception as error:
            self.report({"ERROR"}, f"VT2 FBX export failed: {error}")
            return {"CANCELLED"}

        textures = _copy_textures(meshes, output_root) if settings.include_textures else []
        handoff = {
            "addon_version": core.VERSION_STRING,
            "asset": core.safe_name(settings.asset_name),
            "blender_version": bpy.app.version_string,
            "exports": [
                {
                    "bytes": path.stat().st_size,
                    "file": path.name,
                    "sha256": _sha256(path),
                }
                for path in outputs
            ],
            "source_blend": Path(bpy.data.filepath).name if bpy.data.filepath else None,
            "textures": textures,
            "validation": report,
        }
        manifest_path = output_root / f"{core.safe_name(settings.asset_name)}_vt2_handoff.json"
        manifest_path.write_text(
            json.dumps(handoff, indent=2, sort_keys=True) + "\n",
            encoding="utf-8",
        )
        settings.last_output = str(output_root)
        settings.last_report = f"Exported {len(outputs)} FBX file(s)"
        self.report({"INFO"}, f"VT2 handoff exported to {output_root}")
        return {"FINISHED"}


CLASSES = (
    VT2_OT_validate,
    VT2_OT_repair_weights,
    VT2_OT_tag_material,
    VT2_OT_export_handoff,
)
