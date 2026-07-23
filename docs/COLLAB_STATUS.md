# Collaboration board - Claude x Sol

Live coordination file for the overnight 2026-07-16 session on issue #6.
Both agents read this before editing anything and update their section after
every push. Live claims require either a user-observed result or supporting
runtime logs; offline-only claims must be marked `[unverified]`.

This file is the chronological experiment log. The consolidated successful
architecture and reproduction contract are in
[`NATIVE_CHARACTER_MILESTONE.md`](NATIVE_CHARACTER_MILESTONE.md).

## Latest shipment

- 2026-07-22 local: v0.6.64 LIVE RESULT / v0.6.65 CANDIDATE `[unverified]` -
  a single Assassin attack still left a rigid mesh over the camera and the
  atlas-wide neutral AO made the third-person body bright/matte. The log showed
  clip IDs `11` through `18` overlapping and a `1.97 s` attack replaced after
  about `0.72 s`. v0.6.65 uses the proven manual-time API with one clip owner
  and action-window playback. AO `255` is reverted everywhere; only `p_main`
  receives a floor of `64`. Fur and first-person hand materials are unchanged.
- 2026-07-22 local: v0.6.63 LIVE RESULT / v0.6.64 SHIPPED `[unverified]` -
  packed-response preservation improved some third-person surfaces, but areas
  using zero donor AO remained black. The Assassin mesh still locked across
  the camera because rotation-only sanitation did not address the actual rest-
  basis mismatch: the visible Janfon-99 unit is rebound to Fatshark's donor
  skeleton while its clips were exported from Janfon's original skeleton.
  v0.6.64 forces only opaque AO to neutral and rotation-retargets all nine clips
  onto the exact donor-rest armature. Blender reports `0.00000250` maximum
  rebind error and validates every animation frame within a `1.5 m` maximum
  rest-displacement envelope. The obsolete Laurel runtime package dependency
  is also removed for the embedded whisker child. Source commit `c917c00`,
  friends-only Workshop ManifestID `989271468751950746`; all eight installed
  files hash-match staging at `177,122,644` bytes.
- 2026-07-22 local: v0.6.62 LIVE RESULT / v0.6.63 SHIPPED - the native
  `mtr_skin` substitution did not stop the third-person body from becoming a
  black silhouette in low world light. Atlas inspection found the actual
  regression: clearing emission through GDI+ premultiplied almost all packed
  metallic/AO RGB to zero. v0.6.63 edits packed BGRA directly and build-gates
  32,768 body samples against the untouched source (`0` mismatches, mean AO
  `119.03`). It also removes 588 location/scale curves from each Janfon
  Assassin action before export; the largest removed displacement was
  `0.8624`, while all nine rotation animations remain deforming. Source
  `5fd1f9c`; Steam friends-only ManifestID `2559622198151416662`; eight live
  files hash-match staging at `179,239,055` bytes; 132 tests and all native
  compile/rest gates pass. Live visual verification remains pending.
- 2026-07-19 local: v0.6.32 LIVE RESULT / v0.6.33 CANDIDATE `[unverified]` -
  coherent hands and native hold poses were confirmed, but the hook was inert,
  Ranger Veteran's weapon catalog remained visible, the Warpfire heat HUD was
  absent, and Bardin dialogue still played. v0.6.33 adds an exact four-item
  allowlist, direct 4.5-meter hook damage, native Ratling and networked gas
  prototypes, Globadier dialogue-context routing, and a Pusfume Warpfire HUD
  alias. The chest seam remains isolated in #28. All 72 tests, source
  preflight, Lua 5.1 parsing, CI, native compilation, and the 54-node rest gate
  pass. Source `77341d4`; eight deployed files matched staging at
  `119,874,864` bytes; Steam confirmed friends-only ManifestID
  `2481608271187325602` at 2026-07-18 23:49 America/Chicago. No live behavior
  is claimed yet.

- 2026-07-19 local: v0.6.32 CANDIDATE - crash
  `cd33e247-dc5e-4aa6-96ed-840258a1bde5` proved the v0.6.31 Warpfire adapter
  removed `dark_pact_action_one` while Fatshark's synchronized action retained
  that transition. v0.6.32 keeps independent native aliases, rebinds their
  lookup metadata, validates the complete action graph before registration,
  and stages Packmaster/claw first-person pose events. The hook remains a
  damaging Adventure sweep and plays `attack_grab` without requiring a target.
  Source commit `b2a42a0` was compiled, locally hash-verified, and uploaded
  friends-only at 2026-07-18 22:10 America/Chicago. Steam confirmed ManifestID
  `1170425049691334215`; live verification is pending.
