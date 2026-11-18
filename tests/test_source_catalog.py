import pathlib,unittest
from urllib.parse import urlparse
R=pathlib.Path(__file__).parents[1]
class SourceCatalogTests(unittest.TestCase):
 def test_downloads_match_verified_systemd_sources(self):
  checks={l.split()[1].lstrip('*') for l in (R/'research/md5sums').read_text().splitlines() if l.strip()}
  downloads={pathlib.PurePosixPath(urlparse(u).path).name for u in (R/'research/wget-list').read_text().splitlines() if u.strip()}
  self.assertEqual(downloads,checks)
 def test_man_db_dependency_is_in_both_architecture_plans(self):
  import json
  for directory in ['build/scripts','experimental/amd64/scripts']:
   names=[x['script'] for x in json.loads((R/directory/'order.json').read_text())]
   self.assertLess(names.index('chapter08-libpipeline.sh'),names.index('chapter08-man-db.sh'))
