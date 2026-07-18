# Changelog

All notable changes to Pusfume are recorded here. This project follows the
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) structure and uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) once releases are
tagged.

Detailed investigation evidence belongs in the linked GitHub issue and pull
request rather than in release notes.

## [Unreleased]

### Changed

- Replaced the failed first-person runtime translation/retarget experiment with
  an offline exact-rest rebind. v0.6.15's latest live probe placed each hand
  within `0.0181/0.0119m` of the donor while the shoulder roots remained
  `0.4647/0.5126m` away, empirically explaining the two stretched strands.
- Added a guarded parser for VT2 version-189 compiled unit scene graphs. The
  private build reads the installed Ranger Veteran first-person donor's 63
  rest nodes, maps 54 shared bones, and refuses an incompatible unit.
- Blender 5.2 now rebinds Janfon's arms to those exact donor rest matrices
  offline, verifies a maximum matrix error of `0.00000310`, and rejects any
  change to the authored mesh above `0.00001m` (observed `0.00000036m`).
- Donor-rest builds use VT2's native 53-node first-person attachment directly
  and skip every per-frame midpoint, arm-root, and rest-retarget correction.
  Source builds retain the root-only fallback and diagnostics.
- Added the v0.6.15-dev staged-transform correction after v0.6.14 exposed
  vague transparent strands. The live probe showed midpoint and per-arm
  translations each repeating the same `~0.441m` offset, while per-arm
  residuals remained unchanged, proving a parent/child double translation.
- Per-arm corrections now subtract the shared midpoint translation inherited
  from the spine and apply only the side-specific remainder. Residuals are
  measured from the resolved prior frame rather than stale same-update world
  poses.
- Uploaded the hash-verified v0.6.15-dev build from source commit `ecbddd0` to
  friends-only Workshop item `3764954245` as ManifestID
  `5051999329694268825`.
- Added the v0.6.14-dev per-arm anchor candidate after v0.6.13 rendered two
  tiny black specks. The live probe proved the mesh was shown, midpoint error
  fell to `0.0044m`, but each hand remained about `0.18m` from its donor hand.
- Added independent rigid translations at `j_leftarm` and `j_rightarm` after
  midpoint alignment. Each complete arm now follows its corresponding VT2 hand
  without scaling bones or returning to the collapsing absolute-node bridge.
- Added per-side correction and residual diagnostics to distinguish successful
  hand placement from remaining orientation, clipping, or material failures.
- Uploaded the hash-verified v0.6.14-dev build from source commit `ee26fcf` to
  friends-only Workshop item `3764954245` as ManifestID
  `3997686606515825820`.
- Added the v0.6.13-dev first-person camera-anchor candidate after v0.6.12
  initialized all 53 retarget pairs but rendered no visible hand model. Its
  live hand nodes remained `0.50-0.66m` from VT2's animated hand locations.
- Added a rigid per-frame spine translation that aligns Janfon's two-hand
  midpoint to VT2's live two-hand midpoint after rotational retargeting. This
  corrects camera placement without changing any authored bone length.
- Disabled bounding-volume culling on the generated first-person renderable.
  The runtime exposes zero LOD objects on the custom target, so donor LOD bounds
  cannot be copied through `LODObject`; Stingray supports per-mesh disabled
  culling for exactly this camera-linked case.
- Uploaded the hash-verified v0.6.13-dev build from source commit `ccaec5a` to
  friends-only Workshop item `3764954245` as ManifestID
  `299222409316147201`.
- Added the v0.6.12-dev first-person rebind candidate after v0.6.11 rendered
  Janfon's arms as blinking sticks despite a live mesh, enabled visibility, and
  zero-distance attachment nodes.
- Replaced absolute per-bone `World.link_unit` attachment with a root-only link
  and rest-relative runtime retarget. Donor animation deltas are applied over
  Janfon's own bind rotations while preserving his authored local offsets.
- Copied the donor first-person LOD bounding volume to Janfon's attachment;
  vanilla cosmetic attachments do this, but VT2's first-person character path
  does not, allowing a custom mesh to blink at its incorrectly compiled bounds.
- Uploaded the v0.6.12-dev friends-only retarget test as Steam ManifestID
  `1512228345017462962` after full native compilation, splice validation, and
  hash-verified local deployment.
- Advanced the live first-person A/B candidate to v0.6.10-dev after v0.6.9
  loaded its custom unit and material successfully but rendered no arms.
- Kept the corrected static bind export while restoring Janfon's known-visible
  `j_spine2 -> j_spine1` donor adapter as the single deformation variable.
- Added a delayed runtime probe for first-person mesh count, mode, root
  transform, scale, and linked source/target node distances.
- Uploaded the v0.6.10-dev friends-only test as Steam ManifestID
  `1380279707573289085` after local build and deployment verification.

### Fixed

- Fixed the v0.6.10-dev crash in the delayed first-person probe. Its target
  lookup now follows the actual `j_spine2 -> j_spine1` attachment pair instead
  of asserting on a target `j_spine2` node that is not present at runtime.
- Uploaded the crash-safe v0.6.11-dev friends-only test as Steam ManifestID
  `5832214133899576087` after full native build and local deployment checks.
