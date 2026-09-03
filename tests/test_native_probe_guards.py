import pathlib
import unittest


ROOT = pathlib.Path(__file__).resolve().parents[1]
NATIVE_LUA = (
    ROOT / "pusfume" / "scripts" / "mods" / "pusfume" / "_pusfume_native.lua"
)


class NativeProbeGuardTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.source = NATIVE_LUA.read_text(encoding="utf-8")

    def test_root_isolated_probe_uses_native_skaven_hand(self):
        self.assertIn("local NATIVE_PROBE_LINKS", self.source)
        self.assertIn('{ source = "j_lefthand", target = "j_lefthand" }', self.source)
        self.assertIn("config.root_animation_isolation", self.source)

    def test_probe_checks_nodes_before_stingray_lookup(self):
        self.assertIn(
            "if Unit.has_node(unit, link.source) and Unit.has_node(mesh, link.target) then",
            self.source,
        )
        self.assertIn(
            "if not Unit.has_node(unit, hips_node) or not Unit.has_node(unit, hand_node) then",
            self.source,
        )

    def test_first_person_probe_checks_both_nodes_before_lookup(self):
        self.assertIn(
            "if Unit.has_node(source, node_pair.source)\n"
            "                and Unit.has_node(target, node_pair.target) then",
            self.source,
        )
        self.assertIn(
            '"%s->%s=unavailable", node_pair.source, node_pair.target',
            self.source,
        )

    def test_manual_probe_node_is_guarded(self):
        self.assertIn('if Unit.has_node(mesh, "j_spine1") then', self.source)
        self.assertIn("Manual skin deformation probe skipped", self.source)


if __name__ == "__main__":
    unittest.main()
