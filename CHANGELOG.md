# Changelog

All notable changes to Pusfume are recorded here. This project follows the
[Keep a Changelog](https://keepachangelog.com/en/1.1.0/) structure and uses
[Semantic Versioning](https://semver.org/spec/v2.0.0.html) once releases are
tagged.

Detailed investigation evidence belongs in the linked GitHub issue and pull
request rather than in release notes.

## [Unreleased]

- Added weapon-aware dual first-person rigs. Native Packmaster, Gutter Runner,
  Globadier, Warpfire Thrower, and Ratling Gunner weapons now select their own
  Versus base and arm mesh; normal hero weapons select Janfon's human-rigged
  Pusfume hands. Wielding updates both VT2 first-person caches and rebinds the
  existing weapon, ammo, and damage units before vanilla handles the wield.
- Fixed Janfon's human hands rendering off-camera. The donor-rest build now uses
  VT2's complete native `first_person_attachment` contract instead of the
  retarget table, whose `j_spine2 -> j_spine1` diagnostic mapping displaced the
  live attachment by roughly 20 engine units.
- Fixed the v0.6.44 startup crash in `StatisticsDatabase._init_backend_stat`.
  Pusfume's late-added per-career statistic leaves now include the `name`
  metadata normally supplied by the private boot-time `add_names()` pass, so
  the database no longer recurses into numeric `value` fields.
- Guarded the direct weapon first-person animation path after v0.6.42 sent a
  missing generic hook-swing event to Stingray and crashed. The check is scoped
  to Pusfume and preserves every event supported by Janfon's human hero rig.
- Gave the Ratling Gun a real clip-plus-reserve ammo economy (issue
  [#40](https://github.com/Ensrick/vt2-pusfume/issues/40)): 240 total rounds as
  a 120-round loaded clip plus a 120-round reserve. The pool is now reserve-based
  (`ammo_immediately_available` false), the reload pulls from the reserve into
  the clip (`instant_reload`, replacing the Versus infinite-hopper `add_ammo`),
  and ammo boxes refill the reserve like any hero ranged weapon. Verified against
  `GenericAmmoUserExtension` and `SimpleInventoryExtension._add_ammo_to_slot`.
- Restored the Ratling Gun and Warpfire Thrower firing audio (issue
  [#41](https://github.com/Ensrick/vt2-pusfume/issues/41)). The ratling adapter
  had nil'd every synchronized-state callback to strip the crashing VCE and
  Pactsworn "fire" career-ability code, which also removed the Wwise fire loop
  and spin-up triggers; those are now re-added as sanitized audio-only callbacks
  (event names verbatim from `vs_ratling_gunner_gun.lua`). The Warpfire's Versus
  soundbank is not resident in Adventure (the item declares no such wwise_dep),
  so it now plays the resident hero drakegun flamethrower loop
  (`Play/Stop_player_combat_weapon_drakegun_flamethrower_shoot`, bank
  `wwise/flamethrower`, both from `drakegun.lua`) over the fire action.
  Ratling-bank residency in Adventure needs in-game A/B confirmation.
- Switched Pusfume's live first-person hands to Janfon's human-rigged arms
  (issue [#35](https://github.com/Ensrick/vt2-pusfume/issues/35)): the rig is
  the standard hero 1P skeleton verbatim (weapon-attach plus all 40
  weapon-component bones), rebound via the FBX path against the dwarf donor
  after proving all hero 1P donor skeletons are world-identical (max matrix
  delta 0.0). `native_skaven_first_person` now bakes false whenever a
  first-person blend is supplied, retiring the always-on Packmaster fallback
  and un-suppressing native hero weapon state machines. v0.6.46 retains those
  native arms only in the separate weapon-aware Versus rig.
- Opened every hero's weapons to Pusfume for testing
  (`open_all_hero_weapons = true`): the roster layer expands `can_wield`,
  the weapon grid surfaces all hero weapons alongside the rat prototypes,
  and per-slot selection stores any hero backend item. The three-path 3P
  animation wire-safety floor guards cross-body events unconditionally.
  Flip the single flag off for any public promotion.
- Pruned weightless orphan vertex groups in the 1P prep (handles Janfon's
  stray `j_lefthandpinky4`) and located the beastmen first-person arrow-hit
  mechanism (`first_person_hit_flow_events` `arrow_left/right/center`) for
  the future psf_arrow flow-graph swap.
- Fixed a fatal when any per-career statistic was recorded for Pusfume
  (2026-07-19 23:30 crash via career_tweaker's armor/overcharge stat on
  area damage): `StatisticsDefinitions` builds its career-keyed stat
  families by iterating `CareerSettings` at boot, before the mod registers
  the career. `register_statistics_definitions` now replicates the boot
  generation for Pusfume (`min_health_percentage`, `min_health_completed`,
  `completed_career_levels` across unlockable levels and difficulties),
  idempotent across VMF reloads.
- Fixed the hero-select name rendering as the missing-localization marker
  `< Pusfume >`: the identity widgets received the VMF-resolved string, which
  the vanilla localize=true text pass re-ran through global `Localize` where
  mod localization is invisible. The display strings are now registered as
  self-resolving keys in `LocalizationManager`'s backend table (the
  `_base_lookup` chokepoint), re-registered on manager init, per the repo
  localization standard - no Localize hooks.
- Added the gated hero-weapon roster layer (issue
  [#35](https://github.com/Ensrick/vt2-pusfume/issues/35) groundwork):
  `open_all_hero_weapons` dev flag with can_wield expansion, an unconditional
  three-path 3P animation wire-safety floor, and per-slot enumeration. Inert
  while the flag is off; the human-rig switch enables it.
- Corrected the emission channel after the v0.6.40 live test lit the whole
  body except the eyes: the shader reads its emission mask from the MA
  texture's ALPHA, not the normal map's blue (that convention was the Blender
  ubershader's, not the game's). The MA atlas now ships zeroed alpha with
  `skaven_eyemask` stamped into the eye tile only; the normal atlas keeps its
  vanilla-parity zeroed blue with no stamp. Eyes glow warpstone red, body
  stays dark.
- Fixed the potion-wield CTD (2026-07-19 22:41): consumable wield events
  (`to_potion`, `to_healthkit`, ...) do not exist on the native Skaven 1P rig
  and resolved to a negative Stingray animation index. A first-person
  animation-event guard now skips any event the rig does not carry, logging
  each skipped event once.
- Lit the authored eye glow (issue [#36](https://github.com/Ensrick/vt2-pusfume/issues/36)):
  Janfon confirmed character emission rides the normal map's BLUE channel and
  that the eyes are the model's only emissive. The normal atlas now ships a
  zeroed blue channel (matching vanilla character normals; the engine
  reconstructs Z from RG) with `skaven_eyemask` stamped into the eye tile,
  and the spliced body child sets `emissive_color` to the authored warpstone
  red (15, 1, 0.2 HDR, tunable). Corrected the earlier mis-read: nothing on
  the arm glows, and VT2 has no tint-mask concept.
- Reconciled Janfon's fully-packed body .blend against the handoff: 23 maps
  byte-identical; `pusfume_fur_df` updated and the previously-missing
  `pusfume_fur_n`/`pusfume_fur_s` recovered. Wiring the fur child to Janfon's
  own maps awaits a UV-pairing confirmation for the integrated fur mesh.
- Fixed the flat body shading (issue [#36](https://github.com/Ensrick/vt2-pusfume/issues/36)):
  the spliced body child's third texture slot was left pointing at the
  Globadier's OWN metallic/AO map (baked to Globadier UVs, misaligned to
  Pusfume) with the emissive tint zeroed. Decoded the donor slot as Fatshark's
  M/AO/x/EM packing (R=metallic, G=AO, A=emissive mask) from the compiled
  `90BDF3BAC6F81BA8.material` and its vanilla texture. The build now composes
  `pusfume_atlas_ma` from Janfon's `_s` maps and feeds it to that slot,
  restoring per-pixel metallic (peg leg, buckles) and baked occlusion.
  Emissive stays dark pending three art confirmations (tint colour, outfit
  `_s` alpha cleanup, body mask extent); the plumbing is wired.
- Confirmed from Janfon's 3P body .blend (V2 Ubershader 1.07 node graphs):
  every material feeds `_s` into the Maskmap slot; `pusfume_eyenormal` as eye
  albedo is intentional, but eyes are authored EMISSIVE via `skaven_eyemask`
  (not yet wired in-game); fur normal/mask maps (`pusfume_fur_n/s.dds`) are
  absent from the handoff and need a fresh send from Janfon.
- Audited the texture pipeline against Fatshark's SDK examples and working
  Workshop mods after the reported in-game quality loss. Diffuse and normal
  textures (per-slot and both body atlases) now compile as `BC7` instead of
  `DXT5`: same 8 bpp so no bundle growth, but ~8-bit RGB precision instead of
  5:6:5, matching the SDK's own `*_nm.texture` treatment, with the donor's
  gloss-in-alpha channel preserved. Specular and mask maps stay DXT5.
- Scoped `BodyDiffuseGain` (1.2x) to the body atlas tile only. Globadier,
  armor, metal, and ammo tiles keep Janfon's authored brightness instead of a
  highlight-clipping boost. Verified non-losses during the same audit: gloss
  survives in the normal-map alpha through atlas composition, and all srgb
  flags are correct.
- Compiled, deployed (8 files), and uploaded the friends-only v0.6.37-dev
  candidate with the hook damage-type CTD fix. Steam confirmed ManifestID
  `3176743220645990543` at 2026-07-19 12:37 America/Chicago. Live gameplay
  verification is pending.
- Fixed the Packmaster hook strike CTD on training dummies (2026-07-19 16:42
  playtest): the strike helper passed the billhook damage-profile name
  `light_slashing_smiter_pull` as the networked damage type, which is not a
  `NetworkLookup.damage_types` key, so the host crashed encoding
  `rpc_add_damage`. The strike now uses the vanilla `light_slashing_smiter`
  damage type.
- Fixed the ranged-to-hook switch crash by restoring Fatshark's playable
  Pactsworn wield contract: weapon templates use `idle`, while Pusfume's native
  rig enters its separate role pose. Removed the AI-only `to_packmaster_claw`
  event, which produced an invalid negative Stingray animation index.
- Gave the crossbow stand-in an isolated Pusfume template. It retains Bardin's
  projectile and ammunition behavior but cannot install Bardin's first-person
  state machine; placeholder animation events remain safely idle until authored
  Skaven crossbow poses exist.

- Added a Pusfume-scoped compatibility bridge for UI Tweaks/HideBuffs. The full
  Pactsworn Warpfire widget now supplies invisible legacy threshold styles and
  restores its authored height after HideBuffs updates it, preventing the
  `max_threshold` nil-index crash without changing UI Tweaks or other careers.

- Made the Ratling Gun a finite 120-round Adventure weapon. It now consumes
  ammunition, becomes eligible for normal ammo-box refills, and no longer
  triggers the donor Bardin `activate_ability` bark on spin-up.
- Pointed the Packmaster hook's damage-only helper at Fatshark's shipped
  billhook smiter damage family. The strike keeps the flat prototype hit; a
  networked pulling stagger toward Pusfume is not yet implemented.
- Added Pusfume-only Assassin Claws using the complete Gutter Runner claw units
  and a guarded dual-dagger action graph, plus a functional Bardin-crossbow
  duplicate reserved as the future Skaven-crossbow stand-in.
- Forced Pusfume's character-selection and inventory previews to remain on the
  authored idle with no equipped weapons. Added the complete 250x70 Pactsworn
  Warpfire HUD widget instead of recoloring the ordinary hero heat bar.
- Audited the exact v0.6.33 compiled 3P FBX in Blender 5.2: all 73,254 mapped
  loops remain inside their assigned atlas regions with zero escapes. The
  missing unused `p_eye_g` slot and reported chest appearance remain tracked
  for textured-render and live validation rather than speculative UV edits.

- Recorded the v0.6.32 live result: Pusfume's hands and native weapon poses
  remained coherent, but the hook did not damage enemies, the shared Hero View
  still listed Ranger Veteran weapons, the Warpfire heat HUD was absent, and
  Bardin dialogue continued to play. The localized chest atlas seam remains
  isolated in issue [#28](https://github.com/Ensrick/vt2-pusfume/issues/28).
- Added a Pusfume-only hard identity allowlist to Hero View and loadout writes.
  The only permitted melee item is the Packmaster Hook; the ranged inventory
  now contains Warpfire Thrower, Ratling Gun, and Poison Wind Globe prototypes.
  Ranger Veteran weapons can no longer enter either Pusfume weapon slot.
- Added a 4.5-meter, forward-cone Adventure strike to the Packmaster hook.
  This provides reliable damage independently of the Versus-only disable
  character state; full Packmaster capture and dragging are still out of scope.
- Adapted Fatshark's native Ratling Gun actions, ammo, projectiles, and poses to
  normal hero inputs, and added a networked Globadier globe throw prototype.
  Both use complete cloned Versus item/unit records and isolated templates.
- Routed Pusfume's dialogue context to the playable Globadier profile and
  retained Fatshark's corresponding per-unit Wwise switch. Added Pusfume's own
  clone of the Warpfire overcharge data so heat uses the Pactsworn-green HUD.
- Expanded regression coverage to 72 tests, added exact roster, hook damage,
  Ratling, globe, voice, role-pose, and overcharge-HUD contracts, and verified
  all 14 Lua files with the Lua 5.1 parser.
- Compiled source commit `77341d4`, passed GitHub source-preflight CI and the
  54-node first-person rest check (`0.00000310` maximum error), deployed all
  eight files with exact staging/live SHA-256 parity (`119,874,864` bytes), and
  uploaded the friends-only v0.6.33 candidate. Steam confirmed ManifestID
  `2481608271187325602` at 2026-07-18 23:49 America/Chicago. Live gameplay
  verification is pending.

- Fixed release-pipeline issue
  [#29](https://github.com/Ensrick/vt2-pusfume/issues/29) by replacing
  Pusfume's disruptive direct Blender/Node/VMB upload sequence with a
  single optional `Build-NativePusfume.ps1 -Upload` pipeline. Every external
  process now uses redirected output, `CreateNoWindow=true`, and hidden window
  style; VMBLauncher owns build, verified local/enabled-remote deploy, and
  friends-only upload. The pipeline also rejects uploader success unless
  Steam's Workshop log confirms a fresh Pusfume ManifestID.

- Fixed crash `cd33e247-dc5e-4aa6-96ed-840258a1bde5` in
  `WeaponUnitExtension.get_action`. The adapted Warpfire state machine retained
  a native `dark_pact_action_one` transition after Adventure input began
  `action_one`, but v0.6.31 had removed that action group.
- Added independent, lookup-correct native Warpfire compatibility aliases and
  pre-registration validation for every weapon action-chain destination. An
  unresolved chain now fails registration with a diagnostic instead of
  reaching Fatshark's nil-unsafe action lookup during play.
- Staged the first-person rig into `to_packmaster` followed by
  `to_packmaster_claw` when melee is equipped, and into
  `to_warpfire_thrower` for ranged. Temporary hook starts and sweeps now play
  the native `attack_grab` first-person event while retaining damaging
  Adventure sweeps when no valid grab target exists.
- Compiled source commit `b2a42a0`, deployed and hash-verified all eight native
  Workshop files locally, and uploaded the friends-only v0.6.32 candidate as
  Steam ManifestID `1170425049691334215` at 2026-07-18 22:10
  America/Chicago. Steam's Workshop log confirms the remote content manifest;
  live gameplay verification is pending.

- Recorded the v0.6.30 live result: Pusfume spawned without a crash, the native
  Skaven hands were coherent, animated, and remained visible, and the real
  Packmaster claw unit completed its armed presentation. Both weapons still
  lacked usable Adventure input/action behavior, the hands retained their
  Globadier hold pose, Bardin weapons remained visible in the shared-profile
  inventory, and localized body regions still appeared incorrectly mapped.
- Added the v0.6.31 Adventure weapon adapter. Normal `action_one` and
  `weapon_reload` inputs now drive Fatshark's native Warpfire action, heat,
  synchronized shooting/cooling states, sounds, and effects. A Pusfume-only
  target adapter supplies Adventure enemies, while a networked two-damage
  pulse replaces the Versus burn callback that unsafely requires a
  `vs_warpfire_thrower` player breed.
- Kept the Packmaster hook on the crash-safe Adventure sweep contract and now
  sends its native `attack_grab` event for articulated claw presentation.
  Exact Versus dragging remains a career-state feature and is not claimed by
  this weapon adapter.
- Restricted Pusfume's melee and ranged Hero View grids to
  `can_wield_by_current_career`. This removes Bardin's weapon catalog without
  changing permissions or inventory behavior for his four native careers.
- Audited the handoff body in Blender 5.2: all 76,334 mapped loops remain
  inside their declared atlas regions, but the atlas expects `p_eye_g` while
  the model does not provide that material slot. The visual mismatch is tracked
  independently rather than changing the known-good body in this candidate.
- Expanded weapon and inventory regression coverage to 65 tests and updated
  source preflight for the native-action, target, damage, and career-filter
  contracts.
- Compiled source commit `a7cc929`, deployed and hash-verified all eight native
  Workshop files locally, and uploaded the friends-only v0.6.31 candidate as
  Steam ManifestID `1065739404025473822` at 2026-07-18 21:22
  America/Chicago. GitHub source-preflight CI passed; live gameplay
  verification is pending.

- Fixed crash `9970472a-2b65-409b-b45d-1421516dbc88` in
  `ActionSweep._play_hit_animations`. The real Packmaster hook was equipped,
  but its temporary two-handed-axe actions tried to play the hero-only
  `attack_hit_alt_effect` event on Fatshark's shared Skaven controller.
- Sanitized all first-person hit-stop, armor-hit, shield-hit, kill-hit, and
  dual-hit animation fields from the isolated Packmaster melee adapter. Damage,
  sweeps, native hook units, and native attachment linking are unchanged.
- Corrected `restore_first_person_weapons`, which previously called
  `hide_weapons` every frame while reporting the opposite. It now waits for a
  live wielded unit, clears the Packmaster `catapulted` hide reason and the old
  diagnostic reason, and reproduces the capability-guarded `to_armed`/`armed=1`
  presentation step used by Fatshark's Packmaster equipping state.
- Added a one-shot live weapon probe covering the wielded slot, weapon unit,
  root transform, articulated claw nodes, armed event/variable support, and any
  remaining hide reasons. Regression and source-preflight coverage now enforce
  the complete crash and visibility contract.
- Recorded the v0.6.29 live result: the controller fix produced coherent,
  animated Pusfume hands. The Globadier-like gestures came from the shared
  Skaven first-person base, while the crash locals proved the equipped item and
  spawned weapon unit were still Pusfume's Packmaster hook.
- Built and hash-verified the v0.6.30 native package from source commit
  `be6f63a`, deployed all eight game files locally, and uploaded the identical
  payload to the friends-only Workshop item. Steam confirmed ManifestID
  `3684913542981979356` at 2026-07-18 20:34 America/Chicago. All 63 regression
  tests, source preflight, material/animation checks, and the 54-node compiled
  rest validation pass; live gameplay validation remains pending.

- Fixed crash `3e42f9dd-5fbe-495d-8d55-d44ab5d0b062` when attacking after
  swapping to the Warpfire Thrower. The Versus condition called the
  Pactsworn-only `is_climbing()` API on Pusfume's ordinary Adventure hero
  status extension; all adapted status and overcharge callbacks are now
  capability-guarded.
- Prevented Bardin's common first-person animation state machine from being
  installed on the native Skaven first-person base at spawn or reapplied as a
  weapon-swap fallback. Fatshark's playable Packmaster profile and both native
  weapon templates intentionally omit that override and retain the controller
  embedded in the Skaven base.
- Recorded the v0.6.28 live control result: the native base and Packmaster arms
  spawned at identity scale, and every available arm/hand attachment pair had
  `0.0000m` node error. This rules out the attachment transform as the primary
  cause of the huge fur-and-claw lump and makes v0.6.29 a single-variable
  controller test rather than another asset or transform revision.
- Added regression coverage for the Adventure/Pactsworn API boundary, safe
  Warpfire reload checks, temporary shared-profile restoration, and weapon-swap
  state-machine rejection.
- Built and hash-verified the v0.6.29 native package from source commit
  `6c912e3`, deployed all eight game files locally, and uploaded the identical
  payload to the friends-only Workshop item. Steam confirmed ManifestID
  `3618672643934952388` at 2026-07-18 19:53 America/Chicago. Live gameplay
  validation remains pending.

- Fixed the v0.6.27 delayed first-person attachment-probe crash. The native
  Packmaster control spawned successfully, but its arm unit does not expose
  the old Janfon/Ranger `j_spine2` probe node; an unguarded `Unit.node` call
  asserted in Stingray two seconds after spawn.
- Guarded both units in every first-person probe pair with `Unit.has_node`.
  Unavailable diagnostic pairs are now reported as such without affecting
  gameplay, and regression coverage locks the assertion-safe lookup order.
- Built and hash-verified the v0.6.28 native package from source commit
  `2fa45c5`, deployed all eight game files locally, and uploaded the same
  payload to the friends-only Workshop item. Steam confirmed ManifestID
  `2137408449754657186` at 2026-07-18 19:21 America/Chicago. Live gameplay
  validation remains pending.

- Fixed the v0.6.26 spawn crash at
  `player_unit_first_person.lua:60`. The live locals proved
  `World.spawn_unit` returned `nil` for the non-resident shared Skaven
  first-person base before vanilla called `set_animation_state_machine`.
- Added a reference-counted native package residency contract for the shared
  Skaven first-person base, bot base, and Packmaster arms. All three are loaded
  synchronously through Fatshark's `Managers.package` API and verified as
  gettable units before skin registration and again immediately before spawn.
- Added a crash-safe fallback to the bundled first-person path if any native
  package cannot become resident, plus symmetric shutdown and regression
  coverage. This prevents another nil-unit spawn from reaching vanilla.
- Built and hash-verified the v0.6.27 native package from source commit
  `182f977`, deployed all eight game files locally, and uploaded the same
  payload to the friends-only Workshop item. Steam confirmed ManifestID
  `4012083168238356315` at 2026-07-18 18:55 America/Chicago. Live gameplay
  validation remains pending.

- Replaced the Ranger Veteran first-person base used by the v0.6.25 weapon
  prototype with Fatshark's shared Skaven first-person base and native
  Packmaster arm attachment. This isolates weapon placement from Janfon's
  still-Ranger-bound cosmetic arms and gives both prototype weapons their
  authored Pactsworn attachment nodes for the v0.6.26 live test.
- Rebuilt both Pusfume inventory entries as complete deep clones of the
  official `vs_packmaster_claw` and `vs_warpfire_thrower_gun` base records.
  Only Pusfume ownership, custom identity, Adventure slot metadata, and
  isolated template names differ from Fatshark's records.
- Added regression coverage for the native Skaven first-person contract and
  complete base-item cloning. Janfon's first-person asset remains preserved in
  the build pipeline for a later exact Skaven-rest rebind.
- Built and hash-verified the v0.6.26 native package from source commit
  `b059534`, deployed all eight files locally, and uploaded the friends-only
  Workshop candidate. Steam's persistent log confirmed ManifestID
  `4747837235132942219` for item `3764954245` at 2026-07-18 18:33
  America/Chicago. Live gameplay validation remains pending.

- Corrected the v0.6.24 prototype weapon adapter after crash
  `c6fadfc5-d61e-4eaf-9d19-ced33b4d75ae`. Both models now resolve directly
  from Fatshark's base playable-Versus item records instead of substitute
  hero items. The Warpfire Thrower now keeps its native left-hand unit and
  left-handed Versus action template as one coherent contract; only callbacks
  tied to Versus ghost mode and its VCE manager are removed for Adventure.
- Rebased the hook adapter on the native `vs_packmaster_claw` template and
  attachment metadata. Fatshark implements its grab as a Pactsworn character
  state and gives the weapon no ordinary actions, so only the temporary hero
  attack table remains borrowed until Pusfume has dedicated melee actions.
- Added a runtime action-hand invariant and source regression test. Preflight
  now fails before selection if any Pusfume action could start without its
  corresponding wielded unit.
- Built and hash-verified the v0.6.25 native package from source commit
  `c59ab62`, deployed all eight files locally, and uploaded the friends-only
  Workshop candidate. Steam's persistent log confirmed ManifestID
  `1817442651143246521` for item `3764954245` at 2026-07-18 17:45
  America/Chicago. Live gameplay validation remains pending.

- Added the v0.6.24 weapon and identity candidate. Pusfume now owns fixed,
  synchronized prototype items that render the shipped playable-Versus
  Packmaster hook and Warpfire Thrower, while retaining Adventure-safe Bardin
  action logic instead of invoking Pactsworn-only character states.
- Restricted the two prototype weapons to Pusfume, stopped granting him every
  Ranger Veteran weapon, and removed the first- and third-person diagnostic
  seams that hid equipped weapon units.
- Added career-scoped character-name guards to the selector header, inventory
  character panel, and loot panel. Bardin's shared profile localization remains
  unchanged for his four native careers.
- Added runtime preflight coverage for item/template/network registration,
  shipped weapon-unit availability, exact default loadout keys, and isolated
  weapon permissions. Live gameplay and two-peer verification remain pending.
- Built, hash-verified, and locally deployed the v0.6.24 native package from
  source commit `46b9f1f`. Steam's persistent Workshop log confirmed new
  content as ManifestID `40228561972604423` at 2026-07-18 17:11
  America/Chicago. The configured direct `pc-b` deploy failed SSH
  authentication, so the tester distribution path for this candidate is the
  successful friends-only Workshop upload.

### Changed

- Added the v0.6.23 first-person deformation and HUD candidate. The v0.6.22
  live log proved direct donor links reached all arm/hand nodes with identity
  root scale and zero positional error, while blocking still warped the mesh.
  The direct-BSI pipeline now weight-deforms Janfon's mesh onto the donor joint
  positions before adopting the donor axes and inverse binds, instead of moving
  rotation pivots under an unchanged mesh. Blender rejected a full-axis bake
  that displaced vertices by `1.1730m`; the accepted position-only bake moves
  at most `0.1857m`, reproduces its target pose within `0.00000018`, and retains
  the compiled 54-node maximum rest error of `0.00000310`.
- Reasserted Pusfume's hero-selection identity widgets after vanilla updates
  its selected indices, and added a final live `UnitFramesHandler` seam that
  restores `portrait_pusfume` after other HUD/portrait hooks. Both paths emit
  bounded runtime evidence and are represented in `/pusfume_preflight`.
- Recorded that Janfon's current first-person handoff has no walk cycle. This
  candidate does not synthesize one: the existing third-person walk remains
  separate, while first-person arms inherit VT2's weapon/action poses.
- Expanded the regression suite to 50 passing tests and made automatic
  preflight summaries log every warning/failure detail instead of only totals.
- Shipped source commit `6ecf623` to the friends-only Workshop item at
  2026-07-18 16:25 America/Chicago. The uploader reported success; live
  verification and a refreshed Steam ManifestID remain pending.
- Added the v0.6.22 animation candidate. Janfon's new 96-frame authored idle is
  packaged separately from the restored original 25-frame walk; the latter is
  rotation-retargeted from its 82-bone source onto the current 138-bone
  untouched Skaven rig. Three-frame front/side renders verify coherent idle and
  gait deformation before compilation, and the build now rejects missing bones,
  missing actions, and zero-duration clips instead of trusting handoff filenames.
- Compiled, locally deployed, and hash-verified the v0.6.22-dev eight-file
  package from source commit `83583ce`. The friends-only Workshop uploader
  reported `Upload finished` at 2026-07-18 14:42 America/Chicago; Steam's local
  ACF has not refreshed, so a new ManifestID remains intentionally unclaimed.
- Added the v0.6.21 material and first-person deformation candidate after the
  v0.6.20 live test reached a normal shutdown but showed malformed finger curls
  and a corrupted-looking third-person surface. The log decoded the failed
  third-person material slot as `p_fur`; the build now rejects integrated-fur
  models unless `-IntegratedFur` packages their dedicated Laurel-derived cutout
  material instead of allowing Stingray's default-material fallback.
- Replaced the default first-person FBX hop with a direct Blender-to-BSI skin
  export. Scene nodes and inverse bind matrices now come from the same exact
  donor-rebound scene, avoiding FBX's split unit-scale behavior. The SDK probe
  compiled 99 bones, 1,980 triangles, and all 54 donor-linked transforms with
  maximum rest error `0.00000310`; FBX remains an explicit diagnostic fallback.
- Deployed and hash-verified the v0.6.21-dev eight-file package locally and
  uploaded source commit `04caf66` to friends-only Workshop item `3764954245`.
  Steam recorded ManifestID `3411867430659936354` at 2026-07-18 13:36
  America/Chicago.
- Added the v0.6.20 lifecycle crash fix after v0.6.19 attempted to hide
  first-person weapons during `PlayerUnitFirstPerson.init`. VT2 does not assign
  `inventory_extension` until `extensions_ready`, so the diagnostic hide now
  remains pending through construction and is applied only from the guarded
  update path once inventory exists. Weapon hiding still persists after wield
  updates without dereferencing an unavailable extension.
- Deployed and hash-verified the v0.6.20-dev eight-file package locally and
  uploaded source commit `b578b23` to friends-only Workshop item `3764954245`.
  Steam recorded ManifestID `627079647267377713` at 2026-07-18 13:01
  America/Chicago.
- Added the v0.6.19 presentation and hand-inspection candidate. Hero-selection
  name writes are now career-scoped at the final UI boundary so the shared
  Bardin profile cannot restore `Bardin Goreksson` over `Pusfume`.
- Applied the playable Poison Wind Globadier `character_vo` flow switch only
  to spawned Pusfume units, replacing Bardin combat vocal routing without
  mutating the shared dwarf profile. Full bespoke dialogue remains future work.
- Hid Pusfume's first-person weapons and weapon lights through VT2's native
  persistent hide-reason API, including after wield updates, so the next live
  test can inspect Janfon's hands without weapon geometry obscuring them.
- Replaced the v0.6.17-v0.6.18 armature-object counter-scale with a compiler-
  measured FBX unit contract. The build now pre-scales mesh and bone positions
  by `100`, exports at `global_scale=0.01`, and leaves the armature object at
  identity. Stingray retains donor-sized translations while all 54 compared
  bone bases compile at unit scale with maximum rest error `0.00000263`; this
  targets the remaining long, thin first-person arm deformation.
- Deployed and hash-verified the v0.6.19-dev eight-file package locally and
  uploaded source commit `721d3c0` to friends-only Workshop item `3764954245`.
  Steam recorded ManifestID `8719688784520429489` at 2026-07-18 12:27
  America/Chicago.
- Added the source-referenced Pusfume career production workbook for Janfon:
  823 checklist items across animation, models/rigging/physics, materials, UI,
  audio, VFX/gameplay, export validation, and a 34-entry VT2 source map.
- Uploaded the locally hash-verified v0.6.18-dev eight-file package from source
  commit `eaf7ae8` to friends-only Workshop item `3764954245`; Steam's UGC
  uploader reported `Upload finished` at 2026-07-18 11:39 America/Chicago.
- Added the v0.6.18 crash fix after the first v0.6.17 live spawn reached the
  new hero preview but asserted on legacy diagnostic bone `j_hand_L`. Native
  root-isolated builds now probe the untouched Skaven rig's `j_lefthand`, and
  every optional probe node is checked with `Unit.has_node` before `Unit.node`.
  Missing diagnostic nodes now produce a warning instead of terminating VT2.
- Uploaded the locally hash-verified v0.6.17-dev eight-file package from source
  commit `d0d7893` to friends-only Workshop item `3764954245`. Steam's UGC
  uploader reported `Upload finished`; the friends-only page and refreshed
  manifest ID still require an authenticated Steam client verification.
- Corrected the Stingray FBX armature counter-scale that left v0.6.16's
  compiled first-person bone bases roughly 100 times larger than the Ranger
  donor. The v0.6.17 post-compiler gate compared all 54 mapped transforms and
  measured a maximum error of `0.00000263` against the `0.001` limit.
- Confirmed from the 2026-07-18 live log that the visible, animated but skinny
  hands were produced by v0.6.16. Runtime attachment was healthy (`direct=true`,
  identity root scale, and zero arm/hand node distance), isolating that result
  to the old compiled deformation asset rather than camera placement or links.
- Replaced the 82-bone normalized placeholder body with Janfon's new
  138-bone untouched Skaven rig. The guarded Blender preparation keeps only
  `p_mainbody` and the game rig, transfers the one stray pinky weight, assigns
  the three unweighted Globadier equipment shells to `j_backpack`, and copies
  12 coincident tail-tip weights without modifying the source `.blend`.
- Added an integrated-fur native build mode so Janfon's body-owned fur geometry
  uses the proven skinned-cutout material without duplicating dalokraff's 510
  separate legacy cards.
- Preserved Janfon's 96-frame baked action on the untouched skeleton as the
  current locomotion test clip. Blender measured `0.154m` sampled vertex
  deformation before the VT2 SDK accepted the 138-bone character.

- Added a post-compiler first-person rest-skeleton gate. It compares 54 linked
  world transforms in the compiled custom `.unit` against the installed
  compiled Ranger Veteran donor and rejects drift above `0.001`.

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
- Uploaded the hash-verified v0.6.16-dev build from source commit `1b35b11` to
  friends-only Workshop item `3764954245` as ManifestID
  `3075372935869158668`.
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

- Fixed the unresolved first-person stick/strand deformation at its actual
  source: Stingray compiled Blender's otherwise correct hand skeleton with a
  `100x` bone basis. A guarded armature-data counter-scale preserves Janfon's
  world-space mesh within `0.00000042m` and bone positions within
  `0.00000020m`; after compilation all donor-linked transforms now match with
  maximum error `0.00000263`, down from `99.0`.

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
