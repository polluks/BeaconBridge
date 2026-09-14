#!/usr/bin/env python3
"""Generate a classic Amiga DiskObject icon (BeaconBridge.info).

Builds a valid Workbench .info file (magic 0xE310) for BeaconBridge.rexx.
Art: a suspension bridge at night with a moon, stars and a blinking beacon,
inspired by U+1F309 and U+1F6A8. Pure stdlib - no dependencies.
"""

import struct

W = H = 32
DEPTH = 3
GADGET = struct.Struct(">IhhhhHHHIIIiIHI")


def line(x0, y0, x1, y1):
    points = []
    dx, dy = abs(x1 - x0), -abs(y1 - y0)
    sx = 1 if x0 < x1 else -1
    sy = 1 if y0 < y1 else -1
    err = dx + dy
    while True:
        points.append((x0, y0))
        if x0 == x1 and y0 == y1:
            break
        e2 = 2 * err
        if e2 >= dy:
            err += dy
            x0 += sx
        if e2 <= dx:
            err += dx
            y0 += sy
    return points


def disc(cx, cy, r):
    return {
        (cx + dx, cy + dy)
        for dx in range(-r, r + 1)
        for dy in range(-r, r + 1)
        if dx * dx + dy * dy <= r * r
    }


def rect(x0, x1, y0, y1):
    return {(x, y) for x in range(x0, x1 + 1) for y in range(y0, y1 + 1)}


def rect_x(x0, x1, y):
    return {(x, y) for x in range(x0, x1 + 1)}


def build_variant(variant):
    pens = {
        "moon": 2, "stars": 2, "water": 3, "towers": 6, "deck": 6,
        "cables": 2, "post": 1, "dome": 7, "glow": 7,
        "warmrefl": 7, "whiterefl": 2, "skybg": 0,
    }
    if variant == "selected":
        pens.update(
            {"moon": 1, "stars": 1, "cables": 1, "post": 1, "skybg": 2}
        )

    features = {
        "skybg": {(x, y) for y in range(19) for x in range(32)},
        "water": rect(0, 31, 19, 31),
        "moon": disc(20, 3, 2),
        "stars": {(3, 2), (7, 6), (13, 3), (19, 1), (28, 7), (2, 8), (10, 9), (25, 3), (15, 8)},
        "towers": rect_x(4, 8, 5) | rect(5, 7, 6, 18) | rect_x(23, 27, 5) | rect(24, 26, 6, 18),
        "deck": rect(0, 31, 17, 18),
        "cables": set(
            line(6, 5, 11, 17)
            + line(6, 5, 16, 17)
            + line(25, 5, 21, 17)
            + line(25, 5, 16, 17)
        ),
        "post": {(16, y) for y in range(13, 18)},
        "dome": {(15, 12), (16, 12), (17, 12)},
        "glow": {(16, 11), (14, 11), (18, 11)},
        "warmrefl": {(16, 20), (16, 22), (16, 24)},
        "whiterefl": {(20, 20), (20, 21), (20, 22)},
    }

    grid = [[0] * W for _ in range(H)]
    for name, cells in features.items():
        for x, y in cells:
            if 0 <= x < W and 0 <= y < H:
                grid[y][x] = pens[name]
    return grid


def to_planes(grid):
    row_bytes = (W + 15) // 16 * 2
    planes = [bytearray(row_bytes * H) for _ in range(DEPTH)]
    for y in range(H):
        for x in range(W):
            c = grid[y][x]
            for p in range(DEPTH):
                if c & (1 << p):
                    planes[p][y * row_bytes + (x >> 3)] |= 0x80 >> (x & 7)
    return [bytes(p) for p in planes]


def pack_image(grid):
    header = struct.pack(">hhhhhIBBI", 0, 0, W, H, DEPTH, 0, (1 << DEPTH) - 1, 0, 0)
    return header + b"".join(to_planes(grid))


def build_info():
    out = bytearray()
    out += struct.pack(">HH", 0xE310, 0)
    out += GADGET.pack(0, 0, 0, W, H, 4, 0, 0, 1, 1, 0, 0, 0, 0, 0)
    out += struct.pack(">BB", 3, 0)
    out += struct.pack(">IIiiIii", 1, 0, 0, 0, 0, 0, 0)
    out += pack_image(build_variant("normal"))
    out += pack_image(build_variant("selected"))
    tool = b"BeaconBridge.rexx\x00"
    out += struct.pack(">I", len(tool)) + tool
    return bytes(out)


def preview():
    grid = build_variant("normal")
    glyph = {0: ".", 1: "+", 2: "*", 3: "~", 6: "#", 7: "@"}
    return "\n".join(
        "".join(glyph.get(c, "?") for c in row) for row in grid
    )


def main():
    data = build_info()
    with open("BeaconBridge.info", "wb") as f:
        f.write(data)
    print(preview())
    print(f"\nwrote BeaconBridge.info ({len(data)} bytes)")


if __name__ == "__main__":
    main()