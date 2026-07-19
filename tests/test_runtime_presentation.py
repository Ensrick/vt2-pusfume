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
        self.assertIn('career.sound_character = "dwarf_slayer"', self.registry)

    def test_first_person_weapons_are_restored_for_prototype_loadout(self):
        self.assertIn('FIRST_PERSON_WEAPON_HIDE_REASON = "pusfume_hands_diagnostic"', self.native)
        helper = self.native.split("local function restore_first_person_weapons", 1)[1].split(
            "local DONOR_PACKAGE_REFERENCE", 1
        )[0]

        self.assertIn("if not extension.inventory_extension then", helper)
        self.assertIn("extension:hide_weapons(FIRST_PERSON_WEAPON_HIDE_REASON, false)", helper)
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

    def test_native_skaven_rig_never_receives_bardin_state_machine(self):
        self.assertIn(
            "local donor_default_state_machine = profile.default_state_machine",
            self.native,
        )
        self.assertIn("profile.default_state_machine = nil", self.native)
        self.assertIn("profile.default_state_machine = donor_default_state_machine", self.native)
        self.assertIn(
            'mod:hook(PlayerUnitFirstPerson, "set_state_machine"',
            self.native,
        )
        self.assertIn(
            "new_state_machine == extension._pusfume_donor_default_state_machine",
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