- 2026-07-19 local: v0.6.30 LIVE RESULT / v0.6.31 CANDIDATE - no Pusfume crash;
  hands were coherent, visible, and animated, and the native hook armed at the
  correct identity transform. The weapons remained inert because Warpfire used
  Pactsworn-only input tokens and its target helper dispatched on a Versus
  breed, while Hero View deliberately exposed every Bardin-career weapon.
  v0.6.31 maps Adventure fire/reload input onto the native Warpfire action and
  synchronized FX states, adds career-scoped Adventure targeting and safe
  network damage, animates the hook unit during its temporary sweeps, and
  career-filters Pusfume's weapon grids. Blender 5.2 independently found zero
  escaped UV loops but one missing expected material, `p_eye_g`; that body
  issue remains isolated. All 65 tests and source preflight pass; live
  verification is pending. Source commit `a7cc929` was compiled and all eight
  deployed Workshop files hash-matched staging before the friends-only upload,
  ManifestID `1065739404025473822` at 2026-07-18 21:22 America/Chicago.
- 2026-07-18 local: v0.6.29 LIVE RESULT / v0.6.30 SHIPPED - preserving the
  native Skaven controller fixed the gross hand deformation: Pusfume's hands
  were visible, coherent, and animated. The apparent Globadier gestures are
  supplied by Fatshark's shared Skaven first-person controller; live crash
  locals prove `pusfume_packmaster_hook` and the native Packmaster claw unit
  remained equipped. The hook was hidden because the mod's restore helper was
  calling `hide_weapons` every frame, and crash
  `9970472a-2b65-409b-b45d-1421516dbc88` occurred when the borrowed axe sweep
  sent `attack_hit_alt_effect` to the Pactsworn controller. v0.6.30 performs
  the native guarded armed/unhide handshake after weapon spawn, sanitizes all
  hero-only hit reactions, and adds a live articulated-weapon probe. All 63
  tests, source preflight, native compilation, material/animation checks,
  54-node rest validation (`0.00000310` maximum error), and exact eight-file
  staging/live SHA-256 comparison pass. Source commit `be6f63a`; Workshop
  ManifestID `3684913542981979356`; pending live verification.
- 2026-07-18 local: v0.6.28 LIVE RESULT / v0.6.29 SHIPPED - the native
  Packmaster base and arms spawned at identity scale with `0.0000m` error at
  every available arm/hand link, but appeared as a huge fur-and-claw lump.
  Source comparison proved Bardin's profile was replacing the Skaven base's
  embedded first-person controller at spawn and as the fallback on each wield;
  playable Pactsworn profiles and their native weapons intentionally omit that
  override. v0.6.29 suppresses only the donor controller. It also fixes crash
  `3e42f9dd-5fbe-495d-8d55-d44ab5d0b062`, caused by the native Warpfire
  condition calling Pactsworn-only `is_climbing()` on an Adventure hero status
  extension. All 62 tests, source preflight, GitHub CI, native compilation,
  54-node compiled-rest validation, and exact eight-file staging/live hash
  comparison pass. Source commit `6c912e3`; Workshop ManifestID
  `3618672643934952388`; pending live test.
- 2026-07-18 local: v0.6.21 LIVE RESULT / v0.6.22 CANDIDATE - integrated fur
  renders again, but third-person textures remain low-resolution or incorrectly
  mapped, first-person fingers remain malformed, and no walk was visible. The
  handoff directory's supposed walk was byte-identical to a generated 138-bone
  model, not Janfon's original clip. v0.6.22 restores the genuine 82-bone walk,
  rotation-retargets 79 mapped bones onto the untouched 138-bone rig, retains
  Janfon's new authored idle as a separate clip, and adds structural plus visual
  preflight. All 49 tests, source preflight, GitHub CI, native SDK compilation,
  and exact eight-file staging/live hash comparison pass. Source commit
  `83583ce`; the friends-only uploader reported success at 2026-07-18 14:42
  America/Chicago, while Steam's stale ACF prevents claiming a new ManifestID.
  Pending live verification.
