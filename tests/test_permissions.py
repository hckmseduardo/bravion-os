import importlib.util
from pathlib import Path
import unittest
class PermissionTests(unittest.TestCase):
    def test_normalizes_public_writes_but_preserves_special_modes(self):
        path=Path(__file__).parents[1]/'build'/'normalize_target.py'
        self.assertTrue(path.exists(),'permission normalizer must exist')
        spec=importlib.util.spec_from_file_location('permissions',path)
        m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
        self.assertEqual(m.normalized_mode(0o777),0o755)
        self.assertEqual(m.normalized_mode(0o666),0o644)
        self.assertEqual(m.normalized_mode(0o1777),0o1777)
        self.assertEqual(m.normalized_mode(0o4755),0o4755)
        self.assertEqual(m.normalized_mode(0o664),0o664)
if __name__=='__main__':unittest.main()
