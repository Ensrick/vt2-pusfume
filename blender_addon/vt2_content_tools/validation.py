"""Blender scene validation for VT2 character handoffs."""

from __future__ import annotations

from datetime import datetime, timezone

import bpy

from . import core


EPSILON = 1e-6


def _add_referenced_armatures(objects):
    result = [obj for obj in objects if obj is not None]
    known = set(result)
    for obj in list(result):
        if obj.type != "MESH":
            continue
        for modifier in obj.modifiers:
            armature = modifier.object
            if (
                modifier.type == "ARMATURE"
                and armature is not None
                and armature not in known
            ):
                known.add(armature)
                result.append(armature)
    return result


def _add_bound_meshes(context, objects):
    result = list(objects)
    known = set(result)
    selected_armatures = {obj for obj in result if obj.type == "ARMATURE"}
    if not selected_armatures:
        return result

    for obj in context.scene.objects:
        if obj is None or obj.type != "MESH" or obj in known:
            continue
        if any(
            modifier.type == "ARMATURE" and modifier.object in selected_armatures
            for modifier in obj.modifiers
        ):
            result.append(obj)
            known.add(obj)
    return result


def export_objects(context, scope):
    supported = {"ARMATURE", "EMPTY", "MESH"}
    if scope == "SELECTED":
        objects = [
            obj
            for obj in context.selected_objects
            if obj is not None and obj.type in supported
        ]
        objects = _add_bound_meshes(context, objects)
    elif scope == "ACTIVE":
        active = context.view_layer.objects.active
        if active is None or active.type not in supported:
            return []
        objects = [active]
        if active.type == "ARMATURE":
            objects.extend(
                obj
                for obj in context.scene.objects
                if obj.type == "MESH"
                and any(
                    modifier.type == "ARMATURE" and modifier.object == active
                    for modifier in obj.modifiers
                )
            )
    else:
        objects = [
            obj
            for obj in context.scene.objects
            if obj is not None and obj.type in supported
        ]
    return _add_referenced_armatures(objects)


def armatures_for_objects(objects):
    armatures = {obj for obj in objects if obj.type == "ARMATURE"}
    for mesh in (obj for obj in objects if obj.type == "MESH"):
        armatures.update(
            modifier.object
            for modifier in mesh.modifiers
            if modifier.type == "ARMATURE" and modifier.object is not None
        )
    return sorted(armatures, key=lambda item: item.name)


def action_fcurves(action):
    if action is None:
        return []
    if hasattr(action, "fcurves"):
        return list(action.fcurves)

    curves = []
    for layer in getattr(action, "layers", ()):
        for strip in getattr(layer, "strips", ()):
            for channelbag in getattr(strip, "channelbags", ()):
                curves.extend(channelbag.fcurves)
    return curves


def action_data_paths(action):
    return [curve.data_path for curve in action_fcurves(action)]


def varying_action_data_paths(action, tolerance=1e-6):
    paths = []
    for curve in action_fcurves(action):
        values = [point.co[1] for point in curve.keyframe_points]
        if values and max(values) - min(values) > tolerance:
            paths.append(curve.data_path)
    return paths


def _transform_is_identity(obj):
    location, rotation, scale = obj.matrix_basis.decompose()
    return (
        location.length <= 1e-5
        and abs(rotation.angle) <= 1e-5
        and all(abs(component - 1.0) <= 1e-5 for component in scale)
    )


def _weight_rows(mesh, bone_names):
    group_names = {group.index: group.name for group in mesh.vertex_groups}
    rows = []
    unknown_groups = set()
    for vertex in mesh.data.vertices:
        weights = []
        for assignment in vertex.groups:
            if assignment.weight <= EPSILON:
                continue
            name = group_names.get(assignment.group, "")
            if name in bone_names:
                weights.append(assignment.weight)
            else:
                unknown_groups.add(name)
        rows.append(weights)
    return rows, sorted(name for name in unknown_groups if name)


def _vertices_by_material(mesh, vertex_indices):
    requested = set(vertex_indices)
    material_vertices = {}
    for polygon in mesh.data.polygons:
        matched = requested.intersection(polygon.vertices)
        if not matched:
            continue
        material = (
            mesh.data.materials[polygon.material_index]
            if polygon.material_index < len(mesh.data.materials)
            else None
        )
        name = material.name if material else f"slot_{polygon.material_index}"
        material_vertices.setdefault(name, set()).update(matched)
    return {
        name: len(vertices)
        for name, vertices in sorted(material_vertices.items())
    }


