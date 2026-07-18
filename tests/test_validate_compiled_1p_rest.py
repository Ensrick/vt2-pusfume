import unittest

from tools.validate_compiled_1p_rest import matrix_error


class CompiledFirstPersonRestTests(unittest.TestCase):
    def test_matrix_error_detects_basis_scale_regression(self):
        donor = (1.0, 0.0, 0.0, 0.0) * 4
        scaled = (100.0, 0.0, 0.0, 0.0) + donor[4:]
        self.assertEqual(99.0, matrix_error(scaled, donor))

    def test_matrix_error_accepts_small_compiler_noise(self):
        donor = tuple(float(index) for index in range(16))
        custom = tuple(value + 0.00001 for value in donor)
        self.assertAlmostEqual(0.00001, matrix_error(custom, donor))


if __name__ == "__main__":
    unittest.main()
