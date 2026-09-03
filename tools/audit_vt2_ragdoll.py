#!/usr/bin/env python3
"""Audit compiled VT2 unit and state-machine ragdoll resources.

Run this with Blender's Python because the Bitsquid parsers depend on mathutils.
The command is read-only and writes JSON to stdout or to --output.
"""

from __future__ import annotations

import argparse
import csv
import json
import sys
import types
from enum import Enum
from pathlib import Path
from typing import Any


def _arguments(argv: list[str]) -> argparse.Namespace:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("unit", type=Path, help="Compiled .unit resource")
    parser.add_argument(
        "--bitsquid-tools",
        type=Path,
        required=True,
        help="Checkout containing the bitsquid Python package",
    )
    parser.add_argument(
        "--state-machine",
        type=Path,
        help="Optional compiled .state_machine resource",
    )
    parser.add_argument(
        "--dictionary",
        type=Path,
        help="Optional VT2 Bundle Unpacker dictionary.csv",
    )
    parser.add_argument("--output", type=Path, help="Write JSON to this path")
    return parser.parse_args(argv)


def _load_dictionary(path: Path | None) -> dict[int, str]:
    if path is None or not path.is_file():
        return {}

    result: dict[int, str] = {}
    with path.open(encoding="utf-8", newline="") as stream:
        for row in csv.DictReader(stream):
            value = row.get("value", "")
            for column in ("short", "long"):
                encoded = row.get(column, "")
                if value and encoded:
                    result.setdefault(int(encoded, 16), value)
    return result


def _value(value: Any, names: dict[int, str]) -> Any:
    if isinstance(value, Enum):
        return value.name
    if hasattr(value, "ID"):
        identifier = int(value.ID)
        width = 8 if identifier <= 0xFFFFFFFF else 16
        return {
            "hash": f"{identifier:0{width}X}",
            "name": names.get(identifier),
        }
    if hasattr(value, "to_list"):
        return value.to_list()
    if type(value).__module__ == "mathutils":
        return [_value(item, names) for item in value]
    if isinstance(value, bytes):
        return {
            "hex": value.hex().upper(),
            "ascii": "".join(chr(byte) if 32 <= byte < 127 else "." for byte in value),
        }
    if isinstance(value, dict):
        return {str(key): _value(item, names) for key, item in value.items()}
    if isinstance(value, (list, tuple)):
        return [_value(item, names) for item in value]
    if not isinstance(value, (str, int, float, bool, type(None))) and hasattr(
        value, "__iter__"
    ):
        return [_value(item, names) for item in value]
    if hasattr(value, "__dict__"):
        return {
            key: _value(item, names)
            for key, item in vars(value).items()
            if not key.startswith("_")
        }
    return value


def _json_fallback(value: Any) -> Any:
    try:
        return [list(item) if hasattr(item, "__iter__") else item for item in value]
    except TypeError:
        return repr(value)


def _main(argv: list[str]) -> int:
    args = _arguments(argv)
    if not args.unit.is_file():
        raise FileNotFoundError(args.unit)
    if not args.bitsquid_tools.is_dir():
        raise FileNotFoundError(args.bitsquid_tools)

    dictionary = args.dictionary
    if dictionary is None:
        dictionary = args.bitsquid_tools / "bitsquid" / "unpacking" / "dictionary.csv"
    names = _load_dictionary(dictionary)

    tools_root = args.bitsquid_tools.resolve()
    sys.path.insert(0, str(tools_root))
    # Loading a submodule normally executes the add-on's UI/server bootstrap,
    # which is irrelevant to a read-only parser and requires optional packages.
    package = types.ModuleType("bitsquid")
    package.__path__ = [str(tools_root / "bitsquid")]
    package.__package__ = "bitsquid"
    sys.modules["bitsquid"] = package
    import_base = types.ModuleType("bitsquid.import_base")
    import_base.Parser = object
    sys.modules["bitsquid.import_base"] = import_base
    unit_package = types.ModuleType("bitsquid.unit")
    unit_package.__path__ = [str(tools_root / "bitsquid" / "unit")]
    sys.modules["bitsquid.unit"] = unit_package
    vt2_package = types.ModuleType("bitsquid.unit.vt2")
    vt2_package.__path__ = [str(tools_root / "bitsquid" / "unit" / "vt2")]
    sys.modules["bitsquid.unit.vt2"] = vt2_package
    from bitsquid.deserializing import Cursor  # pylint: disable=import-outside-toplevel
    from bitsquid.stingray.animation_state_machine_resource import (  # pylint: disable=import-outside-toplevel
        AnimationStateMachineResourceVT2,
    )
    from bitsquid.unit.vt2.parse_compiled import UnitResourceVT2  # pylint: disable=import-outside-toplevel

    unit = UnitResourceVT2(Cursor.from_bytes(args.unit.read_bytes()))
    result: dict[str, Any] = {
        "unit": str(args.unit.resolve()),
        "summary": {
            "scene_nodes": len(unit.scene_graph.nodes),
            "actors": len(unit.actors),
            "joints": len(unit.joints),
            "meshes": len(unit.meshes),
            "physics_scene_bytes": len(unit.physics_scene_data),
            "physics_scene_64bit_bytes": len(unit.physics_scene_data_64bit),
        },
        "animation_state_machine_reference": _value(unit.animation_state_machine, names),
        "skeleton": _value(unit.skeleton_name, names),
        "actors": _value(unit.actors, names),
        "joints": _value(unit.joints, names),
    }

    if args.state_machine:
        if not args.state_machine.is_file():
            raise FileNotFoundError(args.state_machine)
        machine = AnimationStateMachineResourceVT2(
            Cursor.from_bytes(args.state_machine.read_bytes())
        )
        result["state_machine"] = {
            "path": str(args.state_machine.resolve()),
            "events": _value(machine.event_names, names),
            "constraint_bytes": len(machine.constraints),
            "ragdolls": _value(machine.ragdolls, names),
            "ragdoll_states": [
                {
                    "layer": layer_index,
                    "name": _value(state.name, names),
                    "ragdoll_index": state.ragdoll,
                }
                for layer_index, layer in enumerate(machine.layers)
                for state in layer.states
                if state.state_type.name == "RAGDOLL_STATE"
            ],
        }

    rendered = json.dumps(result, indent=2, sort_keys=True, default=_json_fallback)
    if args.output:
        args.output.parent.mkdir(parents=True, exist_ok=True)
        args.output.write_text(rendered + "\n", encoding="utf-8")
    else:
        print(rendered)
    return 0


if __name__ == "__main__":
    arguments = sys.argv[sys.argv.index("--") + 1 :] if "--" in sys.argv else sys.argv[1:]
    raise SystemExit(_main(arguments))