def _mesh_record(mesh, armature, settings, issues):
    record = {
        "materials": [],
        "name": mesh.name,
        "polygons": len(mesh.data.polygons),
        "uv_layers": len(mesh.data.uv_layers),
        "vertices": len(mesh.data.vertices),
    }
    if not core.is_safe_name(mesh.name):
        issues.append(
            core.issue(
                "WARNING",
                "unsafe_object_name",
                f"Use a VT2-safe object name such as {core.safe_name(mesh.name)!r}.",
                mesh.name,
            )
        )
    if not _transform_is_identity(mesh):
        issues.append(
            core.issue(
                "WARNING",
                "unapplied_transform",
                "Object transforms are not applied; confirm the intended rest pose before export.",
                mesh.name,
            )
        )
    if not mesh.data.polygons:
        issues.append(core.issue("ERROR", "empty_mesh", "Mesh has no faces.", mesh.name))
    if not mesh.data.uv_layers.active:
        issues.append(
            core.issue("ERROR", "missing_uv", "Mesh needs an active UV map.", mesh.name)
        )
    if any(len(polygon.vertices) > 4 for polygon in mesh.data.polygons):
        issues.append(
            core.issue(
                "WARNING",
                "ngons",
                "Mesh contains n-gons; triangulate deliberately before final export.",
                mesh.name,
            )
        )

    for index, material in enumerate(mesh.data.materials):
        if material is None:
            issues.append(
                core.issue(
                    "ERROR",
                    "empty_material_slot",
                    f"Material slot {index} is empty.",
                    mesh.name,
                )
            )
            record["materials"].append(None)
            continue
        record["materials"].append(
            {
                "name": material.name,
                "surface": material.get("vt2_surface", "UNASSIGNED"),
            }
        )
        if not core.is_safe_name(material.name):
            issues.append(
                core.issue(
                    "WARNING",
                    "unsafe_material_name",
                    f"Material {material.name!r} should use letters, numbers, and underscores.",
                    mesh.name,
                )
            )
    if not mesh.data.materials:
        issues.append(
            core.issue(
                "WARNING",
                "missing_material",
                "Mesh has no material slots; VT2 still requires a compiled material.",
                mesh.name,
            )
        )

    modifiers = [modifier for modifier in mesh.modifiers if modifier.type == "ARMATURE"]
    if len(modifiers) != 1 or modifiers[0].object != armature:
        issues.append(
            core.issue(
                "ERROR",
                "armature_modifier",
                "Skinned meshes need exactly one Armature modifier targeting the exported rig.",
                mesh.name,
            )
        )

    bone_names = {bone.name for bone in armature.data.bones}
    rows, unknown_groups = _weight_rows(mesh, bone_names)
    weights = core.analyze_weight_rows(
        rows,
        maximum_influences=settings.maximum_influences,
    )
    record["weights"] = {
        "max_influences": weights["max_influences"],
        "not_normalized": len(weights["not_normalized"]),
        "over_limit": len(weights["over_limit"]),
        "unweighted": len(weights["unweighted"]),
    }
    if weights["unweighted"]:
        unweighted_by_material = _vertices_by_material(
            mesh, weights["unweighted"]
        )
        record["weights"]["unweighted_by_material"] = unweighted_by_material
        distribution = ", ".join(
            f"{name}={count}"
            for name, count in sorted(
                unweighted_by_material.items(),
                key=lambda item: (-item[1], item[0]),
            )[:4]
        )
        issues.append(
            core.issue(
                "ERROR",
                "unweighted_vertices",
                f"{len(weights['unweighted'])} vertices have no exported bone weight"
                + (f" ({distribution})." if distribution else "."),
                mesh.name,
            )
        )
    if weights["over_limit"]:
        issues.append(
            core.issue(
                "ERROR",
                "too_many_influences",
                f"{len(weights['over_limit'])} vertices exceed {settings.maximum_influences} bone weights.",
                mesh.name,
            )
        )
    if weights["not_normalized"]:
        issues.append(
            core.issue(
                "ERROR",
                "unnormalized_weights",
                f"{len(weights['not_normalized'])} vertices have bone weights that do not total 1.0.",
                mesh.name,
            )
        )
    if unknown_groups:
        issues.append(
            core.issue(
                "WARNING",
                "non_bone_groups",
                "Weighted groups not present on the rig will not deform in VT2: "
                + ", ".join(unknown_groups[:8]),
                mesh.name,
            )
        )
    return record


