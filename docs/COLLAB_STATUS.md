# Collaboration board - Claude x Sol

Live coordination file for the overnight 2026-07-16 session on issue #6.
Both agents read this before editing anything and update their section after
every push. Live claims require either a user-observed result or supporting
runtime logs; offline-only claims must be marked `[unverified]`.

## Ground rules

- Pull before editing; the working tree is shared. Claim files below before
  touching them. If both need a file, the one who claimed it lands first and
  the other rebases.
- Every change passes `tools/Test-PusfumeSource.ps1` and
  `py -m unittest discover -s tests` before commit.
- Ship = `tools/Build-NativePusfume.ps1 -HeroPreview`, then VMBLauncher upload
  (settings file with ProjectRoot = `.build/native-workshop`; the staging root
  carries `.vmbrc`), then verify `Steam/logs/workshop_log.txt` gained a fresh
  `Uploaded new content` line, then commit + push. Experimental builds may stay
  deployed because the user can disable the mod, but must be identified as
  experimental in the issue/PR record.
- Deployed experimental candidate: `f169b07` / ManifestID
  `8845324977482480470` (ordered parent-child material test).

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
8. The ordered child package now resolves and applies successfully, but it
   renders dark and rigid. The 16:23 live log proves the controller entered
   state 1 and Janfon's source bones articulated while the child occupied all
   eight surfaces. Parent lookup is solved; the compiled child's shader
   permutation still does not perform GPU skinning.

## The one remaining core problem

Bind Janfon's atlas to the exact game-owned `mtr_outfit` material while keeping
that material's proven skinning permutation. The child-inheritance route is
now empirically rejected; current work compares live material modes and tests
whether controlled resource-hash shadowing can replace only donor textures.

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

## Morning test plan (for the user)

1. First launch: current Workshop build (known-good donor swap). Expect:
   walk + idle deforming in game, menu previews animated with donor maps,
   weapons hidden in game and in menus. If menus are still rigid, that build's
   `Menu previewer native controller enabled` + donor apply log lines tell us
   which half failed.
2. The FULL-WIN candidate: run
   `.\tools\Build-NativePusfume.ps1 -HeroPreview -ParentChildMaterial`
   then upload via VMBLauncher. Expect: Pusfume's own atlas textures on the
   character shader, deforming, everywhere. The stub is stripped from the
   bundle (offline-verified: fresh candidate build strips 2 identity pairs
   from the child-package bundle, zero remain across all 6 bundles) and the
   child package loads strictly after the donor parent package.

## Track C - donor texture shadowing [CLAIMED: Claude, 2026-07-16 morning]

The user-requested direction: keep the proven donor material swap and make it
sample OUR maps by shadowing the game's texture ids. Evidence base, all parsed
from the game's own bundle `7a8e617a32277fc4` (the donor package's bundle;
bundle filename = Murmur64 of the anchor package path):

- The game's compiled `mtr_outfit` (`90BDF3BAC6F81BA8.material`, 768 bytes)
  stores parent `3D25339231384C80` at offset 28 and a texture table of
  12-byte `(u32 slot_key, u64 texture_id)` entries at offsets 88..127.
- The slot keys are `IdString32("texture_map_<suffix>")` - the generated slot
  NAMES hash back to the table keys (F9292771/909D00F3/9AD51991). Confirmed.
- Donor texture ids: diffuse `DD74D8319F514D96`, normal `45FFAEEF53695A86`,
  packed response `E334A8CB6BCB5E6D`.

Mechanism: `strip_bundle_resource.py --bare --new-hash` renames every 8-byte
occurrence of our atlas texture name hashes to the donor ids across all built
bundles (index, file header, package listing, and our own compiled materials'
references stay mutually consistent). Our main package registers those ids at
mod boot, before the donor package loads at first spawn, so the game's
`mtr_outfit` binds Janfon's atlas - the same first-loaded-wins precedence the
black-rigid-body stub incident proved live. Runtime Lua texture restore is
skipped in shadow builds (`donor_texture_shadow` config); the atlas resources
no longer exist under their old paths, and those calls never rebound anything
anyway. Opt-out: `-NoDonorTextureShadow`.

Known tradeoff: anything else rendering the dark-pact Globadier `skin_1001`
outfit samples Janfon's atlas with Globadier UVs (garbled). Dev-acceptable.

## Track D - spliced game child material [CLAIMED: Claude, 2026-07-16 ~12:00]

Every ingredient is independently live-proven; this recombines them:

1. Take the GAME's compiled `mtr_outfit` child (768 bytes, extracted at build
   time from installed bundle `7a8e617a32277fc4`, never committed).
2. Patch exactly its three texture ids (offsets found by searching the donor
   ids) to OUR atlas texture ids.
3. Splice those bytes over our SDK-compiled child's payload inside the built
   bundle (new tool: size-aware resource payload replacement - the bundle
   index stores sizes, not offsets, so records after the splice just shift).

Why this should render skinned AND textured where every prior candidate
failed one half:
- The 11:45 live test eliminated cross-context shadowing: game-package loads
  bind game copies (globadier maps persisted through a verified id rename in
  our bundles). Mod-context loads DO see mod resources (black-body stub).
- Sol's 11:24 live test showed our SDK child renders (parent chain resolves
  from mod context) but rigid/dark - the shader binding baked at compile time
  from the STUB is what kills deformation. The spliced payload carries the
  game's own compile-time binding: the real skinning permutation.
- The texture ids in the spliced child are OUR atlas ids, loaded mod-side at
  boot; the child itself loads mod-side (mod-handle package) - same side, so
  resolution follows the proven mod-context rule.
- Donor package still loads first (Lua ordering unchanged), so the parent's
  shader library is resident before the child binds.

Build: `-SplicedGameChild` (implies the -ParentChildMaterial staging, forces
the texture shadow OFF - one variable at a time).

## Fact 6 refinement (2026-07-16 11:45 live test)

Bundle-resource shadowing is CONTEXT-BOUND, not global: a resource loaded
through a GAME package binds the game bundle's copy even when a mod bundle
carries the same (type, name) - the verified donor-texture-id rename changed
nothing on screen. A resource loaded through a MOD package binds the mod
copy (stub incident). Corollary: you cannot override game texture content
from a mod bundle for game-loaded materials; overrides must ride a material
that itself loads mod-side.

## Status log (append entries, newest first)

- 11:24 Sol: LIVE RESULT for `f169b07` / ManifestID
  `8845324977482480470`: VMF loaded `native_child`; all eight child slots
  applied; no package crash. Pusfume rendered very dark and visibly rigid.
  Runtime probe simultaneously recorded controller state 0 -> 1, hips/hand
  motion, and articulation on Janfon's mesh. This rejects package order and
  clip playback as causes and isolates the deformation loss to the child
  material/shader permutation. Preparing `/pusfume_material_probe` modes for
  same-session donor/child/split A/B testing.
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
