"""Import an extracted VT2 compiled unit into a Blender file headlessly."""

from __future__ import annotations

import os
import sys
import types
from pathlib import Path

import addon_utils
import bpy


def arguments_after_separator() -> list[str]:
    if "--" not in sys.argv:
        return []
    return sys.argv[sys.argv.index("--") + 1 :]


def main() -> None:
    arguments = arguments_after_separator()
    if len(arguments) not in (3, 4):
        raise SystemExit(
            "Usage: import_compiled_vt2_unit.py -- BITSQUID_TOOLS UNIT OUTPUT.blend [PYTHON_DEPS]"
        )

    tools_root, unit_path, output_path = map(
        lambda value: Path(value).resolve(), arguments[:3]
    )
    if not (tools_root / "bitsquid" / "__init__.py").is_file():
        raise RuntimeError(f"Bitsquid Blender Tools checkout is invalid: {tools_root}")
    if not unit_path.is_file() or unit_path.suffix.lower() != ".unit":
        raise RuntimeError(f"Compiled VT2 unit is invalid: {unit_path}")

    os.environ["IS_CI_PIPELINE"] = "1"
    if len(arguments) == 4:
        dependencies = Path(arguments[3]).resolve()
        if not dependencies.is_dir():
            raise RuntimeError(f"Python dependency directory is invalid: {dependencies}")
        sys.path.insert(0, str(dependencies))
    sys.path.insert(0, str(tools_root))

    original_addon_modules = addon_utils.modules
    module_stub = types.ModuleType("bitsquid")
    module_stub.bl_info = {"name": "Bitsquid Blender Tools"}

    def addon_modules_with_stub(*args, **kwargs):
        modules = list(original_addon_modules(*args, **kwargs))
        if not any(module.bl_info.get("name") == "Bitsquid Blender Tools" for module in modules):
            modules.append(module_stub)
        return modules

    addon_utils.modules = addon_modules_with_stub

    import bitsquid  # noqa: PLC0415

    bitsquid.register()
    bitsquid.utils.get_extract_dir_vt2 = lambda: str(unit_path.parent)
    bitsquid.utils.is_level_editor_enabled = lambda: False
    bitsquid.resource_manager.get_extract_dir_vt2 = lambda: str(unit_path.parent)
    bitsquid.is_level_editor_enabled = lambda: False
    bpy.context.scene.bitsquid_import_settings.import_materials = False
    bpy.context.scene.bitsquid_import_settings.import_textures = False
    bpy.ops.object.select_all(action="SELECT")
    bpy.ops.object.delete(use_global=False)

    result = bpy.ops.import_scene.unit_vt2(filepath=str(unit_path))
    if result != {"FINISHED"}:
        raise RuntimeError(f"VT2 unit import failed: {result}")

    output_path.parent.mkdir(parents=True, exist_ok=True)
    bpy.ops.wm.save_as_mainfile(filepath=str(output_path), check_existing=False)
    meshes = [obj for obj in bpy.context.scene.objects if obj.type == "MESH"]
    armatures = [obj for obj in bpy.context.scene.objects if obj.type == "ARMATURE"]
    print(
        "PUSFUME_COMPILED_UNIT_IMPORT="
        f"unit={unit_path} output={output_path} meshes={len(meshes)} "
        f"armatures={len(armatures)}"
    )


if __name__ == "__main__":
    main()
