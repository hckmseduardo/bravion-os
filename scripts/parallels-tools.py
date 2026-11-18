#!/usr/bin/env python3
"""Stage Tools from the user's licensed ISO, without executing it on the builder."""
from pathlib import Path
import argparse,shutil,subprocess,os
p=argparse.ArgumentParser();p.add_argument('root',type=Path);p.add_argument('iso',type=Path);a=p.parse_args();root=a.root.resolve();repo=Path(__file__).resolve().parents[1]
assert root!=Path('/') and (root/'etc/lfs-release').is_file() and a.iso.is_file()
(root/'etc/pi-lfs-vm').touch()
def write(rel,text,mode=0o644):
 q=root/rel;q.parent.mkdir(parents=True,exist_ok=True,mode=0o755)
 if q.is_symlink():q.unlink()
 q.write_text(text);q.chmod(mode)
source=root/'opt/bravion/parallels-tools-installer';source.mkdir(parents=True,exist_ok=True)
subprocess.run(['bsdtar','-xf',str(a.iso),'-C',str(source)],check=True)
assert (source/'install').is_file() and (source/'tools/tools-arm64').is_dir()
hidden='[Desktop Entry]\nType=Application\nName=Parallels Control Center\nHidden=true\n'
write('etc/skel/.config/autostart/prlcc.desktop',hidden)
layout=(repo/'patches/cosmic/parallels-outputs.ron').read_text()
write('etc/skel/.local/state/cosmic-comp/outputs.ron',layout)
for row in (root/'etc/passwd').read_text().splitlines():
 f=row.split(':')
 if f[0]=='cosmic-greeter':
  home=root/f[5].lstrip('/');q=home/'.local/state/cosmic-comp/outputs.ron';q.parent.mkdir(parents=True,exist_ok=True,mode=0o755);q.write_text(layout)
  for item in [home/'.local',home/'.local/state',q.parent,q]:os.chown(item,int(f[2]),int(f[3]))
write('etc/modules-load.d/parallels-vsock.conf','vmw_vsock_virtio_transport\n')
write('usr/local/sbin/bravion-install-parallels-tools','''#!/bin/bash
set -u
mkdir -p /var/lib/bravion
: > /var/lib/bravion/parallels-tools-attempted
cd /opt/bravion/parallels-tools-installer || exit 1
/bin/bash ./install --install-unattended --verbose --restore-on-fail > /var/log/bravion-parallels-tools-install.log 2>&1
result=$?
printf '%s\\n' "$result" > /var/lib/bravion/parallels-tools-install-exit
if [ "$result" -eq 0 ]; then
 : > /var/lib/bravion/parallels-tools-installed
 rm -f /etc/xdg/autostart/prlcc.desktop
 printf '[Desktop Entry]\\nType=Application\\nName=Parallels Control Center\\nHidden=true\\n' > /etc/xdg/autostart/prlcc.desktop
fi
exit "$result"
''',0o755)
write('etc/systemd/system/bravion-parallels-tools-install.service','''[Unit]
Description=Install official Parallels Tools for Bravion VM
After=local-fs.target network.target
ConditionPathExists=/etc/pi-lfs-vm
ConditionPathExists=!/var/lib/bravion/parallels-tools-attempted
[Service]
Type=oneshot
ExecStart=/usr/local/sbin/bravion-install-parallels-tools
TimeoutStartSec=180
[Install]
WantedBy=multi-user.target
''')
subprocess.run(['systemctl','--root='+str(root),'enable','bravion-parallels-tools-install.service'],check=True)
