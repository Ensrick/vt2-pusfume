"""Validate a candidate first-person donor unit against a rig dump, no Blender.

Given a compiled VT2 donor `.unit` and the JSON produced by
`dump_human_rig.py` (a line starting `PUSFUME_HUMAN_RIG_DUMP=` or the bare
object), report whether the donor can serve as the rebind target for
`prepare_pusfume_1p_blend.py` / `prepare_pusfume_1p_bsi.py`:

  * every REQUIRED_DONOR_BONE is present (hard fail if not),
  * how many authored bones map vs fall through to parent-relative resolution,
  * orphan vertex groups (a vgroup with no matching armature bone, e.g. a stray
    j_lefthandpinky4) that the build's orphan guard will only drop if their
    weight is negligible, and
  * the single-arms material contract expected by the BSI path.

Usage:
    python tools/validate_first_person_donor.py DONOR.unit RIG_DUMP.json
Exit status is non-zero when a hard requirement fails.
"""

from __future__ import annotations

import json
import os
import sys

TOOLS_DIR = os.path.dirname(os.path.abspath(__file__))
if TOOLS_DIR not in sys.path:
    sys.path.insert(0, TOOLS_DIR)

from stingray_unit_scene import read_scene_graph, short_hash  # noqa: E402

# Kept in sync with prepare_pusfume_1p_blend.py.
REQUIRED_DONOR_BONES = {
    "j_leftarm",
    "j_leftforearm",
    "j_lefthand",
    "j_rightarm",
    "j_rightforearm",
    "j_righthand",
}
REQUIRED_GROUPS = {"j_leftarm", "j_rightarm", "j_lefthand", "j_righthand"}
FIRST_PERSON_MATERIAL_CONTRACT = ["p_main"]


def parse_rig_dump(text):
    """Accept either the PUSFUME_HUMAN_RIG_DUMP= line or a bare JSON object."""
    marker = "PUSFUME_HUMAN_RIG_DUMP="
    if marker in text:
        text = text.split(marker, 1)[1]
    return json.loads(text.strip())


def select_arms_mesh(meshes):
    """Mirror find_arms_and_rig: the one armature-bound mesh with the arm groups."""
    candidates = [
        mesh
        for mesh in meshes
        if mesh.get("armature_modifier")
        and REQUIRED_GROUPS.issubset(set(mesh.get("vgroups", [])))
    ]
    if len(candidates) != 1:
        return None, [mesh.get("name") for mesh in candidates]
    return candidates[0], None


def analyze(donor_node_hashes, bones, vgroups, materials):
    """Pure core: report donor coverage, orphan groups and material contract."""
    bone_set = set(bones)
    mapped = [bone for bone in bones if short_hash(bone) in donor_node_hashes]
    unmapped = [bone for bone in bones if short_hash(bone) not in donor_node_hashes]
    missing_required = sorted(
        bone for bone in REQUIRED_DONOR_BONES if short_hash(bone) not in donor_node_hashes
    )
    orphan_vgroups = sorted(group for group in vgroups if group not in bone_set)

    errors = []
    if missing_required:
        errors.append("donor is missing required bones: %s" % missing_required)
    if materials and materials != FIRST_PERSON_MATERIAL_CONTRACT:
        errors.append(
            "arms material is %s; the BSI path requires %s"
            % (materials, FIRST_PERSON_MATERIAL_CONTRACT)
        )

    warnings = []
    if orphan_vgroups:
        warnings.append(
            "orphan vertex groups with no matching bone (build drops them only if "
            "weight <= 0.05): %s" % orphan_vgroups
        )

    return {
        "bones": len(bones),
        "errors": errors,
        "mapped": len(mapped),
        "mapped_bones": mapped,
        "materials": materials,
        "missing_required": missing_required,
        "orphan_vgroups": orphan_vgroups,
        "ok": not errors,
        "unmapped": len(unmapped),
        "warnings": warnings,
    }


def main():
    if len(sys.argv) != 3:
        raise SystemExit(
            "Usage: validate_first_person_donor.py DONOR.unit RIG_DUMP.json"
        )
    donor_path, dump_path = sys.argv[1], sys.argv[2]

    graph = read_scene_graph(donor_path)
    donor_hashes = {node["name_hash"] for node in graph["nodes"]}

    with open(dump_path, "r", encoding="utf-8") as dump_file:
        dump = parse_rig_dump(dump_file.read())

    armatures = dump.get("armatures", {})
    if len(armatures) != 1:
        raise SystemExit("Expected exactly one armature in the rig dump; found %d" % len(armatures))
    bones = next(iter(armatures.values()))["bones"]

    arms_mesh, ambiguous = select_arms_mesh(dump.get("meshes", []))
    if arms_mesh is None:
        raise SystemExit(
            "Could not identify a single armature-bound arms mesh with the "
            "required groups; candidates: %s" % ambiguous
        )

    result = analyze(
        donor_hashes,
        bones,
        arms_mesh.get("vgroups", []),
        arms_mesh.get("materials", []),
    )
    result["donor_nodes"] = len(graph["nodes"])
    result["arms_mesh"] = arms_mesh.get("name")

    print("PUSFUME_1P_DONOR_VALIDATION=" + json.dumps(result, sort_keys=True))
    for warning in result["warnings"]:
        print("WARNING: " + warning)
    for error in result["errors"]:
        print("ERROR: " + error)

    raise SystemExit(0 if result["ok"] else 1)


if __name__ == "__main__":
    main()
