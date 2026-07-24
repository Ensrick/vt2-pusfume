"""Read the scene graph from a compiled Vermintide 2 unit resource."""

import struct

try:
    from .strip_bundle_resource import murmur64a
except ImportError:  # Blender executes this module outside the tools package.
    from strip_bundle_resource import murmur64a


class UnitReader:
    def __init__(self, data):
        self.data = data
        self.offset = 0

    def skip(self, size):
        self.offset += size
        if self.offset > len(self.data):
            raise ValueError("Compiled unit ended before its scene graph")

    def u32(self):
        value = struct.unpack_from("<I", self.data, self.offset)[0]
        self.offset += 4
        return value

    def array(self, item_size):
        count = self.u32()
        self.skip(count * item_size)
        return count

    def byte_array(self):
        return self.array(1)

    def u32_array(self):
        count = self.u32()
        values = list(struct.unpack_from("<%dI" % count, self.data, self.offset))
        self.skip(count * 4)
        return values

    def matrix_array(self):
        count = self.u32()
        matrices = [
            struct.unpack_from("<16f", self.data, self.offset + index * 64)
            for index in range(count)
        ]
        self.skip(count * 64)
        return matrices


def short_hash(name):
    return murmur64a(name.encode("utf-8")) >> 32


def read_scene_graph(path):
    with open(path, "rb") as unit_file:
        reader = UnitReader(unit_file.read())
    version = reader.u32()
    if version != 189:
        raise ValueError("Expected VT2 unit version 189, found %d" % version)

    geometry_count = reader.u32()
    for _geometry_index in range(geometry_count):
        stream_count = reader.u32()
        for _stream_index in range(stream_count):
            reader.byte_array()
            reader.skip(16)  # validity, stream type, count, stride

        channel_count = reader.u32()
        reader.skip(channel_count * 17)  # four u32 values plus one bool
        reader.skip(16)  # index stream enums and index count
        reader.byte_array()
        reader.array(16)  # batch ranges
        reader.skip(28)  # bounding volume
        reader.array(4)  # material hashes

    skin_count = reader.u32()
    skins = []
    for _skin_index in range(skin_count):
        inverse_bind_matrices = reader.matrix_array()
        node_indices = reader.u32_array()
        matrix_set_count = reader.u32()
        matrix_sets = []
        for _matrix_set_index in range(matrix_set_count):
            matrix_sets.append(reader.u32_array())
        skins.append(
            {
                "inverse_bind_matrices": inverse_bind_matrices,
                "matrix_sets": matrix_sets,
                "node_indices": node_indices,
            }
        )

    reader.byte_array()  # simple animation
    animation_group_count = reader.u32()
    for _group_index in range(animation_group_count):
        reader.skip(4)  # name hash
        reader.array(4)

    node_count = reader.u32()
    if not 1 <= node_count <= 255:
        raise ValueError("Implausible unit scene graph size: %d" % node_count)

    local_nodes = []
    for _node_index in range(node_count):
        local_nodes.append(struct.unpack_from("<15f", reader.data, reader.offset))
        reader.skip(60)

    world_matrices = []
    for _node_index in range(node_count):
        world_matrices.append(struct.unpack_from("<16f", reader.data, reader.offset))
        reader.skip(64)

    parents = []
    for _node_index in range(node_count):
        parents.append(struct.unpack_from("<HH", reader.data, reader.offset))
        reader.skip(4)

    name_hashes = []
    for _node_index in range(node_count):
        name_hashes.append(reader.u32())

    return {
        "geometry_count": geometry_count,
        "skin_count": skin_count,
        "skins": skins,
        "nodes": [
            {
                "index": index,
                "local": local_nodes[index],
                "name_hash": name_hashes[index],
                "parent": parents[index],
                "world": world_matrices[index],
            }
            for index in range(node_count)
        ],
        "version": version,
    }
