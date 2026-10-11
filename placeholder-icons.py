#!/usr/bin/env python3
"""Write placeholder app icons into <project>/assets/app-icon, so a new project builds and packages
before real artwork exists. Standard library only.

    python3 placeholder-icons.py <project-dir> <app-id> <crate-name> [#RRGGBB]

Writes icon-256.png (embedded in the binary), <crate>.ico (Windows), <crate>.icns (macOS) and
hicolor/<size>/apps/<app-id>.png plus hicolor/scalable/apps/<app-id>.svg (Linux, FreeBSD, Flatpak).
Replace them with real artwork before the first release.
"""

import struct
import sys
import zlib
from pathlib import Path


def png(size: int, rgb: tuple[int, int, int]) -> bytes:
    """A rounded square in `rgb` on a transparent background, RGBA, 8 bits per channel."""
    r = size * 0.2
    rows = []
    for y in range(size):
        row = bytearray([0])  # filter: none
        for x in range(size):
            # Distance outside the rounded rectangle's inner box, for the corner arcs.
            dx = max(r - (x + 0.5), (x + 0.5) - (size - r), 0)
            dy = max(r - (y + 0.5), (y + 0.5) - (size - r), 0)
            inside = dx * dx + dy * dy <= r * r
            row += bytes(rgb) + bytes([255 if inside else 0])
        rows.append(bytes(row))
    raw = b"".join(rows)

    def chunk(kind: bytes, data: bytes) -> bytes:
        return struct.pack(">I", len(data)) + kind + data + struct.pack(">I", zlib.crc32(kind + data) & 0xFFFFFFFF)

    ihdr = struct.pack(">IIBBBBB", size, size, 8, 6, 0, 0, 0)
    return b"\x89PNG\r\n\x1a\n" + chunk(b"IHDR", ihdr) + chunk(b"IDAT", zlib.compress(raw, 9)) + chunk(b"IEND", b"")


def ico(images: dict[int, bytes]) -> bytes:
    """ICO with PNG-compressed entries (Windows Vista and later)."""
    sizes = sorted(images)
    header = struct.pack("<HHH", 0, 1, len(sizes))
    offset = 6 + 16 * len(sizes)
    entries, data = b"", b""
    for s in sizes:
        img = images[s]
        dim = 0 if s >= 256 else s
        entries += struct.pack("<BBBBHHII", dim, dim, 0, 0, 1, 32, len(img), offset + len(data))
        data += img
    return header + entries + data


def icns(images: dict[int, bytes]) -> bytes:
    """ICNS with PNG entries: ic07 (128), ic08 (256), ic09 (512), ic10 (1024 = 512@2x)."""
    types = {128: b"ic07", 256: b"ic08", 512: b"ic09", 1024: b"ic10"}
    body = b"".join(types[s] + struct.pack(">I", 8 + len(images[s])) + images[s] for s in sorted(images) if s in types)
    return b"icns" + struct.pack(">I", 8 + len(body)) + body


def main() -> None:
    if len(sys.argv) not in (4, 5):
        sys.exit(__doc__)
    root, app_id, crate = Path(sys.argv[1]), sys.argv[2], sys.argv[3]
    color = sys.argv[4] if len(sys.argv) == 5 else "#3b6fd8"
    rgb = (int(color[1:3], 16), int(color[3:5], 16), int(color[5:7], 16))
    out = root / "assets" / "app-icon"
    out.mkdir(parents=True, exist_ok=True)

    cache: dict[int, bytes] = {}

    def get(size: int) -> bytes:
        if size not in cache:
            cache[size] = png(size, rgb)
        return cache[size]

    (out / "icon-256.png").write_bytes(get(256))
    (out / f"{crate}.ico").write_bytes(ico({s: get(s) for s in (16, 24, 32, 48, 64, 128, 256)}))
    (out / f"{crate}.icns").write_bytes(icns({s: get(s) for s in (128, 256, 512, 1024)}))
    for s in (16, 32, 48, 64, 128, 256, 512):
        d = out / "hicolor" / f"{s}x{s}" / "apps"
        d.mkdir(parents=True, exist_ok=True)
        (d / f"{app_id}.png").write_bytes(get(s))
    svg = out / "hicolor" / "scalable" / "apps"
    svg.mkdir(parents=True, exist_ok=True)
    (svg / f"{app_id}.svg").write_text(
        f'<svg xmlns="http://www.w3.org/2000/svg" viewBox="0 0 256 256"><rect width="256" height="256" rx="51" fill="{color}"/></svg>\n'
    )
    print(f"placeholder icons written to {out}")


if __name__ == "__main__":
    main()
