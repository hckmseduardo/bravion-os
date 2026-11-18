import importlib.util,pathlib,tempfile,shutil,unittest
R=pathlib.Path(__file__).parents[1]
spec=importlib.util.spec_from_file_location('fingerprints',R/'build/fingerprints.py')
m=importlib.util.module_from_spec(spec);spec.loader.exec_module(m)
class FingerprintTests(unittest.TestCase):
 def test_future_runtime_correction_does_not_change_compiler_inputs(self):
  with tempfile.TemporaryDirectory() as d:
   p=pathlib.Path(d)/'repo';shutil.copytree(R,p,ignore=shutil.ignore_patterns('.git','target','__pycache__','logs'))
   old=m.stage_fingerprints(p,'pi4-arm64')
   f=p/'build/stages.py';f.write_text(f.read_text().replace('def runtimes(target):','def runtimes(target):\n print("new runtime dependency")'))
   new=m.stage_fingerprints(p,'pi4-arm64')
   self.assertEqual(old['lfs'],new['lfs']);self.assertNotEqual(old['runtimes'],new['runtimes'])
 def test_shared_guest_execution_change_invalidates_compiler_stage(self):
  with tempfile.TemporaryDirectory() as d:
   p=pathlib.Path(d)/'repo';shutil.copytree(R,p,ignore=shutil.ignore_patterns('.git','target','__pycache__','logs'))
   old=m.stage_fingerprints(p,'amd64')
   f=p/'build/stages.py';f.write_text(f.read_text().replace('def guest(root,*args,**kw):','def guest(root,*args,**kw):\n print("changed guest environment")'))
   new=m.stage_fingerprints(p,'amd64')
   self.assertNotEqual(old['lfs'],new['lfs'])
 def test_empty_new_python_ast_fields_do_not_invalidate_sources(self):
  import ast
  node=ast.parse('def sample():\n return 1').body[0]
  original=m.ast_text(node)
  node.type_params=[]
  self.assertEqual(m.ast_text(node),original)
 def test_builder_and_launcher_changes_invalidate_their_consumers(self):
  with tempfile.TemporaryDirectory() as d:
   p=pathlib.Path(d)/'repo';shutil.copytree(R,p,ignore=shutil.ignore_patterns('.git','target','__pycache__','logs'))
   old=m.stage_fingerprints(p,'amd64')
   f=p/'desktop/brave-launcher.sh';f.write_text(f.read_text()+'\nexit 7\n')
   changed=m.stage_fingerprints(p,'amd64')
   self.assertNotEqual(old['configuration'],changed['configuration'])
   f=p/'build/Dockerfile';f.write_text(f.read_text()+'\nRUN true\n')
   newer=m.stage_fingerprints(p,'amd64')
   self.assertNotEqual(changed['lfs'],newer['lfs'])
 def test_unknown_build_input_fails_closed(self):
  with tempfile.TemporaryDirectory() as d:
   p=pathlib.Path(d)/'repo';shutil.copytree(R,p,ignore=shutil.ignore_patterns('.git','target','__pycache__','logs'))
   old=m.stage_fingerprints(p,'amd64')
   (p/'build/new-compiler-input').write_text('new')
   self.assertNotEqual(old['lfs'],m.stage_fingerprints(p,'amd64')['lfs'])
 def test_individual_lfs_recipe_changes_preserve_controller_fingerprint(self):
  with tempfile.TemporaryDirectory() as d:
   p=pathlib.Path(d)/'repo';shutil.copytree(R,p,ignore=shutil.ignore_patterns('.git','target','__pycache__','logs'))
   old=m.lfs_inputs(p,'pi4-arm64')
   f=p/'build/scripts/chapter08-libpipeline.sh';f.write_text(f.read_text()+'\nprintf dependency\n')
   new=m.lfs_inputs(p,'pi4-arm64')
   self.assertEqual(old['control'],new['control'])
   before={x['script']:x['fingerprint'] for x in old['packages']};after={x['script']:x['fingerprint'] for x in new['packages']}
   self.assertNotEqual(before['chapter08-libpipeline.sh'],after['chapter08-libpipeline.sh'])
   self.assertEqual(before['chapter08-gcc.sh'],after['chapter08-gcc.sh'])
 def test_mirror_only_update_preserves_archive_identity_but_hash_change_does_not(self):
  import json
  with tempfile.TemporaryDirectory() as d:
   p=pathlib.Path(d)/'repo';shutil.copytree(R,p,ignore=shutil.ignore_patterns('.git','target','__pycache__','logs'))
   old=m.stage_fingerprints(p,'pi4-arm64');f=p/'desktop/manifest.json';data=json.loads(f.read_text())
   data['packages'][0]['url']='https://example.org/verified-mirror/archive.tar.gz';f.write_text(json.dumps(data))
   new=m.stage_fingerprints(p,'pi4-arm64');self.assertEqual(old['desktop-packages'],new['desktop-packages'])
   data['packages'][0]['sha256']='0'*64;f.write_text(json.dumps(data))
   self.assertNotEqual(old['desktop-packages'],m.stage_fingerprints(p,'pi4-arm64')['desktop-packages'])
