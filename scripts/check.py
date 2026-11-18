#!/usr/bin/env python3
"""Fast, unprivileged repository checks; never mounts or formats an image."""
from pathlib import Path
import ast,json,os,re,shutil,subprocess,sys,tempfile
ROOT=Path(__file__).resolve().parents[1]
def run(*args):subprocess.run(list(map(str,args)),cwd=ROOT,check=True)
def main():
 for base in ['build','desktop','scripts','tests','experimental','rootfs','branding','ai-tools','patches','templates']:
  for p in (ROOT/base).rglob('*'):
   if not p.is_file() or any(x in p.parts for x in ['target','__pycache__','.git']):continue
   if p.suffix=='.py':ast.parse(p.read_text(),filename=str(p))
   if p.suffix=='.sh' or p.read_bytes()[:20].startswith((b'#!/bin/bash',b'#!/bin/sh')):run('bash','-n',p)
   if p.suffix=='.json':json.loads(p.read_text())
   if p.suffix not in {'.png','.jpg','.gz','.xz'}:
    text=p.read_text(errors='ignore')
    if p.resolve()!=Path(__file__).resolve() and ('/Users/' in text or '/Volumes/' in text):raise ValueError('Maintainer-specific host path in '+str(p.relative_to(ROOT)))
    if re.search(r'gh[pousr]_[A-Za-z0-9]{30,}',text):raise ValueError('Possible token in '+str(p.relative_to(ROOT)))
 for pattern in ['etc/shadow','etc/passwd','etc/machine-id','etc/ssh/ssh_host_*']:
  if list((ROOT/'rootfs').glob(pattern)):raise ValueError('Private machine/account file in rootfs overlay')
 manifest=json.loads((ROOT/'desktop/manifest.json').read_text());names=set()
 for rec in manifest['packages']:
  assert rec['name'] not in names;names.add(rec['name'])
  assert rec['url'].startswith('https://')
  assert re.fullmatch('[0-9a-f]{64}',rec['sha256'])
  assert (ROOT/'desktop'/rec['script']).is_file()
  assert '/' not in rec['archive'] and '/' not in rec['folder'] and '..' not in rec['folder']
 for arch,meta in json.loads((ROOT/'build/runtimes.json').read_text()).items():
  assert arch in {'aarch64','x86_64'}
  for rec in meta['rust']+[meta[k] for k in ['node','just','brave']]:assert rec['url'].startswith('https://') and re.fullmatch('[0-9a-f]{64}',rec['sha256'])
 run(sys.executable,'-m','unittest','discover','-s','tests','-v')
 run(sys.executable,'-m','unittest','discover','-s','desktop/tests','-v')
 run('bash','desktop/grow-root.sh','--self-test')
 if shutil.which('rustc'):
  with tempfile.TemporaryDirectory() as d:
   for source in ['patches/cosmic/absolute_pointer.rs','ai-tools/src/architecture.rs']:
    binary=Path(d)/Path(source).stem;run('rustc','--test',ROOT/source,'-o',binary);run(binary)
 else:print('NOTE: rustc unavailable; standalone Rust tests not run.')
 if os.environ.get('BRAVION_CHECK_STORE')=='1':run('cargo','test','--locked','--manifest-path','ai-tools/Cargo.toml')
 print(f'PASS: source checks, pipeline/installer tests, and {len(names)} pinned desktop recipes')
if __name__=='__main__':main()