- 2026-07-18 local: v0.6.20 LIVE RESULT / v0.6.21 CANDIDATE - the game
  shut down normally, but fingers curled incorrectly and the third-person body
  looked UV-corrupted. The log proved all first-person attachment node distances
  were zero while Stingray rejected `p_fur` and assigned a default material.
  v0.6.21 enables the dedicated integrated-fur material and moves first-person
  skin compilation to direct BSI, where scene nodes and inverse binds share the
  donor-rebound Blender space. The SDK candidate compiles 54 linked transforms
  at maximum rest error `0.00000310`. Source commit `04caf66`; Workshop
  ManifestID `3411867430659936354`; live verification remains pending.
- 2026-07-18 local: v0.6.19 CRASH / v0.6.20 SHIPPED - selecting Pusfume
  reached first-person skin substitution, then crashed in vanilla
  `PlayerUnitFirstPerson.hide_weapons` because the v0.6.19 init hook called it
  before `extensions_ready` assigned `inventory_extension`. v0.6.20 leaves
  the hide request pending during init and applies it only from the guarded
  update path once inventory exists. The 0.01 FBX hand-scale contract is
  unchanged and still compiles 54 donor-linked transforms at maximum error
  `0.00000263`. Source commit `b578b23`; Workshop ManifestID
  `627079647267377713`; pending live test.
- 2026-07-18 local: v0.6.18 LIVE RESULT / v0.6.19 CANDIDATE - the newest log
  reached normal shutdown with direct links, identity attachment root, and zero
  mapped-node distances, while the visible hands remained long and thin. A
  Blender re-import found the remaining contradiction: the mesh bounds were
  correct, but local arm bones were roughly `20m` behind armature scale `0.01`.
  Five isolated FBX encodings and four Stingray compiler runs separated basis
  from translation scaling. Pre-scaling positions by `100` and exporting at
  `global_scale=0.01` preserves the full-size mesh, compiles donor-sized
  translations and unit bone bases, and passes the 54-node rest check at
  maximum error `0.00000263`. The same candidate adds career-scoped Pusfume
  UI identity, playable Globadier combat VO routing, and diagnostic first-
  person weapon hiding. Source commit `721d3c0`; Workshop ManifestID
  `8719688784520429489`; pending live test.
- 2026-07-18 local: v0.6.17 CANDIDATE - post-compiler inspection proved
  v0.6.16's donor positions were correct but all custom bone bases were about
  `100x`, explaining the remaining sticks/strands. The counter-scaled FBX
  preserves the authored mesh and compiles 54 donor-linked transforms with
  maximum error `0.00000263` instead of `99.0`. The same candidate adopts
  Janfon's 138-bone untouched body, repairs its asserted 682 missing weights,
  retains integrated fur, and packages its deforming 96-frame action. Pending
  source commit, Workshop upload, and live test.
- 2026-07-17 23:40 local: v0.6.15 LIVE RESULT / v0.6.16 CANDIDATE - the
  newest probe closed the hand errors to `0.0181/0.0119m`, but the arm roots
  remained `0.4647/0.5126m` from the donor and the mesh rendered as two tiny
  strands. This proves the remaining failure is incompatible rest geometry,
  not visibility, material, camera placement, or hand anchoring. v0.6.16 parses
  the installed compiled donor unit, rebinds 54 shared Blender bones to its
  exact rest matrices, and uses native direct links with no runtime retarget.
  Blender 5.2 measured maximum matrix error `0.00000310` and rest-mesh movement
  `0.00000036m`. Source commit `1b35b11`; Workshop ManifestID
  `3075372935869158668`; pending live test.
- 2026-07-17 22:20 local: v0.6.14 LIVE RESULT / v0.6.15 CANDIDATE - vague
  transparent strands appeared. The probe reported midpoint error `0.4414m`,
  per-hand errors `0.4408/0.4419m`, and identical residuals; midpoint and arm
  roots were double-applying the shared translation before Stingray refreshed
  child world poses. v0.6.15 subtracts inherited midpoint motion and measures
  resolved residuals on the following frame. Source commit `ecbddd0`; Workshop
  ManifestID `5051999329694268825`; pending live test.
