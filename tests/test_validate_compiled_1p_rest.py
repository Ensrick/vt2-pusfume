import unittest

from tools.stingray_unit_scene import short_hash
from tools.validate_compiled_1p_rest import matrix_error, select_rest_contract


class CompiledFirstPersonRestTests(unittest.TestCase):
    def test_matrix_error_detects_basis_scale_regression(self):
        donor = (1.0, 0.0, 0.0, 0.0) * 4
        scaled = (100.0, 0.0, 0.0, 0.0) + donor[4:]
        self.assertEqual(99.0, matrix_error(scaled, donor))

    def test_matrix_error_accepts_small_compiler_noise(self):
        donor = tuple(float(index) for index in range(16))
        custom = tuple(value + 0.00001 for value in donor)
        self.assertAlmostEqual(0.00001, matrix_error(custom, donor))

    def test_legacy_rig_requires_the_spine_override_contract(self):
        contract, minimum, overrides = select_rest_contract(
            {short_hash("j_spine1")}, {short_hash("j_spine2")}
        )
        self.assertEqual("legacy-spine-override", contract)
        self.assertEqual(53, minimum)
        self.assertEqual({"j_spine1": "j_spine2"}, overrides)

    def test_human_rig_uses_same_name_spine_contract(self):
        contract, minimum, overrides = select_rest_contract(
            {short_hash("j_spine2")}, {short_hash("j_spine2")}
        )
        self.assertEqual("human-same-name", contract)
        self.assertEqual(52, minimum)
        self.assertEqual({}, overrides)

    def test_skaven_rig_uses_same_name_spine_contract(self):
        contract, minimum, overrides = select_rest_contract(
            {short_hash("j_spine1")}, {short_hash("j_spine1")}
        )
        self.assertEqual("skaven-same-name", contract)
        self.assertEqual(53, minimum)
        self.assertEqual({}, overrides)


if __name__ == "__main__":
    unittest.main()
