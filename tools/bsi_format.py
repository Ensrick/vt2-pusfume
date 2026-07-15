"""Deterministic SJSON and compressed BSI helpers.

Bitsquid's source scene format is SJSON. Compressed files use a small `bsiz`
wrapper: four magic bytes, a little-endian raw size, then a zlib stream.
"""

from __future__ import annotations

import json
import math
import re
import struct
import zlib
from collections.abc import Mapping, Sequence
from pathlib import Path


_BARE_KEY = re.compile(r"^[A-Za-z_][A-Za-z0-9_]*$")


def _format_key(value: str) -> str:
    return value if _BARE_KEY.fullmatch(value) else json.dumps(value, ensure_ascii=True)


def _format_float(value: float) -> str:
    if not math.isfinite(value):
        raise ValueError("BSI does not support non-finite floating-point values")
    if value == 0:
        return "0"
    return format(value, ".9g")


def _render(value, level: int) -> str:
    indent = "\t" * level
    child_indent = "\t" * (level + 1)

    if isinstance(value, Mapping):
        if not value:
            return "{}"
        lines = ["{"]
        for key, child in value.items():
            if not isinstance(key, str):
                raise TypeError("BSI object keys must be strings")
            lines.append(f"{child_indent}{_format_key(key)} = {_render(child, level + 1)}")
        lines.append(f"{indent}}}")
        return "\n".join(lines)

    if isinstance(value, Sequence) and not isinstance(value, (str, bytes, bytearray)):
        if not value:
            return "[]"
        rendered = [_render(child, level + 1) for child in value]
        if all("\n" not in child for child in rendered):
            return "[ " + " ".join(rendered) + " ]"
        lines = ["["]
        lines.extend(f"{child_indent}{child}" for child in rendered)
        lines.append(f"{indent}]")
        return "\n".join(lines)

    if isinstance(value, str):
        return json.dumps(value, ensure_ascii=True)
    if isinstance(value, bool):
        return "true" if value else "false"
    if value is None:
        return "null"
    if isinstance(value, int):
        return str(value)
    if isinstance(value, float):
        return _format_float(value)
    raise TypeError(f"Unsupported BSI value: {type(value).__name__}")


def dumps(document: Mapping[str, object]) -> str:
    """Render a top-level BSI document using SDK-compatible SJSON syntax."""
    if not isinstance(document, Mapping):
        raise TypeError("A BSI document must be a mapping")

    lines = []
    for key, value in document.items():
        if not isinstance(key, str):
            raise TypeError("BSI object keys must be strings")
        lines.append(f"{_format_key(key)} = {_render(value, 0)}")
    return "\n".join(lines) + "\n"


def encode_bsiz(raw: bytes, compression_level: int = 9) -> bytes:
    """Wrap raw SJSON bytes in the compressed BSI container."""
    return b"bsiz" + struct.pack("<I", len(raw)) + zlib.compress(raw, compression_level)


def decode_bsiz(payload: bytes) -> bytes:
    """Decode a BSI payload, accepting both plain SJSON and `bsiz` input."""
    if not payload.startswith(b"bsiz"):
        return payload
    if len(payload) < 8:
        raise ValueError("Truncated bsiz header")

    expected_size = struct.unpack("<I", payload[4:8])[0]
    raw = zlib.decompress(payload[8:])
    if len(raw) != expected_size:
        raise ValueError(f"bsiz size mismatch: expected {expected_size}, got {len(raw)}")
    return raw


def write(path: str | Path, document: Mapping[str, object], compress: bool = False) -> None:
    """Write a deterministic UTF-8 BSI file."""
    destination = Path(path)
    destination.parent.mkdir(parents=True, exist_ok=True)
    raw = dumps(document).encode("utf-8")
    destination.write_bytes(encode_bsiz(raw) if compress else raw)
