"""The desktop source cache can share inodes with the base cache."""
from pathlib import Path
import os, subprocess, tempfile, unittest

class WpaArchiveTests(unittest.TestCase):
 def test_shared_archive_does_not_abort_recipe(self):
  with tempfile.TemporaryDirectory() as d:
   root=Path(d);base=root/'lfs';desktop=root/'desktop-lfs'
   for p in (base,desktop):(p/'sources').mkdir(parents=True)
   source=base/'sources/wpa_supplicant-2.11.tar.gz';source.write_bytes(b'archive')
   os.link(source,desktop/'sources'/source.name)
   recipe=(Path(__file__).parents[1]/'desktop/wpa-dbus.sh').read_text().split('mkdir -p',1)[0]
   recipe=recipe.replace('/build/desktop-lfs',str(desktop)).replace('/build/lfs',str(base))
   result=subprocess.run(['bash','-c',recipe],capture_output=True,text=True)
   self.assertEqual(result.returncode,0,result.stderr)
   self.assertEqual(source.read_bytes(),b'archive')
