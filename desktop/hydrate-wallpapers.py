"""Fetch Git LFS wallpaper objects from the pinned upstream commit and verify each oid."""
from pathlib import Path
import hashlib, os, re, subprocess, urllib.parse
os.umask(0o022)
r=Path('/build/desktop-lfs')
repo=r/'sources/cosmic-epoch/cosmic-wallpapers'
pin='da595bba495cb8fc57f26505621fc25000218349'
assert subprocess.check_output(['git','-C',str(repo),'rev-parse','HEAD'],text=True).strip()==pin
for p in sorted((repo/'original').iterdir()):
 if not p.is_file():continue
 with p.open('rb') as f:header=f.read(256)
 if not header.startswith(b'version https://git-lfs.github.com/spec/v1\n'):continue
 oid=re.search(rb'oid sha256:([0-9a-f]{64})',header)[1].decode()
 size=int(re.search(rb'size ([0-9]+)',header)[1])
 tmp=p.with_name(p.name+'.fetch')
 url='https://media.githubusercontent.com/media/pop-os/cosmic-wallpapers/'+pin+'/original/'+urllib.parse.quote(p.name)
 subprocess.run(['curl','-fL','--retry','3','-o',str(tmp),url],check=True)
 assert tmp.stat().st_size==size,p.name+' size mismatch'
 assert hashlib.sha256(tmp.read_bytes()).hexdigest()==oid,p.name+' SHA256 mismatch'
 tmp.chmod(0o644);tmp.replace(p)
 with (r/'desktop-logs/source-sha256.txt').open('a') as f:f.write(oid+'  cosmic-wallpapers/'+p.name+'\n')
 print('Verified wallpaper',p.name,size,flush=True)
subprocess.run(['chroot',str(r),'make','-C','/sources/cosmic-epoch/cosmic-wallpapers','prefix=/usr','install'],check=True)
