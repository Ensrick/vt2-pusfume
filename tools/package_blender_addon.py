"""Build a deterministic Blender extension ZIP for VT2 Content Tools."""

from __future__ import annotations

import argparse
import json
from pathlib import Path
import tomllib
import zipfile


REQUIRED_FILES = {
    "__init__.py",
    "blender_manifest.toml",
    "core.py",
    "operators.py",
    "properties.py",
    "README.md",
    "ui.py",
    "validation.py",
}


def source_files(source_root):
    files = {
        path.relative_to(source_root).as_posix(): path
        for path in source_root.rglob("*")
        if path.is_file() and "__pycache__" not in path.parts
    }
    missing = sorted(REQUIRED_FILES - set(files))
    if missing:
        raise RuntimeError(f"Blender add-on source is incomplete: {missing}")
    return files


def read_manifest(source_root):
    with (source_root / "blender_manifest.toml").open("rb") as handle:
        manifest = tomllib.load(handle)
    if manifest.get("id") != "vt2_content_tools":
        raise RuntimeError(f"Unexpected Blender extension id: {manifest.get('id')!r}")
    if manifest.get("blender_version_min") != "4.3.0":
        raise RuntimeError("Blender extension minimum-version contract changed")
    return manifest


def build_package(source_root, output_path=None):
    source_root = Path(source_root).resolve()
    manifest = read_manifest(source_root)
    files = source_files(source_root)
    if output_path is None:
        output_path = (
            source_root.parents[1]
            / ".build"
            / "dist"
            / f"{manifest['id']}-{manifest['version']}.zip"
        )
    output_path = Path(output_path).resolve()
    output_path.parent.mkdir(parents=True, exist_ok=True)

    with zipfile.ZipFile(
        output_path,
        "w",
        compression=zipfile.ZIP_DEFLATED,
        compresslevel=9,
    ) as archive:
        for relative, path in sorted(files.items()):
            info = zipfile.ZipInfo(relative, date_time=(1980, 1, 1, 0, 0, 0))
            info.compress_type = zipfile.ZIP_DEFLATED
            info.external_attr = 0o100644 << 16
            archive.writestr(info, path.read_bytes(), compresslevel=9)

    return {
        "bytes": output_path.stat().st_size,
        "files": len(files),
        "id": manifest["id"],
        "output": str(output_path),
        "version": manifest["version"],
    }


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--source",
        default="blender_addon/vt2_content_tools",
        help="Blender extension source directory",
    )
    parser.add_argument("--output", help="Destination ZIP path")
    arguments = parser.parse_args()
    print("VT2_ADDON_PACKAGE=" + json.dumps(build_package(arguments.source, arguments.output)))


if __name__ == "__main__":
    main()