- Wrapped preflight output in a literal `%s` VMF format so percentage-bearing
  check details no longer produce `<Invalid string format>` errors.
- Reset Janfon's first-person armature to its authored rest pose before static
  export, removing the saved `positioningtest` NLA strip and 45 non-identity
  pose transforms that made the hands appear as stretched sticks in game.
- Added a Blender deformation diagnostic and a build-time rest-pose assertion.
  The corrected FBX holds edge stretch to `1.00003x`, down from `3.58596x`.
- Imported VT2's canonical buff-perk lookup in both gameplay registration and
  preflight, preventing the v2 no-hit-slow perk from dereferencing an undefined
  `buff_perks` global during startup.
- Moved Scaredy-rat's speed trigger to the player damage hook, where VT2 still
  exposes `light_attack` and `heavy_attack`, so ranged damage no longer
  incorrectly activates the melee-only perk.
- Fixed v0.6.6-dev spawning the equipped Ranger Veteran first-person skin
  before its post-init Pusfume check. The career-scoped hook now substitutes
  the native Pusfume skin during vanilla attachment creation and immediately
  restores the shared init data afterward.
- Fixed a session-ending crash when the shared Ranger Veteran loadout carries
  an item the vanilla loadout-sync RPC cannot encode (live: the Blightreaper
  event sword's `woc_power_vs_order` property is absent from
  `NetworkLookup.properties`, whose metatable raises on missing keys, and the
  synthetic career's loadout resync syncs items vanilla never would). A
  sender-side wire guard now strips unencodable properties and traits before
  the encoder, unconditionally, logging each stripped key once.
- Replaced the legacy fur's per-vertex body projection with rigid connected-card
  retargeting, preventing individual triangle corners from stretching across
  unrelated body regions while preserving animated weight transfer.
- Added build-time fur fit and edge-preservation assertions so detached or
  destructively warped fur fails before native bundle compilation.
- Fixed Pusfume ability, passive, perk, and quest labels rendering as
  angle-bracketed internal keys by bridging the complete VMF localization
  table into vanilla's global `Localize` path.
- Replaced the rigid custom whisker shader with a locally verified splice of
  the game's skinned Laurel feather binding, patched only to Janfon's diffuse,
  normal, and packed response maps.
- Added explicit Laurel donor-package lifetime management so the whisker shader
  does not depend on an equipped cosmetic or another mod making it resident.
- Preserved fractional whisker diffuse alpha during texture compilation instead
  of destructively thresholding the source coverage into a visible tape card.
- Fixed v0.6.3-dev omitting vanilla's generated sub-buff `name` metadata from
  runtime-registered templates, which crashed when Insider Knowledge first
  added its team stat buff after spawning Pusfume.
- Fixed v0.6.2-dev sending a localization key instead of Pusfume's internal
  career token to `ProfileRequester`, which produced a nil career index when
  confirming the hero selection.
- Fixed v0.6.1-dev failing on VT2's strict network-lookup metatable while
  checking whether new career buff identifiers were already registered.
- Fixed the v0.6.0-dev startup regression that aborted career and hero-selector
  registration by replacing unsupported VMF proc and buff helpers with VT2's
  synchronized native registries.

### Added

- Added the authoritative v2.0 career contract derived from the current design
  document, plus focused regression tests for identity, retired v1 systems,
  passive registration, and guarded ability boundaries.
- Added Aggressive Iteration Special-kill capture/readiness diagnostics and
  Moulder Ingenuity's guarded next-consumable state.
- Added Janfon's canonical Pusfume portrait as dedicated selector, HUD/score,
  and compact UI assets, using the proven vanilla frame masks from Dynamic
  Cosmetic Portraits and standalone renderer injection for every supported UI.
- Added Janfon's dedicated first-person Pusfume arms as an optional private
  native build input. The build non-destructively isolates and validates the
  weighted arm mesh, compiles a 99-bone attachment, and applies a dedicated
  direct-UV skinned material without committing the private source asset.
- Added first-person runtime and preflight diagnostics that distinguish unit
  availability, hook installation, package loading, and material application.
- Added Pusfume's localized `Under-Empire Reject` career identity, `The Great
  Scheme` placeholder Skaven quests, and the first functional versions of Hell
  Pit Native, Scaredy-rat, and Insider Knowledge.
- Replaced the Ranger Veteran smoke-bomb adapter with a guarded Skaven
  Ingenuity station scaffold and `/pusfume_gameplay` diagnostics. Inventory
  conversion remains intentionally disabled until its network contract and
  custom gas-item definitions are complete.

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

- Advanced the local live-test candidate to v0.6.8-dev for the v2 career kit.
  The career now has explicit 100 HP, a 90-second Moulder Ingenuity cooldown,
  no-hit-slow and melee-only Scaredy-rat behavior, and 15% Swift Claws reload
  speed. The old Great Scheme, station, and Insider Knowledge prototypes are
  retired.
- v0.6.7-dev added first-person arms.
  Janfon's `positioningtest` action remains a diagnostic handoff clip; this
  candidate instead links the arms to VT2's native first-person animation rig.
- Updated the README, career-kit contract, and live-test checklist to identify
  v0.6.5-dev as the current candidate and distinguish confirmed runtime
  milestones from pending stability, localization, whisker, and multiplayer
  acceptance tests.

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
