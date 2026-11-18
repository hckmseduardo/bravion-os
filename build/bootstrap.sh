#!/bin/bash
set -euo pipefail
umask 022
export LFS=/build/lfs
mkdir -p "$LFS"/{etc,var,tools} "$LFS"/usr/{bin,lib,sbin} /build/{logs,done}
for dir in bin lib sbin; do test -L "$LFS/$dir" || ln -s usr/$dir "$LFS/$dir"; done
# AArch64 uses /lib/ld-linux-aarch64.so.1. GCC is patched to use /usr/lib.
test -e /usr/bin/awk && ln -sf gawk /usr/bin/awk
ln -sf bash /bin/sh
id lfs >/dev/null 2>&1 || useradd -m -s /bin/bash lfs
chown -R lfs:lfs "$LFS"
chmod a+wt "$LFS/sources"
cp -a /workspace/build/scripts /build/scripts
chown -R lfs:lfs /build/scripts /build/logs /build/done
cat > /build/run-bootstrap.py <<'PY'
import hashlib,json,pathlib,subprocess,time,os
root=pathlib.Path('/build'); source=root/'lfs/sources'
checks={line.split()[1].lstrip('*'):line.split()[0] for line in (source/'md5sums').read_text().splitlines() if line.strip()}
for item in json.loads((root/'scripts/order.json').read_text()):
 if not item['page'].startswith(('chapter05/','chapter06/')): continue
 name=item['script']; marker=root/'done'/name
 if marker.exists(): continue
 archive=item['archive']; path=source/archive
 print('WAIT SOURCE',archive,flush=True)
 for attempt in range(180):
  if path.exists() and hashlib.md5(path.read_bytes()).hexdigest()==checks[archive]:break
  time.sleep(5)
 else:raise RuntimeError('Missing or corrupt source: '+archive)
 # All extra patches and bundled GCC libraries are checked before use as well.
 needed=[]
 text=(root/'scripts'/name).read_text()
 for filename in checks:
  if filename in text:needed.append(filename)
 for filename in needed:
  path=source/filename
  for attempt in range(180):
   if path.exists() and hashlib.md5(path.read_bytes()).hexdigest()==checks[filename]:break
   time.sleep(5)
  else:raise RuntimeError('Missing dependency source: '+filename)
 print('BUILD',name,flush=True)
 command=['su','-s','/bin/bash','lfs','-c', 'env -i HOME=/home/lfs TERM=xterm LFS=/build/lfs LFS_TGT=aarch64-lfs-linux-gnu PATH=/build/lfs/tools/bin:/usr/bin:/bin CONFIG_SITE=/build/lfs/usr/share/config.site MAKEFLAGS=-j2 bash /build/scripts/'+name]
 with (root/'logs'/name.replace('.sh','.log')).open('w') as log:
  result=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT)
 if result.returncode:raise SystemExit('FAILED '+name+'; see /build/logs')
 marker.touch()
 print('DONE',name,flush=True)
PY
python3 /build/run-bootstrap.py