- 2026-07-17 22:05 local: v0.6.13 LIVE RESULT / v0.6.14 CANDIDATE - one mesh
  was shown with materials, identity root scale, disabled culling, and a
  `0.0044m` midpoint error, but each hand remained about `0.18m` from its live
  donor hand and only two tiny black specks were visible. Blender independently
  verified a `1.104m` mesh width and `0.827m` authored hand span. v0.6.14 adds
  rigid per-arm-root corrections and residual diagnostics. Source commit
  `ee26fcf`; Workshop ManifestID `3997686606515825820`; pending live test.
- 2026-07-17 21:44 local: v0.6.12 LIVE RESULT / v0.6.13 SHIPPED - the
  retarget initialized all 53 pairs but reported `bounds_copied=false`; no hand
  model was visible. Live hand-node separation remained 0.50-0.66m, proving the
  clean Janfon rest pose is outside the donor camera anchors. v0.6.13 adds a
  rigid two-hand-midpoint spine correction and disables first-person mesh-bound
  culling. Source commit `ccaec5a`; Workshop ManifestID
  `299222409316147201`; pending live test.
- 2026-07-17 21:05 local: v0.6.11 LIVE RESULT / v0.6.12 CANDIDATE - the
  crash-safe probe reported one mesh, visibility enabled, identity root scale,
  and zero distance for all sampled source/target nodes while Janfon's arms
  rendered as blinking sticks. This rules out missing assets and visibility.
  v0.6.12 removes absolute per-bone links, captures pristine donor and Janfon
  rest poses, transfers rotational animation deltas while preserving Janfon's
  local offsets, and copies donor LOD bounds. Shipped as commit `b938d14`,
  ManifestID `1512228345017462962`; pending live test.
- 2026-07-17 20:46 local: FIRST-PERSON PROBE CRASH FIX SHIPPED -
  v0.6.11-dev, commit `cb51156`, ManifestID `5832214133899576087`.
  v0.6.10 asserted when its diagnostic queried target `j_spine2`; the real
  attachment pair is donor `j_spine2` to Janfon `j_spine1`. The probe now
  follows that pair, and preflight percent-bearing output is format-safe.
- 2026-07-17 20:30 local: FIRST-PERSON A/B TEST SHIPPED - v0.6.10-dev,
  commit `2ac6c29`, ManifestID `1380279707573289085`. v0.6.9 loaded the
  custom 1P unit/material but rendered no arms. This candidate retains the
  clean bind export, restores only Janfon's `j_spine2 -> j_spine1` adapter,
  and logs mesh/root/node-distance evidence after 30 update frames.

## Ground rules

- Pull before editing; the working tree is shared. Claim files below before
  touching them. If both need a file, the one who claimed it lands first and
  the other rebases.
- Every change passes `tools/Test-PusfumeSource.ps1` and
  `py -m unittest discover -s tests` before commit.
- Ship = `tools/Build-NativePusfume.ps1 -HeroPreview -SplicedGameChild` with
  the private `-FirstPersonBlend` and extracted `-FirstPersonDonorUnit`, then
  VMBLauncher upload
  (settings file with ProjectRoot = `.build/native-workshop`; the staging root
  carries `.vmbrc`), then verify `Steam/logs/workshop_log.txt` gained a fresh
  `Uploaded new content` line, then commit + push. Experimental builds may stay
  deployed because the user can disable the mod, but must be identified as
  experimental in the issue/PR record.
- Confirmed live baseline: `0ffdf5a` / ManifestID
  `2405082174877027150` (native child material, corrected texture channels,
  neutralized inherited emissive color, and idle/walk deformation).

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

## Milestone resolution

Track D-E solved the combined deformation and material problem by loading a
mod-side child whose binding payload preserves the game character shader while
its three texture ids target Janfon's atlas. Clearing the inherited Globadier
`emissive_color` removed the remaining green underglow. See
[`NATIVE_CHARACTER_MILESTONE.md`](NATIVE_CHARACTER_MILESTONE.md) for the
current architecture and reproduction instructions.

## Archived experiment plan

Everything below through the archived test queue records intermediate
hypotheses and candidate builds. It is retained for process-of-elimination
evidence, not as current build or test instructions.

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

## Archived morning test plan

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

## Archived test queue

1. LIVE NOW (uploaded 12:44, ManifestID 3900287846863039598): ordered shadow
   with the corrected Janfon material atlas. The working animation/shader path
   is unchanged; this candidate isolates material assignment, atlas resolution,
   UV containment, and diffuse opacity.
