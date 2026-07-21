"""Compare compiled Pusfume 1P rest transforms with the compiled VT2 donor."""

from __future__ import annotations

import json
import os
import sys

try:
    from .stingray_unit_scene import read_scene_graph, short_hash
except ImportError:
    from stingray_unit_scene import read_scene_graph, short_hash


TOLERANCE = 0.001
LEGACY_MINIMUM_SHARED_NODES = 53
HUMAN_MINIMUM_SHARED_NODES = 52
SKAVEN_MINIMUM_SHARED_NODES = 53
NAME_OVERRIDES = {"j_spine1": "j_spine2"}


def matrix_error(first, second):
    return max(abs(left - right) for left, right in zip(first, second))


def select_rest_contract(custom_hashes, donor_hashes):
    custom_spine1 = short_hash("j_spine1") in custom_hashes
    custom_spine2 = short_hash("j_spine2") in custom_hashes
    donor_spine1 = short_hash("j_spine1") in donor_hashes
    donor_spine2 = short_hash("j_spine2") in donor_hashes

    if custom_spine1 and donor_spine1:
        return "skaven-same-name", SKAVEN_MINIMUM_SHARED_NODES, {}
    if custom_spine1 and donor_spine2:
        return "legacy-spine-override", LEGACY_MINIMUM_SHARED_NODES, NAME_OVERRIDES
    if custom_spine2 and donor_spine2:
        return "human-same-name", HUMAN_MINIMUM_SHARED_NODES, {}

    raise RuntimeError(
        "Compiled first-person unit matches none of the Skaven same-name, "
        "legacy spine override, or human same-name donor contracts"
    )


def compare_compiled_rest(custom_path, donor_path):
    custom = read_scene_graph(custom_path)
    donor = read_scene_graph(donor_path)
    custom_by_hash = {node["name_hash"]: node for node in custom["nodes"]}
    donor_by_hash = {node["name_hash"]: node for node in donor["nodes"]}
    shared_hashes = sorted(set(custom_by_hash).intersection(donor_by_hash))
    contract, minimum_shared_nodes, name_overrides = select_rest_contract(
        custom_by_hash, donor_by_hash
    )

    comparisons = [
        {
            "target_hash": name_hash,
            "source_hash": name_hash,
            "error": matrix_error(
                custom_by_hash[name_hash]["world"],
                donor_by_hash[name_hash]["world"],
            ),
        }
        for name_hash in shared_hashes
    ]
    for target_name, source_name in name_overrides.items():
        target_hash = short_hash(target_name)
        source_hash = short_hash(source_name)
        if target_hash not in custom_by_hash or source_hash not in donor_by_hash:
            raise RuntimeError(
                f"Missing compiled override pair {source_name}->{target_name}"
            )
        comparisons.append(
            {
                "target_hash": target_hash,
                "source_hash": source_hash,
                "error": matrix_error(
                    custom_by_hash[target_hash]["world"],
                    donor_by_hash[source_hash]["world"],
                ),
            }
        )

    if len(shared_hashes) < minimum_shared_nodes:
        raise RuntimeError(
            f"Only {len(shared_hashes)} compiled nodes are shared with the donor; "
            f"expected at least {minimum_shared_nodes} for {contract}"
        )

    comparisons.sort(key=lambda item: item["error"], reverse=True)
    maximum_error = comparisons[0]["error"] if comparisons else float("inf")
    result = {
        "compared": len(comparisons),
        "contract": contract,
        "custom_nodes": len(custom_by_hash),
        "donor_nodes": len(donor_by_hash),
        "maximum_error": maximum_error,
        "shared_nodes": len(shared_hashes),
        "tolerance": TOLERANCE,
        "worst": comparisons[:5],
    }
    if maximum_error > TOLERANCE:
        raise RuntimeError(
            "Compiled first-person rest skeleton diverges from the VT2 donor: "
            + json.dumps(result, sort_keys=True)
        )
    return result


def main(arguments):
    if len(arguments) != 2:
        raise SystemExit(
            "Usage: validate_compiled_1p_rest.py CUSTOM.unit DONOR.unit"
        )
    custom_path, donor_path = (os.path.abspath(value) for value in arguments)
    result = compare_compiled_rest(custom_path, donor_path)
    print("PUSFUME_1P_COMPILED_REST=" + json.dumps(result, sort_keys=True))


if __name__ == "__main__":
    main(sys.argv[1:])
