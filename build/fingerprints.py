"""Inputs for safe updates to stages which have never started.

Completed and partially executed stages remain immutable. The controller can
accept a correction to a future stage without discarding an identical LFS base.
"""
from pathlib import Path
import ast,hashlib,stat,json,re
FILES={
 'sources':['build/fetch-sources.sh','research'],
 'lfs':['build/bootstrap.sh'],
 'blfs':['build/blfs.sh','build/configure-image.sh','build/cleanup-target.py','build/pi_setup.py'],
 'kernel':['scripts/kernel.sh','kernel','patches/kernel','build/firmware.sh'],
 'desktop':['desktop/prepare.sh'],
 'runtimes':['build/runtimes.json','build/python-build.json'],
 'desktop-packages':['desktop/manifest.json','desktop/generated','desktop/wpa-dbus.sh'],
 'cosmic':['desktop/cosmic-build.sh','scripts/apply-cosmic-patches.py','patches/cosmic','desktop/hydrate-wallpapers.py'],
 'configuration':['desktop/network-audio-configure.sh','desktop/pi_desktop_setup.py','desktop/pi-wifi-country.service','desktop/cosmic-integration.sh','desktop/brave-launcher.sh','desktop/flatpak-install.sh','rootfs','scripts/parallels-tools.py','build/pi_setup.py','build/runtimes.json'],
 'branding':['ai-tools','branding','licenses','LICENSE','THIRD_PARTY.md','research/LFS-MIT-license.html','desktop/strip-debug.py','desktop/normalize_target.py'],
 'package':['desktop/package-desktop.sh'],
 'compress':['scripts/artifacts.py','templates'],
 'verify-artifacts':['scripts/artifacts.py','scripts/boot-probe.py'],
}
def canonical_ast(value):
 # Python 3.12 added empty type_params fields; ignore absent/empty fields so
 # a host Python upgrade alone cannot invalidate otherwise identical inputs.
 if isinstance(value,ast.AST):
  return dict(node=type(value).__name__,fields={k:canonical_ast(v) for k,v in ast.iter_fields(value) if v is not None and v!=[]})
 if isinstance(value,list):return [canonical_ast(v) for v in value]
 if isinstance(value,bytes):return {'bytes':value.hex()}
 return value
def ast_text(node):return json.dumps(canonical_ast(node),sort_keys=True,separators=(',',':'))
SOURCE_DIRS=['build','desktop','kernel','patches','rootfs','ai-tools','branding','scripts','research','templates','licenses','experimental/amd64']
def expanded(repo,paths):
 result=[]
 for name in paths:
  p=repo/name
  result.extend(sorted(p.rglob('*')) if p.is_dir() and not p.is_symlink() else [p])
 return [p for p in result if (not p.is_dir() or p.is_symlink()) and '__pycache__' not in p.parts and 'target' not in p.relative_to(repo).parts]
def stage_fingerprints(repo,target,include_lfs_packages=True):
 repo=Path(repo);tree=ast.parse((repo/'build/stages.py').read_text())
 functions={n.name:n for n in tree.body if isinstance(n,(ast.FunctionDef,ast.AsyncFunctionDef))}
 common='\n'.join(ast_text(n) for n in tree.body if isinstance(n,(ast.Import,ast.ImportFrom,ast.Assign,ast.AnnAssign)))
 # Anything not explicitly classified is a shared input: fail closed when a
 # new builder helper is introduced. The controller/evaluator themselves do
 # not generate image contents; stages.py is covered by its AST below.
 classified={str(p.relative_to(repo)) for p in expanded(repo,[path for paths in FILES.values() for path in paths]+['build/scripts','experimental/amd64/scripts'])}
 classified.update(str(p.relative_to(repo)) for p in expanded(repo,['desktop/tests']))
 classified.update(['build/stages.py','build/pipeline.py','build/fingerprints.py'])
 shared=[p for p in expanded(repo,SOURCE_DIRS) if str(p.relative_to(repo)) not in classified]
 shared+=expanded(repo,['bravion','.dockerignore'])
 results={}
 for stage,files in FILES.items():
  h=hashlib.sha256();h.update(target.encode());h.update((repo/'VERSION').read_bytes());h.update(common.encode())
  pending=[stage.replace('-','_')];seen=set()
  while pending:
   name=pending.pop()
   if name in seen:continue
   seen.add(name);node=functions[name];h.update(name.encode());h.update(ast_text(node).encode())
   pending+=sorted({n.id for n in ast.walk(node) if isinstance(n,ast.Name) and n.id in functions}-seen)
  h.update(ast_text(functions['main']).encode())
  paths=list(files)
  if stage=='lfs' and include_lfs_packages:paths.append('experimental/amd64/scripts' if target=='amd64' else 'build/scripts')
  for p in sorted(set(expanded(repo,paths)+shared)):
   if '__pycache__' in p.parts or 'target' in p.relative_to(repo).parts:continue
   if p.is_dir() and not p.is_symlink():continue
   h.update(str(p.relative_to(repo)).encode())
   if p.is_symlink():h.update(b'LINK'+str(p.readlink()).encode())
   elif p.is_file():
    h.update(str(stat.S_IMODE(p.stat().st_mode)).encode())
    if p.relative_to(repo).as_posix()=='desktop/manifest.json':
     # Fetch verifies the mandatory SHA256 before using these archives. URL
     # changes affect transport only; archive names, hashes and recipes remain
     # material inputs. This permits moving an unavailable verified mirror.
     manifest=json.loads(p.read_text())
     for package in manifest['packages']:package.pop('url',None)
     h.update(json.dumps(manifest,sort_keys=True,separators=(',',':')).encode())
    else:h.update(p.read_bytes())
   else:h.update(b'MISSING')
  results[stage]=h.hexdigest()
 return results

def lfs_inputs(repo,target):
 repo=Path(repo)
 directory=repo/('experimental/amd64/scripts' if target=='amd64' else 'build/scripts')
 packages=[]
 for item in json.loads((directory/'order.json').read_text()):
  if not item['page'].startswith(('chapter05/','chapter06/','chapter07/','chapter08/')):continue
  name=item['script']
  if not re.fullmatch(r'[A-Za-z0-9_+-]+\.sh',name):raise ValueError('Invalid LFS script name')
  path=directory/name
  h=hashlib.sha256(json.dumps(item,sort_keys=True).encode())
  h.update(str(stat.S_IMODE(path.stat().st_mode)).encode());h.update(path.read_bytes())
  packages.append({'script':name,'phase':'bootstrap' if item['page'].startswith(('chapter05/','chapter06/')) else 'chroot','fingerprint':h.hexdigest()})
 if len({p['script'] for p in packages})!=len(packages):raise ValueError('Duplicate LFS package script')
 return {'control':stage_fingerprints(repo,target,include_lfs_packages=False)['lfs'],'packages':packages}
