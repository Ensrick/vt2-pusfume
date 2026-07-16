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
- Added source preflight coverage, BSI serialization unit tests, issue and pull
  request templates, CODEOWNERS, and CI patch-hygiene checks.
- Added a `/pusfume_preflight` donor-content check that fails before a live
  test when the Globadier donor package or material cannot resolve, plus
  offline hash verification and the dalokraff donor-material precedent in the
  model handoff documentation.

### Changed

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

- Visible in-game skeletal deformation for the new animated DCC build still
  requires live confirmation; progress is tracked in
  [issue #6](https://github.com/Ensrick/vt2-pusfume/issues/6) and
  [pull request #11](https://github.com/Ensrick/vt2-pusfume/pull/11).
- The current third-person model and armature are placeholders assembled from
  VT2 Skaven assets and therefore remain outside the public repository.
- Pusfume currently shares Ranger Veteran's equipped items and talents rather
  than maintaining an independent persistent loadout.
- First-person arms, final armature work, custom weapons, and complete
  multiplayer validation are not yet implemented.

[Unreleased]: https://github.com/Ensrick/vt2-pusfume/pull/11
