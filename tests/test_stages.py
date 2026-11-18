import importlib.util,pathlib,unittest
from unittest.mock import patch
spec=importlib.util.spec_from_file_location('stages',pathlib.Path(__file__).parents[1]/'build/stages.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class ResumeTests(unittest.TestCase):
 def test_guest_restores_virtual_filesystems_after_container_restart(self):
  root=pathlib.Path('/isolated/root')
  with patch.object(m,'mounts') as mounts,patch.object(m,'run') as run:
   m.guest(root,'rustc','--version')
   mounts.assert_called_once_with(root)
   self.assertEqual(run.call_args.args[:2],('chroot',root))

class DnsTests(unittest.TestCase):
 def test_build_dns_preserves_runtime_resolver_symlink(self):
  import tempfile,os
  with tempfile.TemporaryDirectory() as d:
   root=pathlib.Path(d);(root/'etc').mkdir()
   resolver=root/'etc/resolv.conf';resolver.symlink_to('/run/systemd/resolve/stub-resolv.conf')
   with patch.object(m.subprocess,'call',return_value=0),patch.object(m,'run'):
    m.mounts(root)
   self.assertTrue(resolver.is_symlink())
   self.assertTrue((root/'run/systemd/resolve/stub-resolv.conf').is_file())

class PcGraphicsTests(unittest.TestCase):
 def test_pc_pci_dependency_precedes_gpu_libraries(self):
  packages=[{'name':n} for n in ['wayland','libdrm','pixman','libpciaccess','mesa']]
  names=[p['name'] for p in m.desktop_package_order('amd64',packages)]
  self.assertLess(names.index('libpciaccess'),names.index('libdrm'))
  self.assertEqual(len(names),len(set(names)))
 def test_pc_recipe_enables_intel_and_amd_libraries(self):
  source=(pathlib.Path(__file__).parents[1]/'desktop/generated/libdrm.sh').read_text()
  recipe=m.desktop_recipe('amd64',source)
  for flag in ['-Dintel=enabled','-Dradeon=enabled','-Damdgpu=enabled']:
   self.assertIn(flag,recipe)
  self.assertEqual(m.desktop_recipe('pi4-arm64',source),source)
