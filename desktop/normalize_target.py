"""Normalize implicit build permissions without touching virtual filesystems."""
import os
from pathlib import Path
import stat

def normalized_mode(mode):
    if mode & stat.S_IWOTH and not mode & stat.S_ISVTX:
        return mode & ~0o022
    return mode

def main():
    root=Path('/build/desktop-lfs')
    os.chown(root,0,0)
    for name in ('bin','lib','sbin'):
        os.chown(root/name,0,0,follow_symlinks=False)
    exclude={'dev','proc','sys','run','sources','tools','build-scripts','build-logs','build-done','tmp','desktop-scripts','desktop-logs','desktop-done'}
    changed=0
    for directory,dirs,files in os.walk(root,topdown=True,followlinks=False):
        path=Path(directory)
        if path==root:dirs[:]=[d for d in dirs if d not in exclude]
        dirs[:]=[d for d in dirs if not (path/d).is_symlink()]
        for item in [path]+[path/name for name in files]:
            if item.is_symlink():continue
            info=item.stat()
            if not (stat.S_ISDIR(info.st_mode) or stat.S_ISREG(info.st_mode)):continue
            mode=stat.S_IMODE(info.st_mode); new=normalized_mode(mode)
            if new!=mode:
                item.chmod(new);changed+=1
    for item in (root/'usr/share/doc/libxcb/tutorial',root/'usr/share/doc/libxcb/tutorial/index.html',root/'usr/share/doc/libxcb/tutorial/xcb.css'):
        if item.exists():os.chown(item,0,0)
    for name in ('passwd','group'):(root/'etc'/name).chmod(0o644)
    for name in ('shadow','gshadow'):(root/'etc'/name).chmod(0o600)
    print('Normalized',changed,'implicit world-writable paths; sticky temporary directories preserved.')

if __name__=='__main__':main()
