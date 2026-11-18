import importlib.util, pathlib, tempfile, unittest, sys
P=pathlib.Path(__file__).parents[1]/'build'/'pipeline.py'
spec=importlib.util.spec_from_file_location('pipeline',P)
m=importlib.util.module_from_spec(spec);sys.modules['pipeline']=m;spec.loader.exec_module(m)
class PipelineTests(unittest.TestCase):
 def test_failed_command_is_not_a_completed_checkpoint(self):
  with tempfile.TemporaryDirectory() as d:
   r=m.Runner(pathlib.Path(d),'pi4-arm64','same-source')
   with self.assertRaises(Exception):r.run('compile',[sys.executable,'-c','raise SystemExit(4)'])
   self.assertFalse(r.completed('compile'))
 def test_resume_skips_success_without_rerunning_side_effect(self):
  with tempfile.TemporaryDirectory() as d:
   p=pathlib.Path(d);r=m.Runner(p,'amd64','source');f=p/'count'
   command=[sys.executable,'-c',f'from pathlib import Path; p=Path({str(f)!r}); p.write_text(p.read_text()+"x" if p.exists() else "x")']
   r.run('compile',command);r.run('compile',command)
   self.assertEqual(f.read_text(),'x')
 def test_different_architecture_cannot_reuse_build_state(self):
  with tempfile.TemporaryDirectory() as d:
   m.Runner(pathlib.Path(d),'pi4-arm64','source')
   with self.assertRaises(ValueError):m.Runner(pathlib.Path(d),'amd64','source')
 def test_source_change_cannot_reuse_successful_state(self):
  with tempfile.TemporaryDirectory() as d:
   m.Runner(pathlib.Path(d),'amd64','old')
   with self.assertRaises(ValueError):m.Runner(pathlib.Path(d),'amd64','new')
 def test_every_target_plans_a_complete_image_not_just_a_rootfs(self):
  for target in ['pi4-arm64','parallels-arm64','amd64']:
   plan=m.plan(target)
   self.assertEqual(plan[-1][0],'verify-artifacts')
   for needed in ['lfs','desktop','cosmic','branding','package','compress']:
    self.assertIn(needed,[name for name,_ in plan])
if __name__=='__main__':unittest.main()

class SafeSourceUpdateTests(unittest.TestCase):
 def test_future_stage_fix_keeps_verified_checkpoints(self):
  with tempfile.TemporaryDirectory() as d:
   p=pathlib.Path(d);old={'base':'same','desktop':'old'}
   r=m.Runner(p,'amd64','old-source',fingerprints=old)
   r.run('base',[sys.executable,'-c','pass'])
   newer=m.Runner(p,'amd64','new-source',fingerprints={'base':'same','desktop':'fixed'})
   self.assertTrue(newer.completed('base'))
   self.assertEqual(__import__('json').loads((p/'identity.json').read_text())['source'],'new-source')
 def test_completed_stage_source_change_is_rejected(self):
  with tempfile.TemporaryDirectory() as d:
   r=m.Runner(d,'amd64','old',fingerprints={'base':'old'})
   r.run('base',[sys.executable,'-c','pass'])
   with self.assertRaises(ValueError):m.Runner(d,'amd64','new',fingerprints={'base':'changed'})
 def test_started_failed_stage_source_change_is_rejected(self):
  with tempfile.TemporaryDirectory() as d:
   r=m.Runner(d,'amd64','old',fingerprints={'base':'old'})
   with self.assertRaises(Exception):r.run('base',[sys.executable,'-c','raise SystemExit(3)'])
   with self.assertRaises(ValueError):m.Runner(d,'amd64','new',fingerprints={'base':'changed'})

class ModeChangeTests(unittest.TestCase):
 def test_same_digest_does_not_bypass_changed_executable_mode(self):
  with tempfile.TemporaryDirectory() as d:
   r=m.Runner(d,'amd64','same-digest',fingerprints={'configuration':'mode-755'})
   r.run('configuration',[sys.executable,'-c','pass'])
   with self.assertRaises(ValueError):m.Runner(d,'amd64','same-digest',fingerprints={'configuration':'mode-644'})
