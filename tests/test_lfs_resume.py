import importlib.util,json,pathlib,sys,tempfile,unittest
P=pathlib.Path(__file__).parents[1]/'build/pipeline.py'
s=importlib.util.spec_from_file_location('lfs_pipeline',P);m=importlib.util.module_from_spec(s);s.loader.exec_module(m)
def package(name,value=None):return {'script':name+'.sh','phase':'chroot','fingerprint':value or name}
class PendingLfsTests(unittest.TestCase):
 def setup_state(self,d):
  root=pathlib.Path(d);state=root/'pipeline-state';done=root/'lfs/build-done';logs=root/'lfs/build-logs'
  done.mkdir(parents=True);logs.mkdir(parents=True)
  old={'control':'same-builder-and-executor','packages':[package('compiler'),package('manuals')]}
  r=m.Runner(state,'pi4-arm64','old',fingerprints={'lfs':'old'},lfs_plan=old)
  (state/'lfs.log').touch();(done/'compiler.sh').touch();(logs/'manuals.log').touch()
  return state,old
 def test_add_missing_pending_dependency_without_rebuilding_compiler(self):
  with tempfile.TemporaryDirectory() as d:
   state,old=self.setup_state(d)
   new=dict(old,packages=[package('compiler'),package('pipeline-library'),package('manuals')])
   r=m.Runner(state,'pi4-arm64','new',fingerprints={'lfs':'new'},lfs_plan=new)
   self.assertTrue((state.parent/'lfs/build-done/compiler.sh').exists())
 def test_changed_compiler_or_reordering_before_completed_package_rejected(self):
  for packages in [[package('compiler','modified'),package('manuals')],[package('extra'),package('compiler'),package('manuals')]]:
   with tempfile.TemporaryDirectory() as d:
    state,old=self.setup_state(d)
    with self.assertRaises(ValueError):m.Runner(state,'pi4-arm64','new',fingerprints={'lfs':'new'},lfs_plan=dict(old,packages=packages))
 def test_modified_active_package_or_builder_rejected(self):
  for new in [{'control':'changed','packages':[package('compiler'),package('manuals')]},{'control':'same-builder-and-executor','packages':[package('compiler'),package('manuals','modified')]}]:
   with tempfile.TemporaryDirectory() as d:
    state,old=self.setup_state(d)
    with self.assertRaises(ValueError):m.Runner(state,'pi4-arm64','new',fingerprints={'lfs':'new'},lfs_plan=new)
 def test_completed_lfs_stage_cannot_be_reopened_with_new_package(self):
  with tempfile.TemporaryDirectory() as d:
   state,old=self.setup_state(d);(state/'lfs.done').touch()
   new=dict(old,packages=[package('compiler'),package('manuals'),package('extra')])
   with self.assertRaises(ValueError):m.Runner(state,'pi4-arm64','new',fingerprints={'lfs':'new'},lfs_plan=new)
 def test_bootstrap_compiler_checkpoint_is_protected(self):
  with tempfile.TemporaryDirectory() as d:
   root=pathlib.Path(d);state=root/'pipeline-state';(root/'done').mkdir();(root/'logs').mkdir()
   compiler=dict(package('compiler'),phase='bootstrap')
   old={'control':'same','packages':[compiler,package('manuals')]}
   m.Runner(state,'amd64','old',fingerprints={'lfs':'old'},lfs_plan=old)
   (state/'lfs.log').touch();(root/'done/compiler.sh').touch()
   bad=dict(old,packages=[dict(compiler,fingerprint='changed'),package('manuals')])
   with self.assertRaises(ValueError):m.Runner(state,'amd64','bad',fingerprints={'lfs':'bad'},lfs_plan=bad)
   good=dict(old,packages=[compiler,package('library'),package('manuals')])
   m.Runner(state,'amd64','new',fingerprints={'lfs':'new'},lfs_plan=good)
 def test_missing_previous_package_inputs_cannot_be_synthesized_from_new_source(self):
  with tempfile.TemporaryDirectory() as d:
   state=pathlib.Path(d)/'pipeline-state'
   m.Runner(state,'amd64','old',fingerprints={'lfs':'old'});(state/'lfs.log').touch()
   plan={'control':'same','packages':[package('library')]}
   with self.assertRaises(ValueError):m.Runner(state,'amd64','new',fingerprints={'lfs':'new'},lfs_plan=plan)
