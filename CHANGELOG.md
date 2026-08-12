# Changelog

All notable changes to Pusfume are recorded here. This project follows the
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) structure and uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) once releases are
tagged.

Detailed investigation evidence belongs in the linked GitHub issue and pull
request rather than in release notes.

## [Unreleased]

### Added

- Registered Pusfume as Bardin's fifth synchronized career with Ranger Veteran
  backend, talent, ability, bot-takeover, and loadout adapters.
- Added a full-size Pusfume selector card in the unused virtual row above
  Saltzpyre without shrinking the existing career portraits.
- Added `/pusfume`, `/pusfume_status`, and `/pusfume_preflight` diagnostics for
  registration, backend, UI, package, and spawn validation.
- Added a friends-only Steam Workshop development item with an explicit TEST
  thumbnail and hash-verified deployment workflow.
- Added an optional native third-person Pusfume unit, selector preview,
  reconstructed materials, texture recipes, and package integration.
- Added Blender tooling for four-influence FBX cleanup, handwritten BSI export,
  and a verified animated-character FBX merge.
- Added reverse-engineering, asset-pipeline, provenance, model-handoff, and live
  testing documentation.
- Added a canonical native-character milestone record covering the confirmed
  architecture, build reproduction, live evidence, rejected approaches,
  provenance boundary, and remaining animation work.
- Added source preflight coverage, BSI serialization unit tests, issue and pull
  request templates, CODEOWNERS, and CI patch-hygiene checks.
- Added a `/pusfume_preflight` donor-content check that fails before a live
  test when the Globadier donor package or material cannot resolve, plus
  offline hash verification and the dalokraff donor-material precedent in the
  model handoff documentation.

- Added a state-driven animation controller with a generated placeholder idle:
  the staged state machine defaults to `base/idle`, blends to `base/walk` on
  events, and the mod fires those events from the player's measured speed with
  hysteresis. `/pusfume_preflight` verifies the compiled idle/walk events.

### Changed

- Rebuilt the native atlas from Janfon's original Blender material graph: ammo
  slot A now uses `generic_cloth_dirty_*`, slot B retains
  `pup_ammo_box_limited_*`, eye normal/response regions are neutral, the
  high-polygon Globadier region keeps full source resolution, and safe UV
  insets prevent neighboring atlas cells from bleeding into opaque surfaces.
- Made the opaque atlas diffuse channel ignore source alpha, matching Janfon's
  graph where only the dedicated whisker material uses diffuse transparency.
- Repacked Pusfume's opaque surfaces into a wrap-safe generated atlas and switched
  the proven Globadier character shader to per-unit texture overrides, preventing
  shared material slots from overwriting one another during animated rendering.
- Retired the manual clip sweep from staged builds now that deformation is
  confirmed; the packaged controller owns playback and the sweep remains a
  source-level diagnostic.
- Bound the compiled opaque materials to the generated atlas and switched the
  runtime donor texture restore to the live-verified per-mesh path after
  `Unit.set_texture_for_materials` reported success without changing the
  rendered maps.
- Made the generated idle clearly visible: spine and neck breathing, a head
  nod, and tail sway, with a rejection floor so an imperceptible idle can no
  longer compile.
- Hid Bardin's third-person weapon units while Pusfume is selected in staged
  native builds.
- Stopped `/pusfume_preflight` from failing before the first spawn when the
  donor material is simply not loaded yet.
- Made every menu previewer (character selection and the inventory hero view)
  force the native Pusfume skin instead of the equipped donor Ranger skin,
  hid previewer weapon units, and started the mesh controller after preview
  spawn so the idle plays in menus. An earlier preview-only skin that removed
  `third_person_attachment` crashed `retrieve_skin_packages_for_preview` and
  was replaced by this approach.
- Reached the swapped donor material instances by setting atlas channels on
  every mesh material by index; name-keyed lookups were landing on orphaned
  pre-swap materials. Live testing then proved runtime texture overrides never
  rebind on character materials at all.
- Compiled a child material that inherits the playable Globadier's character
  shader through a hash reference with Pusfume's atlas maps baked in, matching
  the game's own child-material structure byte for byte. Live testing showed
  the compile-required stub parent shadows the game resource inside the mod
  bundle (black rigid body), so the child path is opt-in behind
  `-ParentChildMaterial` until the stub can be stripped from the built bundle.
- Moved the compiled donor-shader child into its own resource package that
  loads strictly after the donor parent package, and taught
  `-ParentChildMaterial` builds to strip the stub parent's bundled identity
  (`tools/strip_bundle_resource.py`) so the child's parent reference resolves
  against the game's copy instead of the shadowing stub.
- Routed the standalone child package through VMF's mod-handle package API
  after the donor parent loads. This avoids the fatal `Application.resource_package`
  lookup used by the global package manager for game-owned bundles.
- Added `/pusfume_material_probe` live A/B modes (`donor_raw`, `donor_atlas`,
  `child`, and alternating-slot `split`) so shader deformation and texture
  behavior can be compared without changing the mesh, controller, or session.
