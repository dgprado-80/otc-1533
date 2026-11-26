#!/usr/bin/env python3
"""Build a complete OTClient minimap.otmm from the server OTBM maps.

Loads the same maps the Crystal server starts with:
  - data-global/world/<mapName>.otbm
  - every *.otbm in data-global/world/custom/ that does not start with '#'

Tile colors and walk flags come from appearances.dat (automap / unpass),
the same source OTClient uses for the in-game minimap.
"""

from __future__ import annotations

import argparse
import os
import struct
import sys
import time
import zlib
from collections import defaultdict
from pathlib import Path

ROOT = Path(__file__).resolve().parents[1]
PROTO_DIR = Path(__file__).resolve().parent / "_proto_gen"
sys.path.insert(0, str(PROTO_DIR))

try:
    import appearances_pb2
except ImportError as exc:
    raise SystemExit(
        "Missing appearances_pb2. Run:\n"
        "  python -m grpc_tools.protoc -I src/protobuf "
        "--python_out=tools/_proto_gen src/protobuf/appearances.proto"
    ) from exc

NODE_START = 0xFE
NODE_END = 0xFF
NODE_ESCAPE = 0xFD

OTBM_MAP_HEADER = 0
OTBM_MAP_DATA = 2
OTBM_TILE_AREA = 4
OTBM_TILE = 5
OTBM_ITEM = 6
OTBM_HOUSETILE = 14

OTBM_ATTR_DESCRIPTION = 1
OTBM_ATTR_EXT_FILE = 2
OTBM_ATTR_TILE_FLAGS = 3
OTBM_ATTR_ACTION_ID = 4
OTBM_ATTR_UNIQUE_ID = 5
OTBM_ATTR_TEXT = 6
OTBM_ATTR_DESC = 7
OTBM_ATTR_TELE_DEST = 8
OTBM_ATTR_ITEM = 9
OTBM_ATTR_DEPOT_ID = 10
OTBM_ATTR_EXT_SPAWN_FILE = 11
OTBM_ATTR_RUNE_CHARGES = 12
OTBM_ATTR_EXT_HOUSE_FILE = 13
OTBM_ATTR_HOUSEDOORID = 14
OTBM_ATTR_COUNT = 15
OTBM_ATTR_DURATION = 16
OTBM_ATTR_DECAYING_STATE = 17
OTBM_ATTR_WRITTENDATE = 18
OTBM_ATTR_WRITTENBY = 19
OTBM_ATTR_SLEEPERGUID = 20
OTBM_ATTR_SLEEPSTART = 21
OTBM_ATTR_CHARGES = 22
OTBM_ATTR_EXT_SPAWN_NPC_FILE = 23
OTBM_ATTR_EXT_ZONE_FILE = 24

MMBLOCK = 64
OTMM_SIGNATURE = 0x4D4D544F
OTMM_VERSION = 1
MAP_MAX_Z = 15

FLAG_SEEN = 1
FLAG_NOT_PATHABLE = 2
FLAG_NOT_WALKABLE = 4

_STRING_ATTRS = {
    OTBM_ATTR_DESCRIPTION,
    OTBM_ATTR_EXT_FILE,
    OTBM_ATTR_TEXT,
    OTBM_ATTR_DESC,
    OTBM_ATTR_WRITTENBY,
    OTBM_ATTR_EXT_SPAWN_FILE,
    OTBM_ATTR_EXT_HOUSE_FILE,
    OTBM_ATTR_EXT_SPAWN_NPC_FILE,
    OTBM_ATTR_EXT_ZONE_FILE,
}

_U8_ATTRS = {
    OTBM_ATTR_RUNE_CHARGES,
    OTBM_ATTR_HOUSEDOORID,
    OTBM_ATTR_COUNT,
    OTBM_ATTR_DECAYING_STATE,
}

_U16_ATTRS = {
    OTBM_ATTR_ACTION_ID,
    OTBM_ATTR_UNIQUE_ID,
    OTBM_ATTR_DEPOT_ID,
    OTBM_ATTR_CHARGES,
}

_U32_ATTRS = {
    OTBM_ATTR_TILE_FLAGS,
    OTBM_ATTR_DURATION,
    OTBM_ATTR_WRITTENDATE,
    OTBM_ATTR_SLEEPERGUID,
    OTBM_ATTR_SLEEPSTART,
}


