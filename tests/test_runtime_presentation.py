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

    def test_first_person_weapons_stay_hidden_for_hand_test(self):
        self.assertIn('FIRST_PERSON_WEAPON_HIDE_REASON = "pusfume_hands_diagnostic"', self.native)
        helper = self.native.split("local function hide_first_person_weapons", 1)[1].split(
            "local DONOR_PACKAGE_REFERENCE", 1
        )[0]
        init_hook = self.native.split('mod:hook(PlayerUnitFirstPerson, "init"', 1)[1].split(
            'mod:hook_safe(PlayerUnitFirstPerson, "update"', 1
        )[0]

        self.assertIn("if not extension.inventory_extension then", helper)
        self.assertIn("extension:hide_weapons(FIRST_PERSON_WEAPON_HIDE_REASON, true)", helper)
        self.assertNotIn("extension:hide_weapons", init_hook)
        self.assertIn("extension._pusfume_weapon_hide_pending = true", init_hook)
        self.assertIn("hide_first_person_weapons(extension)", self.native)

    def test_selector_name_is_guarded_at_final_write(self):
        self.assertIn('mod:hook(class, "_set_hero_info"', self.ui)
        self.assertIn('hero_name = mod:localize("pusfume_character_name")', self.ui)
        self.assertIn("install_identity_write_guard(HeroWindowCharacterSelectionConsole", self.ui)
        self.assertIn("install_identity_write_guard(CharacterSelectionStateCharacter", self.ui)
        self.assertIn("hero_widget.content.text", self.ui)
        self.assertIn("state.identity_widget_seen = true", self.ui)

    def test_live_hud_reasserts_custom_portrait_after_other_mod_hooks(self):
        self.assertIn('mod:hook_safe(UnitFramesHandler, "_sync_player_stats"', self.ui)
        self.assertIn('career_name ~= registry.CAREER_NAME', self.ui)
        self.assertIn('widget:set_portrait("portrait_pusfume")', self.ui)
        self.assertIn("state.hud_portrait_seen = true", self.ui)


if __name__ == "__main__":
    unittest.main()
