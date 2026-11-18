"""Remove temporary LFS compiler files after the final toolchain is installed."""
from pathlib import Path
import shutil
import subprocess
root=Path('/build/lfs')
target=subprocess.check_output(['chroot',str(root),'/usr/bin/gcc','-dumpmachine'],text=True).strip()
if target in {'aarch64-lfs-linux-gnu','x86_64-lfs-linux-gnu'}:raise SystemExit('Refusing cleanup: final compiler still uses temporary triplet')
for path in sorted((p for pattern in ['aarch64-lfs-linux-gnu*','x86_64-lfs-linux-gnu*'] for p in (root/'usr').rglob(pattern)),key=lambda p:len(p.parts),reverse=True):
    print('Remove temporary toolchain:',path.relative_to(root))
    if path.is_symlink() or path.is_file():path.unlink()
    elif path.is_dir():shutil.rmtree(path)
for directory in ('lib','libexec'):
    for path in (root/'usr'/directory).rglob('*.la'):
        if path.is_file() or path.is_symlink():path.unlink()
if subprocess.call(['chroot',str(root),'/usr/bin/id','tester'],stdout=subprocess.DEVNULL,stderr=subprocess.DEVNULL)==0:
    subprocess.run(['chroot',str(root),'/usr/sbin/userdel','-r','tester'],check=True)
print('Temporary compiler and test account removed; final compiler target:',target)
