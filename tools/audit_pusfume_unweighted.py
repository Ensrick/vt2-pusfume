"""Report connected unweighted regions and nearby valid weights in a Blender scene."""

from __future__ import annotations

import json
import os
import sys
from collections import Counter

import bpy
from mathutils.kdtree import KDTree


def vertex_materials(mesh):
    result = [set() for _vertex in mesh.data.vertices]
    names = [material.name if material else "" for material in mesh.data.materials]
    for polygon in mesh.data.polygons:
        name = names[polygon.material_index]
        for vertex_index in polygon.vertices:
            result[vertex_index].add(name)
    return result


def connected_regions(mesh, requested):
    requested = set(requested)
    adjacency = {index: set() for index in requested}
    for edge in mesh.data.edges:
        first, second = edge.vertices
        if first in requested and second in requested:
            adjacency[first].add(second)
            adjacency[second].add(first)

    regions = []
    while requested:
        seed = requested.pop()
        pending = [seed]
        region = [seed]
        while pending:
            current = pending.pop()
            for neighbor in adjacency[current]:
                if neighbor in requested:
                    requested.remove(neighbor)
                    pending.append(neighbor)
                    region.append(neighbor)
        regions.append(region)
    return sorted(regions, key=len, reverse=True)


def main(arguments):
    if len(arguments) != 1:
        raise SystemExit("Usage: audit_pusfume_unweighted.py INPUT.blend")
    bpy.ops.wm.open_mainfile(filepath=os.path.abspath(arguments[0]), load_ui=False)
    candidates = [
        obj
        for obj in bpy.context.scene.objects
        if obj.type == "MESH" and obj.name == "p_mainbody"
    ]
    if len(candidates) != 1:
        raise RuntimeError(f"Expected one p_mainbody mesh, found {len(candidates)}")
    mesh = candidates[0]
    group_names = {group.index: group.name for group in mesh.vertex_groups}
    weighted = []
    unweighted = []
    for vertex in mesh.data.vertices:
        assignments = [item for item in vertex.groups if item.weight > 0.000001]
        (weighted if assignments else unweighted).append(vertex.index)

    tree = KDTree(len(weighted))
    for vertex_index in weighted:
        tree.insert(mesh.data.vertices[vertex_index].co, vertex_index)
    tree.balance()
    materials = vertex_materials(mesh)
    regions = []
    for region in connected_regions(mesh, unweighted):
        nearest_groups = Counter()
        nearest_distances = []
        for vertex_index in region:
            nearest = tree.find_n(mesh.data.vertices[vertex_index].co, 4)
            for _co, weighted_index, distance in nearest:
                nearest_distances.append(distance)
                for assignment in mesh.data.vertices[weighted_index].groups:
                    if assignment.weight > 0.000001:
                        nearest_groups[group_names[assignment.group]] += assignment.weight
        coordinates = [mesh.data.vertices[index].co for index in region]
        regions.append(
            {
                "bounds_max": [max(value[axis] for value in coordinates) for axis in range(3)],
                "bounds_min": [min(value[axis] for value in coordinates) for axis in range(3)],
                "materials": sorted({name for index in region for name in materials[index]}),
                "nearest_distance_max": max(nearest_distances, default=0),
                "nearest_distance_min": min(nearest_distances, default=0),
                "nearest_groups": nearest_groups.most_common(8),
                "vertices": len(region),
            }
        )
    print(
        "PUSFUME_UNWEIGHTED_AUDIT="
        + json.dumps(
            {
                "mesh": mesh.name,
                "regions": regions,
                "unweighted": len(unweighted),
                "weighted": len(weighted),
            },
            sort_keys=True,
        )
    )


if __name__ == "__main__":
    separator = sys.argv.index("--") if "--" in sys.argv else len(sys.argv)
    main(sys.argv[separator + 1 :])