- Added a guarded donor-texture-shadow build experiment that registers the
  Pusfume atlas under the three texture IDs already bound by the game-owned
  Globadier material, preserving its exact shader rather than compiling a
  mod material. `-NoDonorTextureShadow` keeps the previous path available.
- Isolated the shadowed atlas in a standalone VMF package loaded synchronously
  after the donor package. The first shadow test proved that the later-loaded
  donor reclaimed its texture IDs; this reverses that measured load order.
- Added `/pusfume_tint <gradient_variation> [tint_columns_pair]` for live tint
  sweeps: the Globadier's rendered green is shader-applied (its diffuse decodes
  to red/orange with under one percent green), and these are the exact scalars
  the engine's own `CosmeticUtils.color_tint_unit` sets on live character
  materials.
- Corrected the spliced child's slot semantics after the first live test
  glowed: channel statistics of the donor's own maps prove
  `texture_map_27b67fd2` is the EMISSIVE slot (the donor ships a pure black
  map there) and `texture_map_8bf37d8e` is the normal-plus-gloss slot. The
  splice now patches diffuse and normal only and keeps the donor's black
  emissive, so a normal map can never feed the emissive channel again.
- Added compiled-material channel verification to the splice build. The build
  now parses the final 768-byte texture table and aborts unless diffuse points
  to the Pusfume atlas, emissive remains the donor's black map, and normal
  points to the Pusfume normal atlas; the regression suite also proves a
  missing or swapped channel is rejected.
- Neutralized the inherited Globadier `emissive_color` after the corrected
  texture build revealed a green underglow only in dark areas. The donor child
  used a strongly green-weighted `[14.2, 25.3, 2]`; Track D now resolves that
  reflected variable by hash and writes `[0,0,0]` without changing its proven
  skinning payload, diffuse atlas, or normal atlas.
- Established the first live-confirmed native-character baseline: Janfon's
  textured placeholder deforms in the selector and in game, the generated
  idle and Janfon walk cycle transition through the compiled controller, and
  the corrected material renders without the Globadier green underglow.
- Added the `-SplicedGameChild` build (Track D): the compiled child material's
  payload is replaced inside the built bundle with the game's own `mtr_outfit`
  binding table, its three texture ids patched to the Pusfume atlas. The live
  child test showed our child's compile-time shader binding is what breaks
  deformation; the game payload carries the real skinning binding. New
  size-aware splice tooling (`splice_bundle_resource.py`,
  `make_spliced_child.py`) validates the bundle walk, index sizes, and
  payload round-trip. The raw extracted file is never committed, while the
  generated friends-only Workshop bundle embeds the patched binding payload;
  this remains subject to provenance review before wider publication.
- Applied the donor character shader to the menu preview mesh; the preview
  spawned with skinning-incapable compiled materials, which is why the menu
  model never animated even with its controller running.
- Entered the idle controller state explicitly at attach instead of relying on
  default-state auto-entry.

- Made the supported Stingray FBX/DCC importer the default native skin path;
  retained the handwritten BSI path as an explicit diagnostic fallback.
- Changed native builds to merge Janfon's skinned model and baked walk into one
  character FBX and reject the export unless both bones and evaluated vertices
  move.
- Changed the local diagnostic build to assign the installed playable
  Globadier's full-character material at runtime while restoring only Pusfume
  texture maps; extracted game shaders are neither committed nor packaged.
- Isolated development-only animation and skin probes from public source
  defaults so normal builds fail safely when unreviewed assets are absent.
- Limited the current prototype to Adventure Keep and Adventure missions while
  unsupported Chaos Wastes, Weaves, and Versus paths remain locked.

### Fixed

- Prevented crashes caused by unresolved donor weapon loadouts and a missing
  Pusfume career color registry entry.
- Prevented stale Ranger Veteran models and queued package loads from replacing
  the Pusfume selector preview.
- Corrected DCC scene-root attachment so the custom model remains visible.
- Replaced static imported material parents with character-capable skinning
  shader graphs while preserving Pusfume's textures.
- Removed an unsafe experimental animation-layer query that asserted inside the
  Stingray runtime.
- Added the missing compiled unit animation group while preserving all 82 DCC
  skin binds and 86 scene nodes.

### Known Limitations

- The native controller currently covers only idle and walk. Run/sprint,
  crouch, jump/fall, dodge, attacks, ability actions, downed, death, and weapon
  poses remain to be authored and integrated.
- Remote-husk deformation and complete multiplayer synchronization still need
  dedicated live testing; progress remains tracked in
  [issue #6](https://github.com/Ensrick/vt2-pusfume/issues/6) and
  [pull request #11](https://github.com/Ensrick/vt2-pusfume/pull/11).
- The current third-person model and armature are placeholders assembled from
  VT2 Skaven assets and therefore remain outside the public repository.
- Pusfume currently shares Ranger Veteran's equipped items and talents rather
  than maintaining an independent persistent loadout.
- First-person arms, final armature work, custom weapons, and complete
  multiplayer validation are not yet implemented.

[Unreleased]: https://github.com/Ensrick/vt2-pusfume/pull/11
