"""Remove only ELF debug sections; retain symbols and runtime/development files."""
from pathlib import Path
import subprocess
root=Path('/build/lfs/usr')
count=0
for directory in ('bin','sbin','lib','libexec'):
    for path in (root/directory).rglob('*'):
        if path.is_symlink() or not path.is_file() or '/modules/' in str(path) or '/firmware/' in str(path): continue
        with path.open('rb') as stream:header=stream.read(20)
        if len(header)<20 or header[:4]!=b'\x7fELF':continue
        endian='little' if header[5]==1 else 'big'
        if int.from_bytes(header[16:18],endian) not in (2,3):continue
        subprocess.run(['strip','--strip-debug',str(path)],check=True,stdout=subprocess.DEVNULL)
        count+=1
print('Removed debug sections from',count,'ELF executables and shared libraries.')
