"""Offline installed runtime audit; excludes bound virtual filesystems and build trees."""
from pathlib import Path
import os, stat, subprocess
r=Path('/build/desktop-lfs')
binaries=('cosmic-comp','cosmic-session','cosmic-greeter','cosmic-greeter-daemon','cosmic-panel','cosmic-bg','cosmic-app-library','cosmic-files','cosmic-settings','cosmic-term','cosmic-store','xdg-desktop-portal-cosmic','greetd','flatpak','bwrap','rustc','cargo','nmcli','brave','start-cosmic')
commands={name:'/usr/bin/'+name for name in binaries}
commands['xdg-desktop-portal-cosmic']='/usr/libexec/xdg-desktop-portal-cosmic'
for name,target in commands.items():
 p=r/target.lstrip('/')
 assert p.is_file() and os.access(p,os.X_OK), str(p)
 with p.open('rb') as f:elf=f.read(4)==b'\x7fELF'
 if elf:
  result=subprocess.run(['chroot',str(r),'/usr/bin/ldd',target],capture_output=True,text=True)
  assert 'not found' not in result.stdout+result.stderr,(name,result.stdout,result.stderr)
for prefix in ('usr','etc','opt','var'):
 for directory,dirs,files in os.walk(r/prefix,followlinks=False):
  d=Path(directory)
  if d==r/'opt':dirs[:]=[n for n in dirs if n!='buildtools']
  dirs[:]=[n for n in dirs if not (d/n).is_symlink()]
  for p in [d]+[d/n for n in files]:
   if p.is_symlink():continue
   s=p.stat()
   assert not (s.st_mode & stat.S_IWOTH and not s.st_mode & stat.S_ISVTX),str(p)+' world writable'
   assert s.st_uid!=1000,str(p)+' UID1000'
assert not (r/'usr/bin/Xorg').exists()
assert not (r/'usr/bin/Xwayland').exists()
assert '--no-xwayland' in (r/'usr/bin/start-cosmic').read_text()
assert '--ozone-platform=wayland' in (r/'usr/bin/brave').read_text()
for name in ('su','passwd','sudo','fusermount3'):
 p=r/'usr/bin'/name
 assert p.stat().st_uid==0 and p.stat().st_mode & stat.S_ISUID,str(p)+' needs setuid root'
p=r/'usr/lib/polkit-1/polkit-agent-helper-1'
assert p.stat().st_uid==0 and p.stat().st_mode & stat.S_ISUID
for p in (r/'usr/share/backgrounds/cosmic').iterdir():
 if p.is_file():
  with p.open('rb') as f:assert not f.read(64).startswith(b'version https://git-lfs.github.com/spec/'),str(p)+' LFS placeholder'
print('PASS: native runtime links, permissions, setuid helpers, and Wayland-only launch configuration')
