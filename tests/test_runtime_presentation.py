import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
MOD_ROOT = ROOT / "pusfume" / "scripts" / "mods" / "pusfume"


class RuntimePresentationTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.native = (MOD_ROOT / "_pusfume_native.lua").read_text(encoding="utf-8")
        cls.registry = (MOD_ROOT / "_pusfume_registry.lua").read_text(encoding="utf-8")
        cls.ui = (MOD_ROOT / "_pusfume_ui.lua").read_text(encoding="utf-8")
        cls.build = (ROOT / "tools" / "Build-NativePusfume.ps1").read_text(
            encoding="utf-8-sig"
        )

    def test_embedded_whisker_child_has_no_runtime_laurel_dependency(self):
        self.assertIn('whisker_donor_package = false', self.build)
        self.assertIn(
            'if type(config.whisker_donor_package) ~= "string" then',
            self.native,
        )
        self.assertIn("state.whisker_donor_package_loaded = true", self.native)

    def test_pusfume_uses_playable_globadier_voice_switch(self):
        self.assertIn('PUSFUME_CHARACTER_VO = "vs_poison_wind_globadier"', self.native)
        self.assertIn('Unit.set_flow_variable(unit, "character_vo", PUSFUME_CHARACTER_VO)', self.native)
        self.assertIn('Unit.flow_event(unit, "character_vo_set")', self.native)
        self.assertIn("install_dialogue_voice_hook", self.native)
        self.assertIn("DialogueContextSystem, \"extensions_ready\"", self.native)
        self.assertIn(
            "dialogue_extension.context.player_profile = PUSFUME_CHARACTER_VO",
            self.native,
        )
        self.assertIn('career.sound_character = "dwarf_slayer"', self.registry)

    def test_pusfume_has_warpfire_overcharge_hud_data(self):
        self.assertIn("OverchargeData[M.CAREER_NAME] = deep_clone(", self.registry)
        self.assertIn("OverchargeData.vs_warpfire_thrower", self.registry)
        self.assertIn("install_overcharge_hook", self.ui)
        self.assertIn("UIWidgets.create_dark_pact_overcharge_bar_widget", self.ui)
        self.assertIn('"charge_bar_dark_pact"', self.ui)
        self.assertIn("definition.style.min_threshold", self.ui)
        self.assertIn("definition.style.max_threshold", self.ui)
        self.assertIn('mod:hook(OverchargeBarUI, "_update_overcharge"', self.ui)
        self.assertIn("style.bar_1.size[2] = 70", self.ui)
        self.assertIn("style.max_threshold.size[2] = 0", self.ui)

    def test_menu_preview_is_authored_idle_without_donor_weapons(self):
        self.assertIn('career.preview_animation = "idle"', self.registry)
        self.assertIn("career.preview_items = {}", self.registry)
        self.assertIn("career.preview_wield_slot = nil", self.registry)
        self.assertIn('mod:hook(MenuWorldPreviewer, "equip_item"', self.ui)
        self.assertIn('slot_type == "melee" or slot_type == "ranged"', self.ui)
        self.assertIn("Menu preview weaponless idle enforced", self.ui)

    def test_first_person_weapons_are_restored_for_prototype_loadout(self):
        self.assertIn('FIRST_PERSON_WEAPON_HIDE_REASON = "pusfume_hands_diagnostic"', self.native)
        self.assertIn('PACKMASTER_WEAPON_HIDE_REASON = "catapulted"', self.native)
        helper = self.native.split("local function restore_first_person_weapons", 1)[1].split(
            "local DONOR_PACKAGE_REFERENCE", 1
        )[0]

        self.assertIn("if not extension.inventory_extension then", helper)
        self.assertIn("equipment.right_hand_wielded_unit", helper)
        self.assertIn("extension:unhide_weapons(PACKMASTER_WEAPON_HIDE_REASON)", helper)
        self.assertIn("extension:unhide_weapons(FIRST_PERSON_WEAPON_HIDE_REASON)", helper)
        self.assertNotIn("extension:hide_weapons(", helper)
        self.assertIn('unit_has_animation_event(first_person_unit, "to_armed")', helper)
        self.assertIn('Unit.animation_has_variable(first_person_unit, "armed")', helper)
        self.assertIn('extension:animation_set_variable("armed", 1)', helper)
        self.assertIn("update_first_person_weapon_pose(extension, equipment)", helper)
        self.assertIn("item_template.pusfume_role_pose", self.native)
        self.assertIn('wielded_slot == "slot_melee" and "to_packmaster"', self.native)
        self.assertIn('wielded_slot == "slot_ranged" and "to_warpfire_thrower"', self.native)
        self.assertNotIn("to_packmaster_claw", self.native)
        self.assertIn("extension._pusfume_weapon_hide_pending = false", self.native)
        self.assertIn(
            "extension._pusfume_presented_right_weapon_unit == right_weapon_unit",
            helper,
        )
        self.assertIn(
            "extension._pusfume_presented_left_weapon_unit == left_weapon_unit",
            helper,
        )
        self.assertIn("and same_weapon_units and not presentation_blocked", helper)
        self.assertIn("recovered_hidden=%s", helper)
        self.assertIn("restore_first_person_weapons(extension)", self.native)

    def test_assassin_blades_follow_janfon_attachment_and_remain_visible(self):
        helper = self.native.split("local function restore_first_person_weapons", 1)[1].split(
            "local DONOR_PACKAGE_REFERENCE", 1
        )[0]
        self.assertIn(
            "extension._pusfume_active_skaven_role == ASSASSIN_ROLE", helper
        )
        self.assertIn("show_first_person_weapon_unit(right_weapon_unit)", helper)
        self.assertIn("show_first_person_weapon_unit(left_weapon_unit)", helper)
        self.assertIn("Assassin blade presentation", helper)
        visibility_helper = self.native.split(
            "local function show_first_person_weapon_unit", 1
        )[1].split("local function first_person_weapon_attachment_error", 1)[0]
        self.assertIn('Unit.has_visibility_group(unit, "normal")', visibility_helper)
        self.assertIn('Unit.set_visibility(unit, "normal", true)', visibility_helper)
        self.assertIn("Unit.set_unit_visibility(unit, true)", visibility_helper)
        self.assertIn("Unit.num_meshes(unit)", visibility_helper)
        self.assertIn(
            'Unit.set_mesh_visibility(unit, mesh_index, true, "default")',
            visibility_helper,
        )
        self.assertIn("attachment_error=%s/%s", helper)
        self.assertIn("camera_distance=%s/%s default_context=forced", helper)
        self.assertIn("first_person_attachment_camera_distance(", helper)
        self.assertNotIn("Assassin hands-only prototype active", self.native)
        self.assertNotIn("hide_assassin_third_person_weapons", self.native)
        relink = self.native.split("local function relink_weapon_unit", 1)[1].split(
            "local function relink_ammo_unit", 1
        )[0]
        self.assertIn("attachment_node_linking[1]", relink)
        self.assertIn("Unit.has_node(first_person_unit, source_node)", relink)
        self.assertIn("First-person weapon link rejected missing source node", relink)

    def test_switching_away_from_warpfire_clears_its_linked_visual_state(self):
        helper = self.native.split(
            "local function stop_inactive_warpfire_effect", 1
        )[1].split("local function switch_first_person_rig", 1)[0]
        self.assertIn('active_slot ~= "slot_ranged"', helper)
        self.assertIn("item_key ~= WARPFIRE_ITEM_KEY", helper)
        self.assertIn("weapon_extension:current_synced_state()", helper)
        self.assertIn("weapon_extension:change_synced_state(nil)", helper)
        self.assertNotIn('Unit.flow_event(weapon_unit, "cooldown_ready")', helper)
        self.assertIn(
            "stop_inactive_warpfire_effect(inventory_extension, slot_name)",
            self.native,
        )
        self.assertIn('Unit.flow_event(weapon_unit, "wind_up_start")', helper)
        self.assertIn('Unit.flow_event(weapon_unit, "lua_unwield")', helper)
        self.assertIn("Unit.set_unit_visibility(weapon_unit, false)", helper)
        self.assertIn(
            "INACTIVE_WARPFIRE_PARK_OFFSET:unbox()", helper
        )
        self.assertIn(
            "local INACTIVE_WARPFIRE_PARK_OFFSET =\n"
            "    Vector3Box(Vector3(0, 0, -1000))",
            self.native,
        )
        self.assertNotIn(
            "local INACTIVE_WARPFIRE_PARK_OFFSET = Vector3(",
            self.native,
        )
        self.assertIn("state.inactive_warpfire_transforms[weapon_unit]", helper)
        self.assertIn("transform.position:unbox()", helper)
        self.assertIn("parked=%d restored=%d lights_disabled=%d units=%s", helper)

    def test_inherited_versus_equipment_particles_are_removed_at_the_source(self):
        helper = self.native.split(
            "local function clear_linked_particle_metadata", 1
        )[1].split("local function articulation_vector", 1)[0]
        self.assertIn('Unit.has_data(weapon_unit, "particles")', helper)
        self.assertIn("pcall(World.destroy_particles", helper)
        self.assertIn('"particles", "node_part_pairs", 0', helper)
        self.assertIn('Unit.set_data(unit, "has_linked_particles", nil)', helper)
        self.assertIn(
            "suppress_inherited_equipment_particles(extension, unit)",
            self.native,
        )

    def test_weapon_baseline_uses_native_skaven_first_person_contract(self):
        self.assertIn("SKAVEN_FIRST_PERSON_BASE", self.native)
        self.assertIn("PACKMASTER_FIRST_PERSON_ARMS", self.native)
        self.assertIn("skin.first_person = SKAVEN_FIRST_PERSON_BASE", self.native)
        self.assertIn("AttachmentNodeLinking.skaven_first_person_attachment", self.native)
        self.assertIn("if config.native_skaven_first_person then", self.native)
        self.assertIn("native_skaven_baseline", self.native)

    def test_ratling_near_wall_uses_native_controller_without_root_translation(self):
        self.assertNotIn("update_skaven_viewmodel_retraction", self.native)
        self.assertNotIn("SKAVEN_VIEWMODEL_OBSTRUCTION_DISTANCE", self.native)
        self.assertNotIn("Vector3(0, -current, 0)", self.native)
        self.assertIn('event == "near_wall_updated"', self.native)
        self.assertIn("play_first_person_pose(extension, event)", self.native)
        self.assertIn('variable_name == "disable_shooting"', self.native)
        self.assertIn(
            "Unit.animation_find_variable(active_unit, variable_name)",
            self.native,
        )
        self.assertIn(
            "Unit.animation_set_variable(\n"
            "                            active_unit, variable_index, value)",
            self.native,
        )

    def test_native_skaven_first_person_packages_are_resident_before_spawn(self):
        self.assertIn("NATIVE_SKAVEN_FIRST_PERSON_PACKAGES", self.native)
        self.assertIn("ensure_native_skaven_first_person_packages", self.native)
        self.assertIn(
            "Managers.package:load(package_name, NATIVE_SKAVEN_PACKAGE_REFERENCE, nil, false)",
            self.native,
        )
        self.assertIn('Application.can_get("unit", package_name)', self.native)
        self.assertIn("Native Skaven first-person spawn blocked", self.native)
        self.assertIn(
            "Managers.package:unload(package_name, NATIVE_SKAVEN_PACKAGE_REFERENCE)",
            self.native,
        )

    def test_assassin_clip_driver_measures_real_bone_output(self):
        # elapsed/clip_time are wall-clock estimates; only relative hand
        # travel and the roots/view telemetry prove where the controller put
        # the rig. Manual node-0 writes and crossfade playback must never
        # return (v0.6.89-91 evidence: unstable anchor, origin-space and
        # world-frozen blend modes).
        driver = self.native.split(
            "local function update_custom_first_person_clip", 1
        )[1].split("local function update_first_person_weapon_pose", 1)[0]
        self.assertIn('Unit.has_node(animation_unit, "j_righthand")', driver)
        self.assertIn("Vector3.distance(relative_hand, active.previous_hand:unbox())", driver)
        self.assertIn("active.previous_hand = Vector3Box(relative_hand)", driver)
        self.assertNotIn("Unit.crossfade_animation(", driver)
        self.assertIn(
            "hand_travel=%.4f sm=%s view_hand=%s view_cam=%s view_spine=%s",
            driver,
        )
        self.assertNotIn("base_spine - rig_spine", driver)
        self.assertNotIn("Unit.set_local_position(animation_unit, 0,", driver)
        self.assertIn("roots: cam=%s base=%s rig=%s hand=%s", driver)
        self.assertIn(
            "Quaternion.inverse(Unit.world_rotation(camera_unit, 0))", driver
        )
        setup = self.native.split(
            "local function play_custom_first_person_clip", 1
        )[1].split("local function update_custom_first_person_clip", 1)[0]
        self.assertIn("clip_resource = clip.clip,", setup)

    def test_assassin_blade_proxies_present_metal_3p_units(self):
        # The native 1P claw units carry a Versus spectral-glow material that
        # draws nothing in Adventure (issue #46, v0.6.80-84). The visible
        # blades are the self-contained _3p units, spawned locally, linked to
        # Janfon's weapon-attach nodes, package-pinned across item swaps, and
        # following the active rig's visibility every frame.
        self.assertIn("ASSASSIN_BLADE_PROXY_UNITS", self.native)
        self.assertIn("wpn_right_claw_3p", self.native)
        self.assertIn("wpn_left_claw_3p", self.native)
        helper = self.native.split(
            "local function ensure_assassin_blade_proxies", 1
        )[1].split("local function first_person_weapon_attachment_error", 1)[0]
        self.assertIn("unit_spawner:spawn_local_unit(unit_path)", helper)
        self.assertIn(
            "Managers.package:load(\n"
            "                    unit_path, ASSASSIN_BLADE_PROXY_REFERENCE, nil, false)",
            helper,
        )
        self.assertIn("World.link_unit(extension.world, proxy, 0, animation_unit,", helper)
        presentation = self.native.split(
            "local function restore_first_person_weapons", 1
        )[1].split("local DONOR_PACKAGE_REFERENCE", 1)[0]
        self.assertIn("ensure_assassin_blade_proxies(extension, animation_unit)", presentation)
        self.assertIn("proxies=%d/%d", presentation)
        update = self.native.split("_pusfume_assassin_blade_proxies\n", 2)[-1]
        self.assertIn(
            "extension._pusfume_active_skaven_role == ASSASSIN_ROLE",
            self.native.split("local blades_visible = visible == true", 1)[1][:120],
        )
        destroy = self.native.split(
            "local function destroy_dual_first_person_rig", 1
        )[1].split("local function install_first_person_hook", 1)[0]
        self.assertIn("blade_proxies", destroy)
        self.assertIn("mark_for_deletion(blade_proxy)", destroy)
        shutdown = self.native.split("function M.shutdown(config)", 1)[1]
        self.assertIn(
            "Managers.package:unload(unit_path, ASSASSIN_BLADE_PROXY_REFERENCE)",
            shutdown,
        )

    def test_shared_material_dependency_load_stays_retired(self):
        # Dead end (v0.6.83): Application.can_get("package",
        # "resource_packages/common_shaders") is false, so gating the loader
        # on it disabled the entire first-person system. The bundle's shared
        # material payloads are engine-resident in Adventure regardless (the
        # working human-hand child parents D97596A091982F4B from that same
        # bundle), so the load must never return.
        self.assertNotIn("SHARED_MATERIAL_DEPENDENCY_PACKAGES", self.native)
        self.assertNotIn(
            'Managers.package:load("resource_packages/common_shaders"',
            self.native,
        )

    def test_dual_rig_keeps_hero_camera_base_permanent(self):
        switch = self.native.split(
            "local function switch_first_person_rig", 1
        )[1].split("local function prepare_first_person_rig_for_wield", 1)[0]
        self.assertIn(
            "extension._pusfume_active_animation_unit = custom_assassin",
            switch,
        )
        self.assertIn("and attachment_unit or first_person_unit", switch)
        self.assertNotIn("extension.first_person_unit = first_person_unit", switch)
        self.assertNotIn("extension.first_person_attachment_unit = attachment_unit", switch)
        self.assertIn("World.link_unit(", self.native)
        self.assertIn("camera_base=hero", self.native)

    def test_first_person_attachments_bypass_all_or_nothing_link_wrappers(self):
        self.assertIn("local function link_shared_first_person_nodes", self.native)
        self.assertIn("World.link_unit(world, target, target_index, source, source_index)", self.native)
        self.assertIn('"Janfon-160-human"', self.native)
        self.assertIn('"Janfon-99-skaven"', self.native)
        self.assertIn('"Fatshark-native-" .. role', self.native)
        dual_spawn = self.native.split(
            "local function spawn_dual_first_person_rig", 1
        )[1].split("local function first_person_weapon_units", 1)[0]
        self.assertNotIn("AttachmentUtils.link(", dual_spawn)

    def test_initial_wield_selects_the_correct_attachment(self):
        self.assertIn("extension._pusfume_initial_rig_pending = true", self.native)
        self.assertIn("extension.inventory_extension:get_wielded_slot_name()", self.native)
        self.assertIn(
            "prepare_first_person_rig_for_wield(\n                        extension.inventory_extension, wielded_slot)",
            self.native,
        )

    def test_weapon_family_switches_between_native_versus_and_janfon_human_arms(self):
        for role in (
            "packmaster",
            "gutter_runner",
            "globadier",
            "warpfire_thrower",
            "ratling_gunner",
        ):
            self.assertIn(f'{role} = ', self.native)

        self.assertIn("spawn_dual_first_person_rig", self.native)
        self.assertIn('mod:hook(SimpleInventoryExtension, "wield"', self.native)
        self.assertIn(
            "SKAVEN_ROLE_BY_POSE[item_template.pusfume_role_pose]",
            self.native,
        )
        self.assertIn(
            "inventory_extension._first_person_unit = weapon_animation_unit",
            self.native,
        )
        self.assertIn(
            "extension._pusfume_hero_first_person_attachment",
            self.native,
        )
        self.assertIn(
            "extension._pusfume_skaven_first_person_attachment",
            self.native,
        )
        self.assertIn("config.versus_first_person_unit", self.native)
        self.assertIn("config.native_versus_first_person", self.native)
        self.assertIn("skaven_attachments[role] or skaven_attachments.packmaster", self.native)
        self.assertIn("extension._pusfume_skaven_first_person_attachments", self.native)
        self.assertIn("relink_first_person_slot", self.native)
        self.assertIn(
            "weapon_extension.first_person_unit = first_person_unit",
            self.native,
        )
        self.assertIn("relink_damage_unit", self.native)
        self.assertIn(
            "AttachmentNodeLinking.first_person_attachment",
            self.native,
        )
        self.assertIn("dual_rigs_requested", self.native)
        self.assertIn("dual_rigs_ready", self.native)

    def test_direct_weapon_animation_path_rejects_missing_events(self):
        self.assertIn(
            'mod:hook(WeaponUnitExtension, "_play_1p_anim"', self.native
        )
        self.assertIn("local custom_event = event_1p or event", self.native)
        self.assertIn("local native_event = event or event_1p", self.native)
        self.assertIn("skip_missing_first_person_event", self.native)

    def test_assassin_clips_crossfade_on_the_active_skaven_rig(self):
        self.assertIn("local function play_custom_first_person_clip", self.native)
        self.assertIn('extension._pusfume_active_skaven_role ~= "gutter_runner"', self.native)
        self.assertIn("extension._pusfume_active_animation_unit", self.native)
        self.assertIn("Unit.crossfade_animation(", self.native)
        self.assertIn("play_custom_first_person_clip(extension, event)", self.native)
        self.assertIn(
            "play_custom_first_person_clip(\n                        first_person_extension, custom_event)",
            self.native,
        )
        self.assertIn("local custom_event = event_1p or event", self.native)
        self.assertIn('mod:hook(WeaponUnitExtension, "_play_end_event_1p"', self.native)

    def test_assassin_clips_use_one_pose_player(self):
        # The clips replay from baked pose data (engine playback re-anchors
        # this unit at the world origin); the compiled controller stays
        # permanently disabled from spawn.
        self.assertIn("ASSASSIN_CLIP_TARGET_DURATION", self.native)
        self.assertNotIn("_pusfume_assassin_disabled_state_machine_unit", self.native)
        self.assertNotIn(
            "Unit.enable_animation_state_machine(attachment_unit)", self.native
        )
        self.assertIn("update_custom_first_person_clip(extension, t)", self.native)
        self.assertIn("previous.event == event_name and clip.loop == true", self.native)
        self.assertIn("Janfon assassin pose player enabled", self.native)

    def test_assassin_clips_target_janfon_attachment_not_skaven_base(self):
        switch = self.native.split(
            "local function switch_first_person_rig", 1
        )[1].split("local function prepare_first_person_rig_for_wield", 1)[0]
        self.assertIn('role == "gutter_runner"', switch)
        self.assertIn(
            "custom_assassin\n        and attachment_unit or first_person_unit",
            switch,
        )
        # The assassin attachment stays UNLINKED: the animation player
        # composes tracked bones in the unit's own directly-set world
        # transform and ignores scene-graph links (v0.6.90/92 roots
        # telemetry), so the per-frame update mirrors the camera directly.
        self.assertIn(
            "World.unlink_unit(extension.world, attachment_unit)", switch
        )
        self.assertIn(
            "Unit.world_position(extension.first_person_unit, 0)", switch
        )
        self.assertIn(
            "AttachmentNodeLinking.skaven_first_person_attachment", switch
        )

    def test_controllerless_pusfume_start_action_suppresses_direct_equip_interrupt(self):
        hook = self.native.split(
            'mod:hook(WeaponUnitExtension, "start_action"', 1
        )[1].split('mod:hook(WeaponUnitExtension, "_play_1p_anim"', 1)[0]
        self.assertIn("weapon_extension.first_person_unit", hook)
        self.assertIn("_pusfume_first_person", hook)
        self.assertIn("Unit.has_animation_state_machine(event_unit)", hook)
        self.assertIn("action_settings.looping_anim = true", hook)
        self.assertIn("action_settings.looping_anim = previous_looping", hook)

    def test_animation_guard_checks_the_active_rig_not_only_the_camera_base(self):
        guard = self.native.split(
            "local function skip_missing_first_person_event", 1
        )[1].split("local function set_unit_visible", 1)[0]
        self.assertIn("extension._pusfume_active_animation_unit", guard)
        self.assertIn("first_person_has_event and active_has_event", guard)
        self.assertIn("unit_has_animation_event(active_animation_unit, event)", guard)

    def test_animation_event_queries_reject_controllerless_manual_clip_unit(self):
        helper = self.native.split(
            "local function unit_has_animation_event", 1
        )[1].split("local function play_first_person_pose", 1)[0]
        self.assertIn("Unit.has_animation_state_machine(unit)", helper)
        self.assertIn("Unit.has_animation_event(unit, event_name)", helper)
        guard = self.native.split(
            "local function skip_missing_first_person_event", 1
        )[1].split("local function set_unit_visible", 1)[0]
        self.assertNotIn("Unit.has_animation_event(", guard)

    def test_first_person_probe_rearms_when_weapon_family_changes(self):
        self.assertIn(
            "extension._pusfume_active_first_person_rig ~= rig_name",
            self.native,
        )
        self.assertIn(
            "extension._pusfume_first_person_probe_logged = nil",
            self.native,
        )
        self.assertIn(
            "extension._pusfume_first_person_probe_frames = 0",
            self.native,
        )
        self.assertIn(
            "extension._pusfume_weapon_presentation_ready = nil",
            self.native,
        )

    def test_selector_name_is_guarded_at_final_write(self):
        self.assertIn('mod:hook(class, "_set_hero_info"', self.ui)
        self.assertIn('hero_name = mod:localize("pusfume_character_name")', self.ui)
        self.assertIn("install_identity_write_guard(HeroWindowCharacterSelectionConsole", self.ui)
        self.assertIn("install_identity_write_guard(CharacterSelectionStateCharacter", self.ui)
        self.assertIn("hero_widget.content.text", self.ui)
        self.assertIn("state.identity_widget_seen = true", self.ui)
        self.assertIn('mod:hook_safe(CharacterSelectionView, "set_current_hero"', self.ui)
        self.assertIn('mod:hook_safe(HeroWindowCharacterInfo, "_update_hero_portrait_frame"', self.ui)
        self.assertIn('mod:hook_safe(HeroViewStateLoot, "_setup_info_window"', self.ui)
        self.assertNotIn("profile.character_name =", self.ui)

    def test_live_hud_reasserts_custom_portrait_after_other_mod_hooks(self):
        self.assertIn('mod:hook_safe(UnitFramesHandler, "_sync_player_stats"', self.ui)
        self.assertIn('career_name ~= registry.CAREER_NAME', self.ui)
        self.assertIn('widget:set_portrait("portrait_pusfume")', self.ui)
        self.assertIn("state.hud_portrait_seen = true", self.ui)


if __name__ == "__main__":
    unittest.main()