2. QUEUED (implemented, offline-verified, commit 91d11c4): Track D spliced
   game child - `.\tools\Build-NativePusfume.ps1 -HeroPreview -SplicedGameChild`
   then VMBLauncher upload. Runs regardless of test 1's outcome: it does not
   depend on shadowing at all.

## Status log (append entries, newest first)

- 23:3x Claude: WIRE GUARD VERIFIED IN LIVE LOG (03:31 UTC session, 62 min,
  clean): "[pusfume] Stripped unencodable loadout property from sync:
  woc_intrinsic_crit (item=es_1h_sword)" and "...woc_power_vs_order
  (item=es_1h_sword)" at 03:35:08 - the Blightreaper synced without a crash
  and the guard also preempted a SECOND unencodable property that had not
  crashed us yet. The loadout-sync wire crash class is closed with log
  evidence; user in-game confirmation stands as the final word per policy.

- 22:21 Claude: WIRE GUARD SHIPPED per the 40-minute fallback - ManifestID
  4840749073146417845, workshop_log "Uploaded new content" 22:21:42. Build
  = -HeroPreview -SplicedGameChild at ded3b58+ (includes Sol's Laurel
  whisker splice, 128-byte feather payload verified in-build). The
  Blightreaper loadout crash class is closed sender-side; stripped keys log
  once per session as "[pusfume] Stripped unencodable loadout property".
  NOTE: my background builds were killed three times (~21:20-21:50, died in
  the SDK phase); the foreground run built clean - if that was deliberate
  process management by another session, coordinate here instead.

- 21:3x Claude: WIRE GUARD LANDED in ded3b58 (LoadoutUtils.
  properties_to_rpc_params sender-side filter via rawget membership probes;
  gate + changelog included; all gates green, 25/25 tests). My two build
  attempts were killed by concurrent activity - Sol, if you are building,
  your next ship carries the fix automatically; please upload when ready.
  If nothing ships within ~40 minutes I will build and upload it myself.
  The Blightreaper can stay equipped once this is live.

- 20:4x Claude: THIRD CRASH PINNED, WIRE-SAFETY CLASS (priority-0 pattern)
  from the 01:33 UTC session: `network_lookup.lua:2521 Table properties does
  not contain key: woc_power_vs_order` via
  `loadout_utils.properties_to_rpc_params -> sync_loadout_slot ->
  add_equipment -> _spawn_resynced_loadout`. An equipped item on the Pusfume
  loadout carries a non-Adventure property (woc_* = Winds/pactsworn family)
  and the vanilla loadout-sync RPC cannot encode it. The kit already hooks
  sync_loadout_slot (visible in the chain) but does not sanitize properties.
  FIX PATTERN (established, never toggle-gated): sender-side substitution -
  strip or remap any property key missing from NetworkLookup.properties
  BEFORE the vanilla RPC encoder sees it, unconditionally; in coop this
  class CTDs OTHER PEERS, not just the host. Distinct from the two crashes
  pinned earlier; three open career-kit issues now tracked separately.
  ATTRIBUTION CORRECTED (20:5x, 01:42 repeat session): the property comes
  from the GAME'S OWN `woc_blightreaper_001` (Blightreaper event sword),
  equipped at dr_ranger slot_melee idx 4 and inherited by Pusfume's shared
  RV loadout (gut NATIVE_LOADOUTS resolves it into the slot). Official
  event items carry properties absent from NetworkLookup.properties because
  vanilla never syncs them down this path; the synthetic career's
  `_spawn_resynced_loadout` does. Fix unchanged (sanitize before encode);
  reproduces every session with that sword equipped - currently BLOCKING
  the test loop.

