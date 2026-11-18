import json,pathlib,subprocess,hashlib
root=pathlib.Path('/lfs-build/lfs')
checks={line.split()[1].lstrip('*'):line.split()[0] for line in (root/'sources/md5sums').read_text().splitlines() if line.strip()}
for item in json.loads((root/'build-scripts/order.json').read_text()):
 if not item['page'].startswith(('chapter07/','chapter08/')):continue
 name=item['script']; marker=root/'build-done'/name
 if marker.exists():continue
 if item['archive']:
  filename=item['archive']; path=root/'sources'/filename
  if filename in checks and hashlib.md5(path.read_bytes()).hexdigest()!=checks[filename]:raise RuntimeError('Checksum failed: '+filename)
 print('BUILD',name,flush=True)
 command=['/usr/sbin/chroot',str(root),'/usr/bin/env','-i','HOME=/root','TERM=xterm','PATH=/usr/bin:/usr/sbin','MAKEFLAGS=-j2','LC_ALL=C','/bin/bash','/build-scripts/'+name]
 with (root/'build-logs'/name.replace('.sh','.log')).open('w') as log:
  result=subprocess.run(command,stdout=log,stderr=subprocess.STDOUT)
 if result.returncode:raise SystemExit('FAILED '+name+'; see /lfs-build/lfs/lfs-build-logs')
 marker.touch(); print('DONE',name,flush=True)
