# Collaboration board - Claude x Sol

Live coordination file for the overnight 2026-07-16 session on issue #6.
Both agents read this before editing anything and update their section after
every push. The user is asleep; no live testing is available - every claim
must be offline-verifiable (compiled bytes, logs, source) or marked
[unverified].

## Ground rules

- Pull before editing; the working tree is shared. Claim files below before
  touching them. If both need a file, the one who claimed it lands first and
  the other rebases.
- Every change passes `tools/Test-PusfumeSource.ps1` and
  `py -m unittest discover -s tests` before commit.
- Ship = `tools/Build-NativePusfume.ps1 -HeroPreview`, then VMBLauncher upload
  (settings file with ProjectRoot = `.build/native-workshop`; the staging root
  carries `.vmbrc`), then verify `Steam/logs/workshop_log.txt` gained a fresh
  `Uploaded new content` line, then commit + push. Do not leave the deployed
  Workshop item on an experimental build: the LAST uploaded build must always
  be the safest known-good one for the user's morning test.
- Deployed known-good right now: `1125d4f` / ManifestID 5211344820166029716
  (donor swap, walk+idle in game, menu preview shader applied). Do not upload
  over it unless your build is verifiably better.

## Confirmed facts (do not re-litigate without new evidence)

1. Custom skinned FBX deforms only when its surfaces use a GAME character
   material. Mod-SDK-compiled materials (standard parent or embedded
   standard_base graph) render textures but never skin.
2. Runtime texture overrides NEVER rebind on character materials.
   `Material.set_texture` by index and `Unit.set_texture_for_materials` both
   report success and change nothing rendered. The game itself never
   retextures characters at runtime; it swaps whole materials.
3. The texture channel names (`texture_map_02af90f8/27b67fd2/8bf37d8e`) are
   Fatshark's literal generated slot names (confirmed as real strings in the
   community hash dictionary), not decompiler placeholders.
4. The donor `mtr_outfit` is itself a slim child material: parent reference
   BY HASH (`3D25339231384C80`, path unknown) + texture overrides. Our SDK
   compiles the same structure: `materials/pusfume/pusfume_outfit_child`
   compiled to 400 bytes with parent hash `90BDF3BAC6F81BA8` and our three
   atlas texture ids (offline byte-verified).
5. The SDK material compiler REQUIRES the parent's SOURCE file at the exact
   path, and the compiled parent then rides into the bundle as a package
   dependency AT THE GAME'S RESOURCE PATH.
6. Mod bundle resources SHADOW game resources with the same path hash
   (2026-07-16 live test: black rigid body = child resolved the bundled stub,
   not the game parent).
7. Menu previewers (`MenuWorldPreviewer`) spawn `skin.third_person` +
   `skin.third_person_attachment.unit`; `retrieve_skin_packages_for_preview`
   indexes `third_person_attachment` unguarded (crashes if nil).

## The one remaining core problem

Get `pusfume_outfit_child` (compiled, verified) to resolve the GAME's
`mtr_outfit` parent at runtime. Blocked only by the stub parent shadowing the
game resource from inside our bundle.

## Track A - bundle stub strip [CLAIMED: Claude]

Post-build tool that renames the stub's resource id inside the built
`.mod_bundle` (resource table + data-block header) to an unused hash so the
child's parent reference resolves against the game's copy. Format sources:
`C:\Users\danjo\source\repos\vt2_bundle_unpacker` (Rust reader),
`C:\Users\danjo\source\repos\_stingray_reverse_engineering\hexpats`,
`_bitsquid_blender_tools` parsers. Deliverable:
`tools/strip_bundle_resource.py` + Build-NativePusfume integration behind
`-ParentChildMaterial` + offline verification (unpacker list shows the stub id
gone, child bytes untouched). Files claimed: `tools/strip_bundle_resource.py`,
`tools/Build-NativePusfume.ps1`, `tests/test_strip_bundle_resource.py`.

## Track B - suggestions for Sol (pick and claim here)

- B1: Extract dalokraff's COMPILED legacy Pusfume Workshop bundle (the
  extract pipeline lives in `misc-vermintide-mods/_scratch/extract_mod.ps1`)
  and determine how his compiled materials referenced game shaders - his mod
  had no .material sources and no runtime swap Lua. If his compiled bundle
  contains child materials referencing game parents WITHOUT a bundled stub,
  learn how his build produced them.
- B2: Investigate whether the SDK's shader graph system can compile a
  skinning-capable permutation at all: the embedded standard_base payloads are
  185,088 bytes; compare their context/permutation tables against a game
  character shader using `bitsquid.material.parse_compiled`. If a graph
  option exists (skinning define, contexts list), the whole donor dependency
  disappears.
- B3: The hero-select preview still needs verification that
  `apply_donor_to_unit` renders on the preview mesh (world differences). If
  reworking, note the preview mesh spawns hidden and unhides via
  `_update_units_visibility`.
- B4: First-person arms and the husk path remain untouched.

## Status log (append entries, newest first)

- 02:2x Claude: TRACK A COMPLETE (offline). `tools/strip_bundle_resource.py`
  renames the stub's (type,name) identity inside the built bundle (index +
  file header + package listing = exactly 3 pairs, verified on the real
  bundle). The rewritten bundle parses cleanly in the independent Rust
  unpacker; the stub id is gone; the compiled child
  (`materials/pusfume/pusfume_outfit_child` = 34482D9DD0D8E385, 400 bytes)
  still carries parent hash 90BDF3BAC6F81BA8 + atlas texture ids.
  Build integration: `Build-NativePusfume.ps1 -ParentChildMaterial` now
  strips automatically post-compile and hard-fails unless exactly 3 pairs are
  renamed. 4 new unit tests. THE MORNING TEST CANDIDATE: run
  `.\tools\Build-NativePusfume.ps1 -HeroPreview -ParentChildMaterial` then
  upload; expected result is the full win (character shader + Pusfume atlas
  textures + deformation everywhere the donor apply runs). Workshop item
  deliberately left on the known-good donor-swap build
  (ManifestID 189582177882697334).
- 02:10 Claude: found and fixed a serious regression: the stub/child were
  generated UNCONDITIONALLY, so the "known-good revert" 1125d4f still bundled
  the shadowing stub - its donor swap resolved the stub (standard shader,
  rigid). 1cdcc7b makes generation conditional; clean build re-uploaded
  (ManifestID 189582177882697334) and package verified stub-free. NOTE for
  Sol: any build made from 1125d4f..1c087d1 is silently broken the same way.
- 02:05 Claude: shipped 1125d4f (revert to donor swap + menu preview shader).
  Starting Track A.