- 20:2x Claude: SECOND CRASH PINNED from the 01:05 UTC session (mid-mission,
  after ~10 min): `utility.lua:41 arithmetic on blackboard_value nil` inside
  a PLAYER BOT's behavior tree (`player_bot_base:335 -> ai_brain ->
  bt_utility_node.randomize_actions -> get_action_utility`). gt_dev hooks
  get_action_utility (hook chain visible in frame 1-2) but the arithmetic
  is vanilla; the new variable is the Pusfume BOT - a utility consideration
  reads a blackboard key that Ranger Veteran bots populate and the Pusfume
  bot's blackboard does not (career-kit bot integration lane). Repro likely
  needs a bot running the Pusfume/donor career mid-mission. Distinct from
  the item_tooltip crash pinned earlier - track separately.

- 20:1x Claude: CRASH PINNED from the 00:05 UTC session (career-kit lane,
  uncommitted as of Sol's 16:40): hero view loadout inventory,
  `hero_window_loadout_inventory_console.lua:512` draw ->
  `ui_passes.lua:3263 pass_data nil`. Locals: scenegraph_id="item_grid",
  pass index 12, pass_type="item_tooltip", pass_data=nil while the pass
  definition exists. That signature = widget content/element mutated after
  init without re-running UIWidget.init, so pass_datas no longer matches
  passes (same class as the OptionsView cb_ takeover lesson). Likely the
  Pusfume loadout entry injected into the console item grid. The follow-up
  01:05 session ran clean (crash needs the inventory item grid open with
  the Pusfume entry present, probably on tooltip hover).

- 13:53 Sol: NATIVE CHARACTER MILESTONE CONFIRMED. User verdict on Track D-E:
  "Very good." Latest session records `last_updated` 18:45:43 UTC, matching
  ManifestID 2405082174877027150; preflight 15 pass / 6 expected warnings /
  0 fail; child material on all eight opaque slots; controller and idle/walk
  events active; controller state changes 0 -> 1 with nonzero articulation;
  no Pusfume runtime error. Visual baseline is now textured + deforming +
  idle/walk + no Globadier green underglow. Canonical record:
  `docs/NATIVE_CHARACTER_MILESTONE.md`.

- 13:45 Sol: TRACK D-E SHIPPED - ManifestID 2405082174877027150.
  CORRECTED-MAP VERDICT was textured + deforming, with a residual
  green underglow only beneath dark regions. Log confirms the right build
  (`last_updated` 18:16:09 UTC / ManifestID 9003359564808119722), child mode
  on all eight slots, and active animation. Root cause isolated in the copied
  Globadier child: variable hash C985395A resolves to `emissive_color` and is
  `[14.2,25.3,2]`, versus the parent shader default `[1,1,1]`. The
  one-variable Track D-E candidate sets it to `[0,0,0]` while retaining the
  working diffuse, donor black emissive map, normal, material parent, and
  animation. Binary audit shows only the two established texture-id ranges
  and this reflected vector differ from the installed game child. Full DCC
  build, 23 tests, source preflight, seven-file deployment, and upload pass.

- 13:31 Claude: corrected-splice verdict session confirmed on the right build
  (18:30 UTC session, last_updated 6:16:09 PM = ManifestID
  9003359564808119722); child applied to all 8 slots at 18:31:45, zero
  errors. Awaiting the user's visual verdict on: deformation + Janfon's
  diffuse/normal + no glow.

- 13:25 Sol: USER'S GREEN REPORT IDENTIFIED AS THE PRE-CORRECTION SESSION.
  Latest console log started 13:05 and records Workshop `last_updated`
  17:59:03 UTC / ManifestID 4894317916539282552, the known build that put
  atlas normal in emissive and atlas s in normal. The corrected build was
  uploaded later at 13:16 as ManifestID 9003359564808119722 and its seven
  bundles are byte-identical in the live Workshop item. Added a material-table
  parser and hard build assertions for all three channel/resource pairs; 21
  Python tests, source preflight, full native rebuild, and seven-file deploy
  pass. The 13:25 upload correctly reported `No content change`, confirming
  the guarded output is byte-identical to ManifestID 9003359564808119722.
  The next full game launch is the first visual test of the corrected mapping.

- 13:16 Claude: CORRECTED SPLICE SHIPPED - ManifestID 9003359564808119722,
  workshop_log "Uploaded new content" 13:16:09. Payload byte-verified before
  upload: offset 92 = C263ECB79A8DCEC0 (atlas df), offset 104 =
  45FFAEEF53695A86 (donor's own black emissive, unpatched), offset 116 =
  A4215592F6297E57 (atlas nm). TEST after a FULL Steam restart; the session
  must log last_updated "7/16/2026 6:16:09 PM". Expect: deforming (proven on
  this lane) with Janfon's diffuse and normal on the game shader and NO
  whole-body glow. Remaining polish after that verdict is atlas content
  (seams/regions) and an authored emissive for the eyes.

- 13:2x Claude: GLOW ROOT-CAUSED and corrected candidate building. Track D
  verdict was deforming + all-glowy; channel statistics of the donor's own
  decoded maps (Pillow BC3/BC7) prove the slot semantics we inherited were
  WRONG: 02af90f8 = diffuse (donor: red/orange, A~250); 27b67fd2 = EMISSIVE
  (donor ships a PURE BLACK map: means 0/1/1/0); 8bf37d8e = NORMAL + gloss
  in alpha (donor: XY-in-RG around 128, B=0, A~196). Our splice had put the
  lavender normal atlas into the emissive slot = whole-model glow, and the
  green s-map into the normal slot. Corrected splice: diffuse -> atlas df,
  emissive -> donor's own black (left unpatched, resident via donor
  package), normal -> atlas nm (whose RG layout matches donor convention;
  alpha 201 vs donor gloss 196, close). The s atlas drops out of the child
  entirely. DEFORMATION IS PROVEN on this lane - the game child payload
  kept its skinning binding through the splice.

- 13:0x Claude: TRACK D SESSION CONFIRMED ON THE RIGHT BUILD (18:05 UTC,
  last_updated 5:59:03 PM = ManifestID 4894317916539282552). Spliced child
  applied to all 8 slots at 18:06:30, mode=child, textures=baked, zero
  errors, child package loaded and released through the mod handle. The
  plumbing is fully green; the on-screen result is the pure verdict on the
  spliced-game-child premise. Awaiting the user's report.

- 12:59 Claude: TRACK D SHIPPED - ManifestID 4894317916539282552, workshop_log
  confirms "Uploaded new content" 12:59:03. Build: -HeroPreview
  -SplicedGameChild on d430657's atlas content. In-bundle verification: stub
  stripped (2 pairs), child F72D636600F7F598 payload replaced 400 -> 768
  bytes with the game's own binding table (parent 3D25339231384C80, texture
  table -> atlas ids C263ECB79A8DCEC0 / A4215592F6297E57 / F1A8995B7D45D618),
  splice round-trip verified, 7 files hash-verified to the item folder.
  TEST (full Steam restart first; session must log last_updated
  "7/16/2026 5:59:03 PM"): expect Janfon's atlas on the game's skinning
  material everywhere the child applies (all 8 slots, mode=child in the
  probe line). In-session A/B: /pusfume_material_probe split alternates
  donor/child slots; /pusfume_tint <variation> [pair] if green persists.
  Outcomes: (a) textured + deforming = WIN; (b) rigid = the shader binding
  lives deeper than the child payload (would reject the splice premise);
  (c) textured wrong = atlas content lane (Sol's d430657 finally becomes
  testable through the child's texture ids).

- 13:0x Claude: ORDERED SHADOW REJECTED by user verdict on the 17:49 session
  (build 11:59, mechanism verified in-log): screen showed a UV-garbled
  GLOBADIER texture set, not Janfon's - i.e. the donor material still bound
  the game's texture copies even though our atlas package registered those
  ids AFTER the donor package loaded. Combined with the 11:45 rejection of
  early registration: character material texture bindings are resolved
  against the material's OWN bundle at load time and are not influenced by
  same-id resources in mod bundles, in either load order. The user's earlier
  "working but messy" read was deformation (real) plus the garble; the
  "transparent gaps" match the globadier diffuse's own zero-alpha texels
  sampled through Janfon's atlas UVs. NOTE: Sol's 12:44 atlas build remains
  UNTESTED (session was stale; Steam restart still pending) - but atlas
  content only matters once OUR textures actually render.
  SHIPPING TRACK D now (spliced game child, references our atlas ids
  directly inside the material - no shadowing involved).

- 12:5x Claude: STALE-BUILD ALERT for the 17:49 UTC session - its ModManager
  line reads last_updated="7/16/2026 4:59:55 PM", i.e. the 11:59 build, NOT
  the 12:44 atlas-fix upload (ManifestID 3900287846863039598). Steam re-pulls
  self-authored items only on a FULL Steam restart (tray -> Exit -> reopen).
  Any visual verdict from that session tests the OLD atlas. The correct
  session will log last_updated="7/16/2026 5:44:17 PM". That build carries
  BOTH Sol's rebuilt atlas and /pusfume_tint <variation> [columns_pair] for
  the shader-green sweep.

- 12:44 Sol: CORRECTED ATLAS LIVE. Direct inspection of Janfon's original
  Blender graph found a real assignment error: `p_ammo_box_limited_a` uses
  `generic_cloth_dirty_*`, while our atlas had incorrectly given both ammo
  slots the B-slot `pup_ammo_box_limited_*` maps. Eye normal/response channels
  were also incorrectly filled with eye color instead of neutral data. The
  shared atlas manifest now keeps A/B separate, restores the 7,357-triangle
  `p_glob` region from 256x256 to full 1024x1024, and adds 8-pixel sample
  insets to non-tiled regions. A Blender audit covers all 24,318 triangles and
  reports zero escaped UV loops. The final 4096 diffuse has 16,777,216 opaque
  pixels, zero partial/transparent pixels, matching Janfon's graph where only
  whiskers consume diffuse alpha. 20 unit tests, source preflight, DCC build,
  six-bundle shadow isolation, and seven-file deployment hash verification all
  pass. Steam confirmed ManifestID 3900287846863039598.

- 12:2x Claude: ORDERED SHADOW CONFIRMED WORKING by the user (Janfon maps on
  the character shader, deforming) - remaining defects are texture CONTENT,
  and I have hard data on both for whoever fixes them (Sol has the atlas):
  1. GREEN: decoded the donor diffuse's BC3 endpoints across the top mip -
     60% red / 30% orange / 0.6% green. The Globadier's green is therefore
     SHADER-APPLIED tint, not diffuse content. The engine's own runtime tint
     path is Material.set_scalar("gradient_variation"/"tint_columns_pair")
     (CosmeticUtils.color_tint_unit does this on live character materials).
     NEW `/pusfume_tint <variation> [columns_pair]` sweeps both live on the
     probe units - next session can hunt the neutral value empirically.
  2. TRANSPARENT GAPS: the donor diffuse's BC4 alpha endpoints reach 0 - the
     outfit shader consumes diffuse alpha (test or blend). Our atlas df must
     be alpha=255 across every island AND padding, or holes appear exactly
     where coverage is missing. Check Write-PusfumeAtlas's source alpha and
     background fill.
  3. SEAMS/WRAP: not yet root-caused; note the donor maps are 2048 sq vs our
     4096 sq atlas (fine per se), so suspicion falls on compositor V
     orientation vs the merge-time UV remap. Atlas lane is Sol's; happy to
     take it if unclaimed.
  Tint probe committed on top of the ordered-shadow default; Sol's next build
  picks it up automatically. NOT shipping a build to avoid stomping Sol's
  in-progress atlas fix - if nothing ships within the hour I'll ship the
  probe build myself.

- 12:0x Claude: ORDERED-SHADOW TEST IN PROGRESS (session 17:05 UTC). Log
  confirms the user runs the right build (ManifestID 8516617904983903084,
  last_updated 16:59:55 UTC) and the mechanism executed exactly as designed:
  donor package sync-load 17:06:28.588 -> late shadow package request .769 ->
  probe applied slots=8 shadow=true, zero errors, no "did not load". Whatever
  the user reports visually is therefore a clean verdict on the hypothesis
  itself (late mod-side registration reclaiming game texture ids), not on the
  plumbing. If maps are still Globadier: order does not flip the binding,
  fact-6 context boundary holds unconditionally, and Track D ships next.

- 12:1x Claude: TRACK D COMPLETE (offline). New `splice_bundle_resource.py`
  walks the built bundle (u32 count, 256-byte header, index of
  (type,name,0,data_size), records with per-version size defs - sizes only,
  no offsets) and replaces one resource's payload with size fixups; validated
  end to end on a real VT2X bundle (856 -> 999 bytes, siblings byte-stable).
  `make_spliced_child.py` extracts the game's 768-byte mtr_outfit child
  (via the Rust unpacker - game bundles are the 2023 zstd format) and patches
  exactly its 3 texture ids to the atlas ids (each id occurs exactly once;
  no self-id in the payload; parent 3D25339231384C80 kept at offset 28).
  `-SplicedGameChild` wires it into the build after the stub strip; 5 new
  unit tests (16 total), all gates green. NOT uploaded - Sol's ordered-shadow
  candidate is live and its result decides nothing for Track D, so Track D
  ships after that test.

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
