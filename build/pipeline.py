#!/usr/bin/env python3
"""Checkpointed source-to-image build, executed inside the isolated builder."""
from pathlib import Path
import argparse, datetime, hashlib, json, os, subprocess, stat
TARGETS={'pi4-arm64':'aarch64','parallels-arm64':'aarch64','amd64':'x86_64'}
STEPS=('sources','lfs','blfs','kernel','desktop','runtimes','desktop-packages','cosmic','configuration','branding','package','compress','verify-artifacts')
def plan(target):
 if target not in TARGETS:raise ValueError('Unknown image target: '+target)
 return [(name,['python3','/workspace/build/stages.py',name,target]) for name in STEPS]
def atomic_json(path,value):
 tmp=path.with_suffix('.tmp');tmp.write_text(json.dumps(value,indent=2)+'\n');tmp.replace(path)
 if path.name=='status.json' and os.environ.get('BRAVION_STATUS'):
  mirror=Path(os.environ['BRAVION_STATUS']);mirror.write_text(path.read_text())
class Runner:
 def __init__(self,state,target,source,fingerprints=None):
  if target not in TARGETS:raise ValueError('Unknown image target')
  self.state=Path(state);self.state.mkdir(parents=True,exist_ok=True)
  self.identity={'target':target,'source':source};identity=self.state/'identity.json'
  inputs=self.state/'inputs.json'
  if identity.exists():
   previous=json.loads(identity.read_text())
   changed_identity=previous!=self.identity
   if previous.get('target')!=target or (changed_identity and (fingerprints is None or not inputs.exists())):
    raise ValueError('Build state belongs to a different target/source revision. Use a new storage directory; do not mix root filesystems.')
   old=json.loads(inputs.read_text()) if inputs.exists() else fingerprints
   changed=sorted(k for k in set(old or {})|set(fingerprints or {}) if (old or {}).get(k)!=(fingerprints or {}).get(k))
   if any((self.state/(k+'.done')).exists() or (self.state/(k+'.log')).exists() for k in changed):
    raise ValueError('Source change affects a stage already started. Use a new storage directory.')
   if changed_identity or changed:
    with (self.state/'source-updates.jsonl').open('a') as log:
     log.write(json.dumps({'from':previous['source'],'to':source,'changed_unstarted_stages':changed})+'\n')
  atomic_json(identity,self.identity)
  if fingerprints is not None:atomic_json(inputs,fingerprints)
 def completed(self,name):return (self.state/(name+'.done')).exists()
 def run(self,name,command):
  if self.completed(name):print('RESUME',name,flush=True);return
  now=lambda:datetime.datetime.now(datetime.timezone.utc).isoformat()
  status=self.state/'status.json';atomic_json(status,dict(self.identity,stage=name,state='running',updated_utc=now()))
  print('BUILD',name,flush=True)
  with (self.state/(name+'.log')).open('a') as log:
   result=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT)
  if result.returncode:
   atomic_json(status,dict(self.identity,stage=name,state='failed',exit_code=result.returncode,updated_utc=now()))
   print((self.state/(name+'.log')).read_text(errors='replace')[-6000:],flush=True)
   raise subprocess.CalledProcessError(result.returncode,command)
  (self.state/(name+'.done')).touch()
  atomic_json(status,dict(self.identity,stage=name,state='complete',updated_utc=now()))
  print('DONE',name,flush=True)
def source_digest(repo):
 h=hashlib.sha256();h.update((repo/'VERSION').read_bytes())
 for name in ['bravion','.dockerignore','LICENSE','THIRD_PARTY.md']:
  p=repo/name;h.update(name.encode());h.update(str(stat.S_IMODE(p.stat().st_mode)).encode());h.update(p.read_bytes())
 for directory in ['build','desktop','kernel','patches','rootfs','ai-tools','branding','scripts','research','templates','licenses','experimental/amd64']:
  for p in sorted((repo/directory).rglob('*')):
   if (p.is_file() or p.is_symlink()) and '__pycache__' not in p.parts and 'target' not in p.parts:
    h.update(str(p.relative_to(repo)).encode());h.update(str(stat.S_IMODE(p.lstat().st_mode)).encode())
    h.update(('LINK:'+str(p.readlink())).encode() if p.is_symlink() else p.read_bytes())
 return h.hexdigest()
def main():
 p=argparse.ArgumentParser();p.add_argument('target',choices=TARGETS);p.add_argument('--plan',action='store_true');a=p.parse_args()
 if a.plan:
  print('\n'.join(name for name,_ in plan(a.target)));return
 if os.geteuid()!=0 or os.uname().machine!=TARGETS[a.target]:raise SystemExit('Use ./bravion build: the builder must match the target architecture.')
 repo=Path('/workspace')
 from fingerprints import stage_fingerprints
 r=Runner('/build/pipeline-state',a.target,source_digest(repo),fingerprints=stage_fingerprints(repo,a.target))
 for name,command in plan(a.target):r.run(name,command)
 print('IMAGE_COMPLETE',a.target,flush=True)
if __name__=='__main__':main()
