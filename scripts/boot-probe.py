#!/usr/bin/env python3
"""Boot a disposable snapshot. No user account or credential is created."""
from pathlib import Path
import argparse,os,select,subprocess,time
p=argparse.ArgumentParser();p.add_argument('target');p.add_argument('image',type=Path);a=p.parse_args()
assert a.image.is_file() and not a.image.is_symlink()
log=a.image.parent/(a.target+'-boot.log')
common=['-m','1536','-smp','2','-display','none','-serial','stdio','-monitor','none','-no-reboot','-drive',f'file={a.image},if=virtio,format=raw,snapshot=on','-netdev','user,id=n0','-device','virtio-net-pci,netdev=n0']
if a.target=='amd64':
 firmware=next((p for p in [Path('/usr/share/OVMF/OVMF_CODE.fd'),Path('/usr/share/OVMF/OVMF_CODE_4M.fd')] if p.is_file()),None)
 if firmware is None:raise SystemExit('OVMF is required for the AMD64 EFI boot check')
 command=['qemu-system-x86_64','-machine','q35','-cpu','max','-bios',str(firmware),'-device','virtio-vga']+common
else:
 root=Path('/build/desktop-lfs/boot/firmware');kernel=root/('kernel8.img' if a.target=='pi4-arm64' else 'EFI/BOOT/BOOTAA64.EFI')
 command=['qemu-system-aarch64','-machine','virt','-cpu','cortex-a72','-kernel',str(kernel),'-append','root=PARTUUID=4c465350-02 rootfstype=ext4 rootwait rw console=ttyAMA0,115200 net.ifnames=0','-device','virtio-gpu-pci']+common
process=subprocess.Popen(command,stdout=subprocess.PIPE,stderr=subprocess.STDOUT)
buffer=b'';deadline=time.monotonic()+300;passed=False
try:
 with log.open('wb') as f:
  while time.monotonic()<deadline:
   ready,_,_=select.select([process.stdout],[],[],1)
   if ready:
    data=os.read(process.stdout.fileno(),65536)
    if not data and process.poll() is not None:break
    f.write(data);f.flush();buffer=(buffer+data)[-1000000:]
    if b'Kernel panic' in buffer:raise RuntimeError('Guest kernel panic; see '+str(log))
    # The setup wizard owns tty1. Seeing systemd start it verifies initial boot,
    # without injecting input, a default password, or a preconfigured account.
    if b'systemd' in buffer and (b'first-boot setup' in buffer or b'first boot account' in buffer):passed=True;break
   if process.poll() is not None:break
finally:
 process.terminate()
 try:process.wait(timeout=15)
 except subprocess.TimeoutExpired:process.kill();process.wait()
if not passed:raise SystemExit('Boot did not reach first-boot setup within 300 seconds: '+str(log))
print('PASS: kernel, systemd, and first-boot service reached on a disposable snapshot')