class EscapedReader:
    def __init__(self, data: bytes):
        self.data = data
        self.pos = 0
        self.n = len(data)

    def remaining(self) -> int:
        return self.n - self.pos

    def peek_raw(self) -> int:
        if self.pos >= self.n:
            raise EOFError("unexpected end of OTBM")
        return self.data[self.pos]

    def get_byte(self) -> int:
        if self.pos >= self.n:
            raise EOFError("unexpected end of OTBM")
        b = self.data[self.pos]
        self.pos += 1
        if b == NODE_ESCAPE:
            if self.pos >= self.n:
                raise EOFError("truncated escape")
            b = self.data[self.pos]
            self.pos += 1
        return b

    def get_u8(self) -> int:
        return self.get_byte()

    def get_u16(self) -> int:
        return self.get_byte() | (self.get_byte() << 8)

    def get_u32(self) -> int:
        return (
            self.get_byte()
            | (self.get_byte() << 8)
            | (self.get_byte() << 16)
            | (self.get_byte() << 24)
        )

    def get_string(self) -> bytes:
        length = self.get_u16()
        return bytes(self.get_byte() for _ in range(length))

    def at_node_marker(self) -> bool:
        if self.pos >= self.n:
            return True
        b = self.data[self.pos]
        return b in (NODE_START, NODE_END)

    def start_node(self) -> int | None:
        if self.pos >= self.n:
            return None
        if self.data[self.pos] != NODE_START:
            return None
        self.pos += 1
        return self.get_byte()

    def end_node(self) -> None:
        if self.pos >= self.n or self.data[self.pos] != NODE_END:
            raise ValueError(f"expected NODE_END at {self.pos}")
        self.pos += 1

    def skip_node(self) -> None:
        """Skip the remainder of the current node, including children."""
        depth = 1
        while depth > 0:
            if self.pos >= self.n:
                raise EOFError("truncated node while skipping")
            b = self.data[self.pos]
            self.pos += 1
            if b == NODE_ESCAPE:
                self.pos += 1
            elif b == NODE_START:
                depth += 1
            elif b == NODE_END:
                depth -= 1


def load_item_info(appearances_path: Path) -> tuple[dict[int, int], set[int]]:
    app = appearances_pb2.Appearances()
    app.ParseFromString(appearances_path.read_bytes())
    colors: dict[int, int] = {}
    blocked: set[int] = set()
    for obj in app.object:
        item_id = int(obj.id)
        if obj.flags.HasField("automap") and obj.flags.automap.color:
            colors[item_id] = int(obj.flags.automap.color) & 0xFF
        if obj.flags.unpass:
            blocked.add(item_id)
    return colors, blocked


def read_item_attr(reader: EscapedReader, attr: int) -> bool:
    """Consume one item attribute. Returns False if the attribute is unknown."""
    if attr in _STRING_ATTRS:
        reader.get_string()
    elif attr in _U8_ATTRS:
        reader.get_u8()
    elif attr in _U16_ATTRS:
        reader.get_u16()
    elif attr in _U32_ATTRS:
        reader.get_u32()
    elif attr == OTBM_ATTR_TELE_DEST:
        reader.get_u16()
        reader.get_u16()
        reader.get_u8()
    elif attr == OTBM_ATTR_ITEM:
        reader.get_u16()
    else:
        return False
    return True


def read_item_subtree(reader: EscapedReader, items: list[int]) -> None:
    """Current node is already opened as OTBM_ITEM; id already read."""
    while not reader.at_node_marker():
        attr = reader.get_u8()
        if not read_item_attr(reader, attr):
            reader.pos -= 1
            reader.skip_node()
            return

    while True:
        child = reader.start_node()
        if child is None:
            break
        if child == OTBM_ITEM:
            item_id = reader.get_u16()
            items.append(item_id)
            read_item_subtree(reader, items)
            reader.end_node()
        else:
            reader.skip_node()


