# Pusfume Ragdoll Pipeline

This document defines the evidence-based process for adding a Vermintide 2
ragdoll to Pusfume. It follows the same rule as the animation pipeline: keep
the game-compatible deform skeleton immutable, derive data from a compatible
native donor, compile, inspect the compiled result, and accept it only after a
controlled in-game test.

## Evidence labels

- **Confirmed** means source code, a compiled retail resource, or a Pusfume
  build was inspected directly.
- **Inferred** means the conclusion follows from confirmed behavior but has not
  yet passed a Pusfume live test.
- **Live gate** means the game must prove the behavior before we call it done.

Do not convert an inference into a production requirement without recording
the confirming build, log, and test result.

## What a VT2 ragdoll actually is

A baked animation and a ragdoll both move skeleton nodes, but they are not the
same resource:

| Contract | Owner | Purpose |
| --- | --- | --- |
| Deform skeleton | `.unit`, `.bones`, skinned mesh | Stable names, hierarchy, rest transforms, and skin weights |
| Living motion | `.animation` and `.state_machine` | Poses the deform skeleton while the character is controlled |
| Hit collision | Compiled `.unit` actors/shapes | Maps attacks to named `c_*` collision actors |
| Ragdoll selection | Compiled `.state_machine` | Defines ragdoll states and dynamic/keyframed `j_*` actor sets |
| Physics constraints | Compiled state-machine/unit physics data | Limits how the simulated skeleton separates and rotates |
| Gameplay mapping | Breed hit-zone tables | Translates `c_*` hit actors to `j_*` ragdoll actors and supplies impulse thickness |
| Runtime transition | Lua plus state-machine event | Sends `ragdoll`, applies impulses, handles wall nails, replication, and corpse cleanup |

**Confirmed:** VT2 defines `RAGDOLL_STATE = 4` in its compiled animation-state
parser. A compiled ragdoll contains `dynamic_actors` and `keyframed_actors`.
The retail slave-rat state machine contains the event `ragdoll`, eight ragdoll
sets, and three ragdoll states.

**Confirmed:** the compiled slave-rat unit contains 28 named collision actors,
229 scene nodes, and no records in its legacy `JointDesc` array. Its ragdoll
constraints are therefore not represented as a simple Blender-style list of
unit joints. The unit instead contains matching 125,236-byte 32-bit and 64-bit
opaque physics-scene payloads. The state machine's separate `constraints`
field is only four bytes in this donor, consistent with an empty serialized
array header. Never infer that a visually successful Blender rigid-body test
is a complete VT2 ragdoll export.

## Current Pusfume architecture

The current native build generates both first- and third-person state machines
with `ragdolls = {}`. Pusfume's visible third-person mesh is a linked child of a
playable parent unit; the parent currently owns locomotion and gameplay.

This creates a mandatory Gate 0 decision:

1. **Current linked-child build:** keep physics on the parent and test whether
   the linked Pusfume nodes follow the parent's native death ragdoll. Do not add
   a second dynamic ragdoll to the visual child.
2. **Future standalone Pusfume player unit:** give that unit one complete,
   donor-derived ragdoll contract and remove dependence on the parent ragdoll.

**Inferred:** the existing per-node links should follow the parent when its
nodes become physical. This is not accepted until the linked-child death test
passes. Two simultaneous physics owners can fight over the same visible
skeleton, causing stretching, jitter, explosive separation, or a crash.

## Canonical donor

Pusfume's current third-person handoff preserves an untouched slave-rat
skeleton, so the first donor is:

```text
units/beings/enemies/skaven_clan_rat/chr_skaven_slave
```

The source path hashes to `1F5A31DDD038B30C`; the locally extracted compiled
unit with that name was audited. It references the shared state machine:

```text
units/beings/enemies/skaven_clan_rat/chr_skaven_clan_rat
```

That path hashes to `2ECE63855280FB09`.

The first slave-rat ragdoll set contains 28 dynamic `j_*` actors and no
keyframed actors: head, hips, both arm chains, both leg chains, shoulders,
neck, spine, and six tail nodes. Other sets omit selected body regions for
special death states, so copying only the first list would be incomplete.

