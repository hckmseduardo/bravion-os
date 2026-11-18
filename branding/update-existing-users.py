from pathlib import Path
import argparse,hashlib,os,shutil
p=argparse.ArgumentParser();p.add_argument('root',type=Path);a=p.parse_args()
root=a.root.resolve()
if root==Path('/') or not (root/'etc/lfs-release').is_file():raise SystemExit('Expected a mounted LFS guest root')
shadow=root/'etc/shadow';before=hashlib.sha256(shadow.read_bytes()).digest()
snippet='''\n# Bravion: user-installed developer tools in interactive terminals.
case ":$PATH:" in
  *":$HOME/.local/bin:"*) ;;
  *) PATH="$HOME/.local/bin:$PATH" ;;
esac
export PATH
'''
def shell_path(path,uid=0,gid=0):
 if path.is_symlink():raise SystemExit(f'Refusing to overwrite shell symlink: {path}')
 text=path.read_text() if path.exists() else ''
 if '# Bravion: user-installed developer tools' not in text:
  if path.exists():shutil.copyfile(path,path.with_name(path.name+'.pre-bravion'))
  path.parent.mkdir(parents=True,exist_ok=True);path.write_text(text+snippet)
  path.chmod(0o644);os.chown(path,uid,gid)
shell_path(root/'etc/skel/.bashrc')
for line in (root/'etc/passwd').read_text().splitlines():
 f=line.split(':')
 if len(f)!=7 or not f[2].isdigit() or not 1000<=int(f[2])<65534 or not f[5].startswith('/home/'):continue
 home=root/f[5].lstrip('/');uid=int(f[2]);gid=int(f[3])
 if not home.is_dir():continue
 shell_path(home/'.bashrc',uid,gid)
 cfg=home/'.config/cosmic/com.system76.CosmicBackground/v1';cfg.mkdir(parents=True,exist_ok=True)
 target=cfg/'all'
 if target.exists() and not (cfg/'all.pre-bravion').exists():shutil.copyfile(target,cfg/'all.pre-bravion')
 shutil.copyfile(root/'usr/share/cosmic/com.system76.CosmicBackground/v1/all',target)
 (cfg/'same-on-all').write_text('true\n')
 for folder in [home/'.config',home/'.config/cosmic',cfg.parent,cfg]:os.chown(folder,uid,gid)
 for name in ['all','same-on-all','all.pre-bravion']:
  item=cfg/name
  if item.exists():os.chown(item,uid,gid)
 fav=home/'.config/cosmic/com.system76.CosmicAppList/v1/favorites'
 if fav.exists() and '"pi-ai-tools"' not in fav.read_text():
  shutil.copyfile(fav,fav.with_name('favorites.pre-bravion'))
  fav.write_text(fav.read_text().replace('[','[\n    "pi-ai-tools",',1));os.chown(fav,uid,gid)
 print(f'Updated Bravion wallpaper and interactive CLI path for {f[0]}')
assert before==hashlib.sha256(shadow.read_bytes()).digest(),'Account password data changed unexpectedly'
print('Account password data preserved')