class MinimapBuilder:
    def __init__(self, colors: dict[int, int], blocked: set[int]):
        self.colors = colors
        self.blocked = blocked
        # z -> block_index -> bytearray(64*64*3)
        self.blocks: dict[int, dict[int, bytearray]] = defaultdict(dict)
        self.tiles = 0
        self.colored = 0

    @staticmethod
    def block_index(x: int, y: int) -> int:
        return ((y // MMBLOCK) * (65536 // MMBLOCK)) + (x // MMBLOCK)

    def set_tile(self, x: int, y: int, z: int, item_ids: list[int]) -> None:
        if z > MAP_MAX_Z:
            return
        color = 255
        for item_id in reversed(item_ids):
            c = self.colors.get(item_id)
            if c:
                color = c
                break
        if color == 255 and not item_ids:
            return

        flags = FLAG_SEEN
        if any(item_id in self.blocked for item_id in item_ids):
            flags |= FLAG_NOT_WALKABLE | FLAG_NOT_PATHABLE

        idx = self.block_index(x, y)
        block = self.blocks[z].get(idx)
        if block is None:
            block = bytearray(MMBLOCK * MMBLOCK * 3)
            # default color 255
            for i in range(1, len(block), 3):
                block[i] = 255
            for i in range(2, len(block), 3):
                block[i] = 10
            self.blocks[z][idx] = block

        lx = x % MMBLOCK
        ly = y % MMBLOCK
        off = ((ly * MMBLOCK) + lx) * 3
        block[off] = flags
        block[off + 1] = color
        block[off + 2] = 10
        self.tiles += 1
        if color != 255:
            self.colored += 1

    def ingest_otbm(self, path: Path) -> None:
        data = path.read_bytes()
        reader = EscapedReader(data)
        # Canary/Remere: 4-byte identifier then root node. Header fields live in the root.
        if reader.peek_raw() != NODE_START:
            reader.pos += 4

        root = reader.start_node()
        if root is None:
            raise ValueError(f"{path}: missing root node")

        version = reader.get_u32()
        reader.get_u16()  # width
        reader.get_u16()  # height
        reader.get_u32()  # major items
        reader.get_u32()  # minor items
        if version > 5:
            raise ValueError(f"{path}: unsupported OTBM version {version}")

        map_data = reader.start_node()
        if map_data != OTBM_MAP_DATA:
            raise ValueError(f"{path}: missing map data (got {map_data})")

        # map attributes until the next node marker
        while not reader.at_node_marker():
            attr = reader.get_u8()
            if attr in (
                OTBM_ATTR_DESCRIPTION,
                OTBM_ATTR_EXT_FILE,
                OTBM_ATTR_EXT_SPAWN_FILE,
                OTBM_ATTR_EXT_HOUSE_FILE,
                OTBM_ATTR_EXT_SPAWN_NPC_FILE,
                OTBM_ATTR_EXT_ZONE_FILE,
            ):
                reader.get_string()
            else:
                reader.pos -= 1
                break

        while True:
            area = reader.start_node()
            if area is None:
                break
            if area != OTBM_TILE_AREA:
                reader.skip_node()
                continue

            base_x = reader.get_u16()
            base_y = reader.get_u16()
            base_z = reader.get_u8()

            while True:
                tile_type = reader.start_node()
                if tile_type is None:
                    break
                if tile_type not in (OTBM_TILE, OTBM_HOUSETILE):
                    reader.skip_node()
                    continue

                tx = reader.get_u8()
                ty = reader.get_u8()
                x = base_x + tx
                y = base_y + ty
                z = base_z
                if tile_type == OTBM_HOUSETILE:
                    reader.get_u32()

                items: list[int] = []
                while not reader.at_node_marker():
                    attr = reader.get_u8()
                    if attr == OTBM_ATTR_TILE_FLAGS:
                        reader.get_u32()
                    elif attr == OTBM_ATTR_ITEM:
                        items.append(reader.get_u16())
                    else:
                        reader.pos -= 1
                        break

                while True:
                    child = reader.start_node()
                    if child is None:
                        break
                    if child == OTBM_ITEM:
                        item_id = reader.get_u16()
                        items.append(item_id)
                        read_item_subtree(reader, items)
                        reader.end_node()
                    else:
                        reader.skip_node()

                if items:
                    self.set_tile(x, y, z, items)
                reader.end_node()

            reader.end_node()

        reader.end_node()  # map data
        while True:
            extra = reader.start_node()
            if extra is None:
                break
            reader.skip_node()
        reader.end_node()

    def write_otmm(self, path: Path) -> None:
        parts: list[bytes] = []
        header = bytearray()
        header += struct.pack("<I", OTMM_SIGNATURE)
        header += struct.pack("<H", 0)  # start placeholder
        header += struct.pack("<H", OTMM_VERSION)
        header += struct.pack("<I", 0)  # flags
        desc = b"OTMM 1.0"
        header += struct.pack("<H", len(desc)) + desc
        start = len(header)
        struct.pack_into("<H", header, 4, start)
        parts.append(bytes(header))

        empty = bytes([0, 255, 10]) * (MMBLOCK * MMBLOCK)
        block_size = MMBLOCK * MMBLOCK * 3
        written = 0
        for z in range(MAP_MAX_Z + 1):
            for index, raw in self.blocks.get(z, {}).items():
                if raw == empty or all(raw[i] == 0 and raw[i + 1] == 255 for i in range(0, len(raw), 3)):
                    # still write if any tile was seen
                    if not any(raw[i] & FLAG_SEEN for i in range(0, len(raw), 3)):
                        continue
                bx = (index % (65536 // MMBLOCK)) * MMBLOCK
                by = (index // (65536 // MMBLOCK)) * MMBLOCK
                compressed = zlib.compress(bytes(raw), 3)
                if len(compressed) > 0xFFFF:
                    raise ValueError(f"compressed block too large at {bx},{by},{z}")
                parts.append(struct.pack("<HHB", bx, by, z))
                parts.append(struct.pack("<H", len(compressed)))
                parts.append(compressed)
                written += 1

        parts.append(struct.pack("<HHB", 0xFFFF, 0xFFFF, 0xFF))
        path.parent.mkdir(parents=True, exist_ok=True)
        path.write_bytes(b"".join(parts))
        print(f"wrote {path} blocks={written} size={path.stat().st_size}")


def list_server_maps(world_dir: Path) -> list[Path]:
    main = world_dir / "world.otbm"
    maps: list[Path] = []
    if main.exists():
        maps.append(main)
    custom = world_dir / "custom"
    if custom.is_dir():
        for path in sorted(custom.glob("*.otbm")):
            if path.name.startswith("#"):
                print(f"skip disabled {path.name}")
                continue
            maps.append(path)
    return maps


def main() -> int:
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument(
        "--server-world",
        default=r"D:\Github\best-1524\data-global\world",
        help="Path to server world folder",
    )
    parser.add_argument(
        "--appearances",
        default=str(ROOT / "data" / "things" / "1530" / "appearances.dat"),
        help="Client appearances.dat used for minimap colors",
    )
    parser.add_argument(
        "--output",
        default=str(ROOT / "data" / "minimap.otmm"),
        help="Destination minimap.otmm",
    )
    args = parser.parse_args()

    world_dir = Path(args.server_world)
    appearances = Path(args.appearances)
    output = Path(args.output)

    if not appearances.exists():
        raise SystemExit(f"appearances not found: {appearances}")
    if not world_dir.exists():
        raise SystemExit(f"world dir not found: {world_dir}")

    print(f"loading colors from {appearances}")
    t0 = time.time()
    colors, blocked = load_item_info(appearances)
    print(f"  colors={len(colors)} blocked={len(blocked)} in {time.time()-t0:.1f}s")

    maps = list_server_maps(world_dir)
    if not maps:
        raise SystemExit("no maps found")
    print("maps:")
    for path in maps:
        print(f"  {path.name} ({path.stat().st_size / 1024 / 1024:.1f} MB)")

    builder = MinimapBuilder(colors, blocked)
    for path in maps:
        t1 = time.time()
        print(f"reading {path.name} ...")
        try:
            builder.ingest_otbm(path)
        except Exception as exc:
            print(f"ERROR in {path}: {exc}")
            raise
        print(
            f"  done in {time.time()-t1:.1f}s  tiles={builder.tiles} colored={builder.colored} "
            f"blocks={sum(len(v) for v in builder.blocks.values())}"
        )

    builder.write_otmm(output)
    print(f"total {time.time()-t0:.1f}s")
    return 0


if __name__ == "__main__":
    raise SystemExit(main())
