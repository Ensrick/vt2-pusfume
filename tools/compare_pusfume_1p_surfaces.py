"""Compare a custom first-person skin with an imported native donor mesh.

Run through Blender 5.2 after importing the compiled donor unit to a .blend:
    blender --background --factory-startup --disable-autoexec \
        --python tools/compare_pusfume_1p_surfaces.py -- \
        CUSTOM.blend DONOR.blend

The comparison is topology-independent. Each vertex-group centroid is weighted
by its skin influence, so the report identifies surface displacement around
matching bones without assuming that the two meshes share vertices.
"""

from __future__ import annotations

import json
import math
import os
import sys

import bpy
from mathutils import Vector


GROUPS = (
    "j_leftshoulder",
    "j_leftarm",
    "j_leftforearm",
    "j_lefthand",
    "j_rightshoulder",
    "j_rightarm",
    "j_rightforearm",
    "j_righthand",
)


def arguments_after_separator():
    if "--" not in sys.argv:
        return []
    return sys.argv[sys.argv.index("--") + 1 :]


def vector_list(value):
    return [round(component, 6) for component in value]


def find_weighted_mesh():
    candidates = [
        obj
        for obj in bpy.context.scene.objects
        if obj.type == "MESH" and obj.vertex_groups
    ]
    if not candidates:
        raise RuntimeError(
            "Expected at least one weighted mesh, found %d: %s"
            % (len(candidates), [obj.name for obj in candidates])
        )

    # Extracted VT2 units can separate skin, fur, and accessory surfaces.
    # Prefer broad arm-group coverage, then the densest matching surface.
    def arm_surface_rank(obj):
        names = {group.name for group in obj.vertex_groups}
        return (len(names.intersection(GROUPS)), len(obj.data.vertices))

    selected = max(candidates, key=arm_surface_rank)
    coverage, _ = arm_surface_rank(selected)
    if coverage < 6:
        raise RuntimeError(
            "No weighted mesh covers both VT2 arms; candidates: %s"
            % [(obj.name, arm_surface_rank(obj)) for obj in candidates]
        )

    return selected


def mesh_bounds(mesh):
    points = [mesh.matrix_world @ vertex.co for vertex in mesh.data.vertices]
    minimum = Vector((math.inf, math.inf, math.inf))
    maximum = Vector((-math.inf, -math.inf, -math.inf))
    for point in points:
        for axis in range(3):
            minimum[axis] = min(minimum[axis], point[axis])
            maximum[axis] = max(maximum[axis], point[axis])
    return {
        "center": vector_list((minimum + maximum) * 0.5),
        "maximum": vector_list(maximum),
        "minimum": vector_list(minimum),
        "size": vector_list(maximum - minimum),
    }


def weighted_group_centroids(mesh):
    group_names = {group.index: group.name for group in mesh.vertex_groups}
    weighted_sums = {name: Vector((0, 0, 0)) for name in GROUPS}
    weight_totals = {name: 0.0 for name in GROUPS}
    vertex_counts = {name: 0 for name in GROUPS}

    for vertex in mesh.data.vertices:
        world_position = mesh.matrix_world @ vertex.co
        for assignment in vertex.groups:
            name = group_names.get(assignment.group)
            if name not in weighted_sums or assignment.weight <= 0:
                continue
            weighted_sums[name] += world_position * assignment.weight
            weight_totals[name] += assignment.weight
            vertex_counts[name] += 1

    result = {}
    for name in GROUPS:
        total = weight_totals[name]
        if total > 0:
            result[name] = {
                "centroid": vector_list(weighted_sums[name] / total),
                "vertices": vertex_counts[name],
                "weight": round(total, 6),
            }
    return result


def read_surface(path):
    bpy.ops.wm.open_mainfile(filepath=path, load_ui=False)
    mesh = find_weighted_mesh()
    return {
        "bounds": mesh_bounds(mesh),
        "groups": weighted_group_centroids(mesh),
        "mesh": mesh.name,
        "vertices": len(mesh.data.vertices),
    }


def main():
    arguments = arguments_after_separator()
    if len(arguments) != 2:
        raise SystemExit(
            "Usage: compare_pusfume_1p_surfaces.py -- CUSTOM.blend DONOR.blend"
        )
    custom_path, donor_path = (os.path.abspath(value) for value in arguments)
    custom = read_surface(custom_path)
    donor = read_surface(donor_path)

    deltas = {}
    for name in GROUPS:
        if name not in custom["groups"] or name not in donor["groups"]:
            continue
        custom_center = Vector(custom["groups"][name]["centroid"])
        donor_center = Vector(donor["groups"][name]["centroid"])
        delta = donor_center - custom_center
        deltas[name] = {
            "custom_to_donor": vector_list(delta),
            "distance": round(delta.length, 6),
        }

    print(
        "PUSFUME_1P_SURFACE_COMPARISON="
        + json.dumps(
            {
                "custom": custom,
                "custom_path": custom_path,
                "deltas": deltas,
                "donor": donor,
                "donor_path": donor_path,
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    main()