Extracted Fatshark resources remain local and untracked. Record hashes and
derived metadata; do not commit or publicly redistribute the retail files.

## Repeatable workflow

### 1. Freeze the game skeleton

Use two rigs in Blender:

- `PUSFUME_GAME_RIG` is the canonical deform/export rig. Bone names,
  hierarchy, parent relationships, rest matrices, bone lengths, and scale stay
  unchanged.
- `PUSFUME_CONTROL_RIG` may contain IK controls, connected chains, custom
  shapes, drivers, or convenience bones. Bake its result onto the game rig and
  never export it as the runtime skeleton.

Physics guide objects belong in a separate `PUSFUME_RAGDOLL_GUIDES`
collection. They may be moved and resized without changing the game rig.

Run the same rest-signature comparison used by animation before and after
ragdoll authoring. A rest-transform difference is a failed handoff, not a
retargeting opportunity.

### 2. Capture the complete donor contract

Audit both the compiled donor unit and its compiled state machine:

```powershell
& "C:\Program Files\Blender Foundation\Blender 5.2\blender.exe" `
  --background --factory-startup --disable-autoexec `
  --python tools\audit_vt2_ragdoll.py -- `
  ".build\generated-native\slave-rat-bundle-extract\1F5A31DDD038B30C.unit" `
  --bitsquid-tools "C:\Users\danjo\source\repos\_bitsquid_blender_tools" `
  --state-machine ".build\generated-native\slave-rat-bundle-extract\2ECE63855280FB09.state_machine" `
  --output ".build\slave-rat-ragdoll-audit.json"
```

The audit is read-only. Preserve its JSON beside the build evidence and record:

- unit and state-machine source paths and hashes;
- scene-node, actor, shape, and joint counts;
- actor names, bound nodes, templates, masses, materials, shape types,
  dimensions, and local transforms;
- every ragdoll set, its ordering, and its dynamic/keyframed actor names;
- every ragdoll state and its ragdoll-set index;
- event names and exact state-machine constraint and unit physics-scene byte
  counts;
- the donor breed's hit zones, `push_actors`,
  `hitbox_ragdoll_translation`, and `ragdoll_actor_thickness`.

Do not hand-copy only the actor names. Shape transforms, set ordering, state
indices, collision filtering, and constraints are part of the contract.

### 3. Build Blender guides without changing compatibility

Janfon may create one guide object per physical region, using capsules,
spheres, boxes, or convex guides that fit the body. Name each guide after its
intended actor and store these custom properties:

```text
vt2_actor_name
vt2_bound_bone
vt2_shape_type
vt2_mass
vt2_actor_template
vt2_shape_template
vt2_physics_material
vt2_donor_hash
```

Constraint guides should record the two actors, type, anchor, axes, angular or
distance limits, spring/damping values, and donor hash. These are source
metadata for review; ordinary FBX does not prove that Stingray compiled them.

Start with donor dimensions and limits. Resize only where Pusfume's silhouette
requires it, one region at a time. Keep shapes inside the visible body where
possible, avoid tiny shapes, and avoid adjacent shapes that begin deeply
interpenetrating.

A Blender drop test may catch inverted axes, disconnected chains, or obvious
intersections. Blender and VT2 do not use the same runtime solver, so it is a
sanity check, never an acceptance test.

### 4. Choose the implementation path

For the current linked-child build, do not compile child physics yet. Add a
diagnostic that confirms the parent enters ragdoll and that every linked
Pusfume node remains attached. If this passes, the parent is the one physics
owner and the visual child needs no duplicate actor graph.

For a standalone unit, reuse the complete native slave-rat contract only after
the canonical node names and rest transforms compare successfully. The correct
no-Maya implementation must preserve or regenerate the compiled physics and
state-machine data. A raw binary splice is allowed only when an automated gate
proves all referenced node hashes, actor hashes, array indices, resource
versions, and section sizes match. Never splice around a failed compatibility
check.

If the rest skeleton changes in the final model, calculate actor-local
transforms and constraint anchors from donor world space into the new rest
spaces, then compare the reconstructed world positions. Do not rotate or
rebuild the deform bones to make the physics guides convenient.

