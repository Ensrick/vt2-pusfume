# Pusfume material and deformation strategies

This matrix records independent ways to combine Pusfume's textures with his
82-bone deformation. Claims are separated into offline evidence and live
evidence so an experiment cannot accidentally become the release baseline.

## Promotion rule

The last Workshop upload remains the safest known-good build. A candidate may
replace it only after its bundle passes source tests, compiles cleanly, contains
no game-resource hash collisions, and deforms with the atlas in both the hero
preview and third-person gameplay.

## Candidates

| Strategy | Offline status | Live status | Next discriminator |
| --- | --- | --- | --- |
| Installed Globadier material swap | Package and resource hashes verified; current fallback | Deformation verified; donor textures remain | Keep as rollback baseline |
| Stripped compiled child | Child parent hash and atlas overrides verified; strip work is Track A | Not yet tested without the shadowing stub | Bundle listing must omit `90BDF3BAC6F81BA8` while retaining child `34482D9DD0D8E385` |
| Native SDK skinned graph | `standard_base` supports four-weight skinning; disabling option removed in this branch | Not yet tested | Compile and confirm custom shader device data differs from static SDK standard, then run isolated preview/game test |
| Legacy donor materials in the unit | Dalokraff's custom units bind game weapon/career materials directly | His inn NPC animated; textures were donor-owned | Compile a Pusfume unit whose atlas UVs target one suitable installed character material without runtime swapping |
| Material resource-ID restoration | Retail source proves `Unit.get_material_resource_id` and `Unit.set_material_from_id` are supported | Not tested for cross-unit cloning | Log resource IDs before/after a donor swap and verify exact restoration on unload |
| First-person/husk split | Architecture and package paths are known | Not implemented | Add dedicated first-person arms and remote-husk probes after third-person promotion |

## Native graph finding

The copied SDK graph had an option named
`b5bb2062-c8fa-43c5-8657-493a0be6860c`. The installed SDK maps that exact GUID
to `SKINNED_DISABLED` in `standard_base.shader_node`. The same output node
contains a permutation rule that defines `SKINNED_4WEIGHTS` only when that
option is absent and the mesh reports four weights. Pusfume's compiled unit
already has `HALF4` weights and packed blend indices, so removing the option is
a direct test of the renderer condition that was previously forced false.

Before this change, the 185,088-byte custom body material and SDK standard
material had identical 177,366-byte shader device-data payloads. They differed
only in shader identifiers and graph data. That explains why the supposedly
skinned template behaved exactly like static SDK standard.

After removing the option, the native build passed and the body material grew
to 399,984 bytes. Its shader device data grew to 385,080 bytes with SHA-256
`5B53F76E3AF6FCF2C37AABE2891C845F2803B56BE62FFC54A84749B33536706B`,
while SDK standard stayed at 177,366 bytes. This proves Stingray emitted a
different permutation set. It does not replace the required live deformation
test, so this branch remains undeployed.

## Resource-ID probe

Retail VT2 uses this reversible pattern for temporary eye effects:

1. Cache `Unit.get_material_resource_id(unit, slot_name)`.
2. Apply a named replacement with `Unit.set_material`.
3. Restore the exact prior resource with `Unit.set_material_from_id`.

This is useful for cleanup and diagnostics but does not create a new material
with Pusfume textures. It should supplement, not replace, either the stripped
child or the corrected native graph.
