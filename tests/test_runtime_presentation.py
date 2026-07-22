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
        self.assertIn('Unit.has_animation_event(first_person_unit, "to_armed")', helper)
        self.assertIn('Unit.animation_has_variable(first_person_unit, "armed")', helper)
        self.assertIn('extension:animation_set_variable("armed", 1)', helper)
        self.assertIn("update_first_person_weapon_pose(extension, equipment)", helper)
        self.assertIn("item_template.pusfume_role_pose", self.native)
        self.assertIn('wielded_slot == "slot_melee" and "to_packmaster"', self.native)
        self.assertIn('wielded_slot == "slot_ranged" and "to_warpfire_thrower"', self.native)
        self.assertNotIn("to_packmaster_claw", self.native)
        self.assertIn("extension._pusfume_weapon_hide_pending = false", self.native)
        self.assertIn("restore_first_person_weapons(extension)", self.native)

    def test_weapon_baseline_uses_native_skaven_first_person_contract(self):
        self.assertIn("SKAVEN_FIRST_PERSON_BASE", self.native)
        self.assertIn("PACKMASTER_FIRST_PERSON_ARMS", self.native)
        self.assertIn("skin.first_person = SKAVEN_FIRST_PERSON_BASE", self.native)
        self.assertIn("AttachmentNodeLinking.skaven_first_person_attachment", self.native)
        self.assertIn("if config.native_skaven_first_person then", self.native)
        self.assertIn("native_skaven_baseline", self.native)

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

    def test_dual_rig_keeps_hero_camera_base_permanent(self):
        switch = self.native.split(
            "local function switch_first_person_rig", 1
        )[1].split("local function prepare_first_person_rig_for_wield", 1)[0]
        self.assertIn("extension._pusfume_active_animation_unit = first_person_unit", switch)
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
            "inventory_extension._first_person_unit = first_person_unit",
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
        self.assertIn("local actual_event = event or event_1p", self.native)
        self.assertIn("skip_missing_first_person_event", self.native)

    def test_animation_guard_checks_the_active_rig_not_only_the_camera_base(self):
        guard = self.native.split(
            "local function skip_missing_first_person_event", 1
        )[1].split("local function set_unit_visible", 1)[0]
        self.assertIn("extension._pusfume_active_animation_unit", guard)
        self.assertIn("first_person_has_event and active_has_event", guard)
        self.assertIn("Unit.has_animation_event(active_animation_unit, event)", guard)

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