### 5. Wire the state machine

The standalone state machine must contain:

- the `ragdoll` event used by VT2 runtime code;
- one or more states whose compiled type is `RAGDOLL_STATE`;
- the complete ordered ragdoll sets required by those states;
- valid dynamic and keyframed actor lists;
- the donor-derived constraints and transitions needed by the selected death
  states.

Do not guess source-recipe syntax from the compiled field names. Compile a
small isolated resource, re-audit it, and compare its compiled contract with
the donor before integrating it into the player package.

### 6. Align gameplay mappings

The slave-rat breed maps attack actors to ragdoll actors. Examples include:

```text
c_head   -> j_head
c_hips   -> j_hips
c_spine  -> j_spine
c_spine2 -> j_spine1
c_tail1  -> j_tail1
c_tail6  -> j_tail6
```

Pusfume's player implementation needs equivalent data wherever its death,
impulse, or wall-nail path reads breed settings. Every value referenced by
`push_actors` or `hitbox_ragdoll_translation` must exist in the compiled
ragdoll contract. Every wall-nailable actor needs a positive
`ragdoll_actor_thickness` value.

The retail source contains an older `j_taill` spelling in parts of this table,
while the audited state machine resolves `j_tail1`. Treat that as a required
cross-resource verification, not an invitation to rename Pusfume's bone.

### 7. Compile and audit the result

Compiler success is only the first gate. Re-run `audit_vt2_ragdoll.py` on the
compiled Pusfume resources and compare machine-readable JSON against the
approved donor/manifest:

- no missing or duplicate actor names;
- every actor-bound node exists;
- all dimensions, masses, transforms, anchors, axes, and limits are finite;
- dimensions and masses are positive where the donor requires them;
- dynamic and keyframed sets are disjoint;
- every ragdoll state references an existing ragdoll-set index;
- all mapped `j_*` actors occur in the intended set;
- no unexpected actor, constraint, or set disappears during compilation;
- package dependencies include the unit, state machine, skeleton, and required
  physics resources.

The first production transfer should be byte- or field-identical to the donor
where the skeleton permits it. Tune only after that baseline survives in game.

## Janfon handoff checklist

Deliver these together for each ragdoll revision:

- Blender 5.2 `.blend` with the canonical game rig, control rig, and ragdoll
  guides in separate named collections;
- canonical rest-signature report showing no game-rig changes;
- one guide per intended actor with the custom properties above;
- constraint-guide metadata or a donor-contract JSON reference;
- body, equipment, fur, whisker, backpack, and tail meshes shown in rest pose;
- list of intentionally non-physical accessory bones and how they should
  follow their nearest physical ancestor;
- screenshots from front, side, and top with physics guides visible;
- short notes for desired tail, ears, whiskers, backpack, and fur behavior;
- Blender sanity-test video, clearly labeled non-authoritative;
- source asset provenance and permission status.

Janfon should not connect, resize, rotate, rename, reparent, or symmetrize the
canonical deform bones for IK or ragdoll convenience. Any helper rig is valid
as long as its animation is baked back to the unchanged game rig.

## Offline acceptance gates

Before a live build:

1. Compare bone names, parents, rest transforms, and scale with the approved
   game-rig signature.
2. Verify every skinned vertex remains normalized and within the VT2 influence
   limit.
3. Verify every actor and ragdoll name resolves to an intended scene node.
4. Verify all ragdoll-set indices and actor lists against the donor manifest.
5. Reject NaN, infinity, zero-size shapes, invalid limits, orphan references,
   duplicate names, and disconnected required regions.
6. Compile in an isolated staging directory and capture the compiler log.
7. Audit the compiled output, not just the source recipe.
8. Confirm exactly one runtime unit owns physical simulation.
9. Confirm extracted retail resources remain outside Git and public packages.

## In-game acceptance matrix

Each test gets its own build identifier, log, result, and short video. Stop at
the first failure and change one variable before rebuilding.

