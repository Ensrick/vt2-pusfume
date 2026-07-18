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
        self.assertGreaterEqual(
            self.native.count("extension:hide_weapons(FIRST_PERSON_WEAPON_HIDE_REASON, true)"),
            2,
        )

    def test_selector_name_is_guarded_at_final_write(self):
        self.assertIn('mod:hook(class, "_set_hero_info"', self.ui)
        self.assertIn('hero_name = mod:localize("pusfume_character_name")', self.ui)
        self.assertIn("install_identity_write_guard(HeroWindowCharacterSelectionConsole", self.ui)
        self.assertIn("install_identity_write_guard(CharacterSelectionStateCharacter", self.ui)


if __name__ == "__main__":
    unittest.main()