def validate(context, settings):
    objects = export_objects(context, settings.scope)
    meshes = sorted((obj for obj in objects if obj.type == "MESH"), key=lambda item: item.name)
    armatures = armatures_for_objects(objects)
    issues = []

    if not meshes:
        issues.append(core.issue("ERROR", "missing_mesh", "Export scope contains no mesh."))
    if len(armatures) != 1:
        issues.append(
            core.issue(
                "ERROR",
                "armature_count",
                f"Character export requires exactly one armature; found {len(armatures)}.",
            )
        )

    armature = armatures[0] if len(armatures) == 1 else None
    armature_record = None
    mesh_records = []
    if armature is not None:
        bones = list(armature.data.bones)
        roots = [bone for bone in bones if bone.parent is None]
        armature_record = {
            "bones": len(bones),
            "name": armature.name,
            "roots": [bone.name for bone in roots],
        }
        if not core.is_safe_name(armature.name):
            issues.append(
                core.issue(
                    "WARNING",
                    "unsafe_armature_name",
                    f"Use a VT2-safe rig name such as {core.safe_name(armature.name)!r}.",
                    armature.name,
                )
            )
        if not _transform_is_identity(armature):
            issues.append(
                core.issue(
                    "WARNING",
                    "unapplied_transform",
                    "Armature transforms are not applied; confirm axes and rest pose.",
                    armature.name,
                )
            )
        if len(roots) != 1:
            issues.append(
                core.issue(
                    "ERROR",
                    "skeleton_roots",
                    f"VT2 character skinning expects one skeleton root; found {len(roots)}.",
                    armature.name,
                )
            )
        if len(bones) > 255:
            issues.append(
                core.issue(
                    "ERROR",
                    "bone_limit",
                    f"Rig has {len(bones)} bones; the verified skin path supports at most 255.",
                    armature.name,
                )
            )
        if settings.bone_prefix:
            unexpected = [
                bone.name
                for bone in bones
                if bone.use_deform
                and not bone.name.startswith(settings.bone_prefix)
                and bone.name not in core.VT2_BONE_PREFIX_EXCEPTIONS
            ]
            if unexpected:
                issues.append(
                    core.issue(
                        "WARNING",
                        "bone_prefix",
                        f"{len(unexpected)} deform bones do not use prefix {settings.bone_prefix!r}.",
                        armature.name,
                    )
                )
        mesh_records = [
            _mesh_record(mesh, armature, settings, issues) for mesh in meshes
        ]

        if settings.export_mode in {"ANIMATION", "BOTH"}:
            action = settings.clip_action
            if action is None and armature.animation_data:
                action = armature.animation_data.action
            if action is None:
                issues.append(
                    core.issue(
                        "ERROR",
                        "missing_action",
                        "Active Clip export requires an action assigned to the armature.",
                        armature.name,
                    )
                )
            else:
                paths = action_data_paths(action)
                varying_paths = varying_action_data_paths(action)
                classified = core.classify_action_paths(
                    paths,
                    {bone.name for bone in bones},
                    {bone.name for bone in roots},
                )
                varying = core.classify_action_paths(
                    varying_paths,
                    {bone.name for bone in bones},
                    {bone.name for bone in roots},
                )
                armature_record["action"] = {
                    "channels": len(paths),
                    "frame_end": float(action.frame_range[1]),
                    "frame_start": float(action.frame_range[0]),
                    "name": action.name,
                    "varying_channels": len(varying_paths),
                }
                if classified["unknown_bones"]:
                    issues.append(
                        core.issue(
                            "ERROR",
                            "unknown_action_bones",
                            "Action targets missing bones: "
                            + ", ".join(classified["unknown_bones"][:8]),
                            armature.name,
                        )
                    )
                if varying["scale"]:
                    issues.append(
                        core.issue(
                            "WARNING",
                            "animated_scale",
                            f"Action changes scale on {len(varying['scale'])} bones; rotation-only clips are safest.",
                            armature.name,
                        )
                    )
                if varying["non_root_location"]:
                    issues.append(
                        core.issue(
                            "WARNING",
                            "non_root_translation",
                            f"Action translates {len(varying['non_root_location'])} non-root bones; verify Stingray playback.",
                            armature.name,
                        )
                    )
            if context.scene.render.fps != 30:
                issues.append(
                    core.issue(
                        "WARNING",
                        "animation_fps",
                        f"Scene is {context.scene.render.fps} FPS; the verified VT2 handoff uses 30 FPS.",
                    )
                )

    counts = {
        "errors": sum(item["severity"] == "ERROR" for item in issues),
        "warnings": sum(item["severity"] == "WARNING" for item in issues),
    }
    return {
        "addon_version": core.VERSION_STRING,
        "armature": armature_record,
        "generated_utc": datetime.now(timezone.utc).isoformat(),
        "issues": issues,
        "meshes": mesh_records,
        "scope": settings.scope,
        "summary": counts,
    }