1. Linked-child baseline: standing death while Pusfume is visible.
2. Falling death: jump or ledge death with vertical momentum.
3. Directional death: front, rear, left, and right impulses.
4. Explosion: low and high impulse without stretching or separation.
5. Environment: flat floor, stairs, slope, wall, doorway, and ledge.
6. Settling: no perpetual jitter, tunneling, levitation, or explosive launch.
7. Second hit: corpse limb receives an impulse through the intended actor.
8. Wall nail: valid actor, thickness lookup, and cleanup behavior.
9. Accessories: tail, backpack, fur, whiskers, and equipment remain attached.
10. Camera/UI: first person, third-person inspect, hero preview, and inventory
    do not accidentally enter or inherit ragdoll state.
11. Authority: host player, client player, bot, remote husk, and hot join.
12. Lifecycle: corpse limits and cleanup remove all linked Pusfume units.
13. Settings: repeat with reduced/disabled ragdoll settings where available.
14. Regression: revive/respawn, weapon switching, mod disable, and next mission
    remain clean.

Acceptance requires no Pusfume-related script errors, missing actor/state/event
messages, physics assertions, leaked child units, or host/client disagreement
in the latest logs.

## Failure guide

| Symptom | Most likely contract failure | First check |
| --- | --- | --- |
| Model explodes on death | Two physics owners, bad rest space, or intersecting shapes | Gate 0 owner and rest signature |
| Mesh stretches to the map origin | Missing/mismatched physical node or broken link | Compiled actor/node names and child links |
| Corpse stays animated | Missing `ragdoll` event/state/transition | Compiled events and ragdoll states |
| Only some limbs simulate | Wrong ragdoll set or omitted actors | State's ragdoll index and complete set |
| Corpse cannot be pushed | Missing `push_actors` or translation entry | Breed mapping to compiled `j_*` actor |
| Wall nail crashes | Actor absent/nonphysical or thickness missing | `Unit.actor` name and thickness table |
| Tail/accessory detaches | Unmapped physical chain or unlinked child bone | Tail set, ancestor link, cleanup ownership |
| Host works, client fails | Husk package/resource or RPC mismatch | Remote unit, resource loading, network log |
| Blender works, VT2 fails | Solver/export assumption | Compiled audit and isolated live baseline |

## Confirmed source evidence

Runtime and gameplay behavior:

- `Vermintide-2-Source-Code/scripts/entity_system/systems/locomotion/locomotion_system.lua`
  sends the `ragdoll` animation event.
- `Vermintide-2-Source-Code/scripts/unit_extensions/generic/generic_hit_reaction_extension.lua`
  selects ragdoll deaths and applies impulses through breed `push_actors`.
- `Vermintide-2-Source-Code/scripts/unit_extensions/generic/death_reactions.lua`
  resolves physical actors for wall nails and reads
  `ragdoll_actor_thickness`.
- `Vermintide-2-Source-Code/scripts/settings/breeds/breed_skaven_slave.lua`
  defines collision hit zones, ragdoll translation, and thickness values.

Compiled resource layout:

- `_bitsquid_blender_tools/bitsquid/unit/vt2/parse_compiled.py`
- `_bitsquid_blender_tools/bitsquid/stingray/actor_resource.py`
- `_bitsquid_blender_tools/bitsquid/stingray/joint_desc.py`
- `_bitsquid_blender_tools/bitsquid/stingray/ragdoll.py`
- `_bitsquid_blender_tools/bitsquid/stingray/animation_state.py`
- `_bitsquid_blender_tools/bitsquid/stingray/animation_state_machine_resource.py`

## Remaining unknowns

- Whether the current Pusfume child follows the parent ragdoll without a link
  or cleanup defect is still a live gate.
- The exact source recipe needed to reproduce the retail opaque unit
  physics-scene payload without Autodesk tooling is not yet proven.
- The retail slave-rat state machine has multiple specialized ragdoll sets;
  their exact death-state semantics need a state-by-state manifest before a
  standalone implementation.
- Player/husk corpse ownership and wall-nail behavior need live multiplayer
  verification.

Until these gates pass, describe the pipeline as audited and ready for a
controlled prototype, not as a completed custom Pusfume ragdoll.
