#!/usr/bin/env python3
"""Install Bravion identity into a mounted LFS image, never a host root."""
from pathlib import Path
import argparse, shutil, os, re
p=argparse.ArgumentParser()
p.add_argument('root',type=Path)
p.add_argument('--binary',required=True,type=Path)
a=p.parse_args(); root=a.root.resolve(); source=Path(__file__).resolve().parent
version=os.environ.get('BRAVION_VERSION',(source.parent/'VERSION').read_text().strip())
if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*',version):raise SystemExit('Invalid version')
if root == Path('/') or not (root/'etc/lfs-release').is_file():
    raise SystemExit('Expected a mounted LFS root, not the host filesystem')

def install(src,dest,mode=0o644):
    target=root/dest; target.parent.mkdir(parents=True,exist_ok=True)
    shutil.copyfile(src,target); target.chmod(mode)

def write(dest,content):
    target=root/dest; target.parent.mkdir(parents=True,exist_ok=True)
    target.write_text(content); target.chmod(0o644)

install(a.binary,'usr/bin/pi-ai-tools',0o755)
for name in ['LICENSE','THIRD_PARTY.md']:
    install(source.parent/name,f'usr/share/licenses/bravion/{name}')
install(source.parent/'research/LFS-MIT-license.html','usr/share/licenses/bravion/LFS-MIT-license.html')
for license_file in (source.parent/'licenses').glob('*.txt'):
    install(license_file,f'usr/share/licenses/bravion/{license_file.name}')
for name in ['bravion-os','bravion-store']:
    install(source/f'{name}.png',f'usr/share/pi-ai-tools/icons/{name}.png')
for icon in (source.parent/'ai-tools/assets').glob('*.png'):
    install(icon,f'usr/share/pi-ai-tools/icons/{icon.name}')
install(source/'bravion-wallpaper.png','usr/share/backgrounds/bravion/bravion-wallpaper.png')
for name,dest in [('pi-ai-tools.desktop','usr/share/applications'),('pi-ai-tools-autostart.desktop','etc/xdg/autostart')]:
    install(source.parent/'ai-tools'/name,f'{dest}/{name}')
write('usr/share/cosmic/com.system76.CosmicBackground/v1/all','''(
    output: "all",
    source: Path("/usr/share/backgrounds/bravion/bravion-wallpaper.png"),
    filter_by_theme: false,
    rotation_frequency: 3600,
    filter_method: Lanczos,
    scaling_mode: Fit((0.01, 0.02, 0.07)),
    sampling_method: Alphanumeric,
)
''')
write('etc/os-release',f'''NAME="Bravion OS"
PRETTY_NAME="Bravion OS {version} (COSMIC)"
ID=bravion
ID_LIKE=lfs
VERSION="{version}"
VERSION_ID="{version}"
''')
write('etc/issue',f'Bravion OS {version} — COSMIC Wayland / AI developer edition\n')
f=root/'usr/share/cosmic/com.system76.CosmicAppList/v1/favorites'
if f.exists() and '"pi-ai-tools"' not in f.read_text():
    f.write_text(f.read_text().replace('[','[\n    "pi-ai-tools",',1))
for rel in ['usr/sbin/pi-setup','usr/libexec/pi-lfs/pi_setup_base.py']:
    target=root/rel
    if target.is_file():
        target.write_text(target.read_text().replace('Pi LFS','Bravion OS'))
print(f'Installed Bravion OS {version} identity in {root}')
