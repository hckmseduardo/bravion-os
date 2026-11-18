#!/usr/bin/env python3
"""All build stages used by pipeline.py; no interactive package installation."""
from pathlib import Path, PurePosixPath
import argparse,hashlib,json,os,re,shutil,subprocess,tarfile,time,zipfile
REPO=Path('/workspace');BASE=Path('/build/lfs');ROOT=Path('/build/desktop-lfs');JOBS=os.environ.get('BRAVION_JOBS','1')
KERNEL_COMMIT='ab4372076bb840600e522ae776887ae2bc488fa6'
COSMIC_COMMIT='e98f8289a22f9e612feee7d4c6ba197782db154b'
FIRMWARE_COMMIT='6e26a246cf6194dd4b75c5d304013e66ebc0f2ae'
def run(*args,**kw):
 print('+',' '.join(map(str,args)),flush=True)
 return subprocess.run(list(map(str,args)),check=True,**kw)
def guest(root,*args,**kw):
 mounts(root)
 return run('chroot',root,'/usr/bin/env','HOME=/root','PATH=/usr/bin:/usr/sbin:/bin:/sbin','LC_ALL=C.UTF-8',f'MAKEFLAGS=-j{JOBS}','CFLAGS=-O2 -g0','CXXFLAGS=-O2 -g0','LDFLAGS=-Wl,--no-keep-memory',*args,**kw)
def checksum(path):
 with Path(path).open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def fetch(url,dest,expected):
 dest=Path(dest);dest.parent.mkdir(parents=True,exist_ok=True)
 if not re.fullmatch('[0-9a-f]{64}',expected):raise ValueError('Missing pinned SHA256: '+url)
 if dest.exists() and checksum(dest)==expected:return dest
 part=dest.with_name(dest.name+'.part')
 run('curl','--fail','--location','--retry','4','--connect-timeout','30','--max-time','1200','--output',part,url)
 if checksum(part)!=expected:raise ValueError('SHA256 mismatch: '+url)
 part.replace(dest);return dest
def extract(archive,dest):
 dest=Path(dest);dest.mkdir(parents=True,exist_ok=True)
 with tarfile.open(archive) as tar:
  for entry in tar.getmembers():
   name=PurePosixPath(entry.name)
   if name.is_absolute() or '..' in name.parts:raise ValueError('Unsafe archive path: '+entry.name)
 run('tar','--extract','--no-same-owner','--file',archive,'--directory',dest)
def copy_overlay(source,dest):
 for p in source.rglob('*'):
  rel=p.relative_to(source);q=dest/rel
  if p.is_dir():q.mkdir(parents=True,exist_ok=True)
  elif p.is_file():
   q.parent.mkdir(parents=True,exist_ok=True)
   if q.is_symlink():q.unlink()
   shutil.copy2(p,q)
def sources(target):
 run('bash',REPO/'build/fetch-sources.sh')
 run('sha256sum','-c',REPO/'research/lfs-sha256.txt',cwd=BASE/'sources')
 assert checksum('/build/pi/linux-ab437207.tar.gz')=='a9b89c16608aa9c7fedd49e68715e1225a8a333f6e36cd9c4fecb48726b41f72'
 assert checksum('/build/pi/wifi-firmware.tar.gz')=='a8fcbcd42240d3b127aa946514c3678332dbca94e350f1711cbf98a39ed07b36'
def lfs(target):
 scripts=REPO/('experimental/amd64/scripts' if target=='amd64' else 'build/scripts')
 # Normalize the experimental directory convention into the common builder API.
 dest=Path('/build/scripts');dest.mkdir(exist_ok=True)
 for p in scripts.iterdir():
  if p.is_file():
   text=p.read_text().replace('/lfs-build','/build')
   text=text.replace('make -j2',f'make -j{JOBS}').replace('MAKEFLAGS=-j2',f'MAKEFLAGS=-j{JOBS}')
   (dest/p.name).write_text(text)
 # Bootstrap uses the scripts just staged above, for the correct CPU architecture.
 text=(REPO/'build/bootstrap.sh').read_text().replace('cp -a /workspace/build/scripts /build/scripts','true # scripts staged by pipeline')
 text=text.replace('CONFIG_SITE=/build/lfs/usr/share/config.site', 'CFLAGS=\"-O2 -g0\" CXXFLAGS=\"-O2 -g0\" LDFLAGS=-Wl,--no-keep-memory CONFIG_SITE=/build/lfs/usr/share/config.site')
 text=text.replace('aarch64-lfs-linux-gnu','x86_64-lfs-linux-gnu' if target=='amd64' else 'aarch64-lfs-linux-gnu').replace('MAKEFLAGS=-j2',f'MAKEFLAGS=-j{JOBS}')
 Path('/build/bootstrap-current.sh').write_text(text)
 if target=='amd64':(BASE/'lib64').mkdir(exist_ok=True)
 if not Path('/build/done/chapter06-gcc-pass2.sh').exists():run('bash','/build/bootstrap-current.sh')
 # Mount virtual filesystems only inside the dedicated LFS root.
 for d in ['dev','proc','sys','run','build-scripts','build-logs','build-done']:(BASE/d).mkdir(parents=True,exist_ok=True)
 if not Path('/build/chroot-ownership-done').exists():
  run('chown','-h','root:root',BASE,BASE/'bin',BASE/'lib',BASE/'sbin')
  for d in ['usr','etc','var','tools']:run('chown','-R','root:root',BASE/d)
  Path('/build/chroot-ownership-done').touch()
 mounts(BASE)
 shutil.copytree(dest,BASE/'build-scripts',dirs_exist_ok=True)
 for item in json.loads((dest/'order.json').read_text()):
  if not item['page'].startswith(('chapter07/','chapter08/')):continue
  marker=BASE/'build-done'/item['script']
  if marker.exists():continue
  log=BASE/'build-logs'/item['script'].replace('.sh','.log')
  with log.open('w') as f:guest(BASE,'bash','/build-scripts/'+item['script'],stdout=f,stderr=subprocess.STDOUT)
  marker.touch()
def mounts(root):
 for d in ['dev','proc','sys','run']:(root/d).mkdir(parents=True,exist_ok=True)
 for name,args in [('dev',['--rbind','/dev']),('proc',['-t','proc','proc']),('sys',['-t','sysfs','sysfs']),('run',['-t','tmpfs','tmpfs'])]:
  if subprocess.call(['mountpoint','-q',str(root/name)])!=0:run('mount',*args,root/name)
 run('mount','--make-rslave',root/'dev')
 p=root/'etc/resolv.conf'
 if p.is_symlink():
  # Preserve the runtime resolver link; build-only data lives on private /run.
  if os.readlink(p)!='/run/systemd/resolve/stub-resolv.conf':raise ValueError('Unexpected resolver symlink')
  p=root/'run/systemd/resolve/stub-resolv.conf';p.parent.mkdir(parents=True,exist_ok=True)
 shutil.copyfile('/etc/resolv.conf',p)
def blfs(target):
 p=BASE/'build-scripts/blfs.sh';shutil.copy2(REPO/'build/blfs.sh',p)
 guest(BASE,'bash','/build-scripts/blfs.sh')
 Path('/build/blfs-complete').touch()
 run('bash',REPO/'build/configure-image.sh')
 run('python3',REPO/'build/cleanup-target.py')
def kernel(target):
 run('bash',REPO/'scripts/kernel.sh',target)
 if target=='amd64':
  source=Path('/build/cache/linux-firmware');source.parent.mkdir(parents=True,exist_ok=True)
  if not (source/'.git').exists():
   run('git','init',source);run('git','-C',source,'remote','add','origin','https://git.kernel.org/pub/scm/linux/kernel/git/firmware/linux-firmware.git')
  run('git','-C',source,'fetch','--depth=1','origin',FIRMWARE_COMMIT)
  run('git','-C',source,'checkout','--detach',FIRMWARE_COMMIT)
  assert subprocess.check_output(['git','-C',str(source),'rev-parse','HEAD'],text=True).strip()==FIRMWARE_COMMIT
  run('make','install','DESTDIR='+str(BASE),'FIRMWAREDIR=/usr/lib/firmware',cwd=source)
def desktop(target):
 run('bash',REPO/'desktop/prepare.sh')
 # Archives are immutable and share the same Linux filesystem: hardlinks avoid copies.
 for p in (BASE/'sources').iterdir():
  if p.is_file() and not (ROOT/'sources'/p.name).exists():os.link(p,ROOT/'sources'/p.name)
 if target=='parallels-arm64':(ROOT/'etc/pi-lfs-vm').touch()
def python_build_dependencies():
 for rec in json.loads((REPO/'build/python-build.json').read_text()):
  name=rec['url'].rsplit('/',1)[-1]
  p=fetch(rec['url'],ROOT/'sources'/name,rec['sha256'])
  guest(ROOT,'python3','-m','pip','install','--no-index','--no-build-isolation','--no-deps','--no-cache-dir','/sources/'+p.name)
 guest(ROOT,'python3','-c','import mako,jinja2,yaml,elftools,mesonpy,pyproject_metadata,setuptools_scm,docutils')
def runtimes(target):
 python_build_dependencies()
 meta=json.loads((REPO/'build/runtimes.json').read_text())[os.uname().machine]
 cache=ROOT/'sources'
 for rec in meta['rust']:
  name=rec['url'].rsplit('/',1)[-1];p=fetch(rec['url'],cache/name,rec['sha256']);extract(p,cache)
  guest(ROOT,'bash','/sources/'+name.removesuffix('.tar.xz')+'/install.sh','--prefix=/usr','--disable-ldconfig')
 for kind in ['node','just']:
  rec=meta[kind];p=fetch(rec['url'],cache/rec['url'].rsplit('/',1)[-1],rec['sha256'])
  dest=ROOT/'opt/node' if kind=='node' else cache/'just-bootstrap'
  dest.mkdir(parents=True,exist_ok=True)
  if kind=='node':run('tar','--extract','--no-same-owner','--strip-components=1','--file',p,'--directory',dest)
  else:
   extract(p,dest);shutil.copyfile(dest/'just',ROOT/'usr/bin/just');(ROOT/'usr/bin/just').chmod(0o755)
 for name in ['node','npm','npx']:
  p=ROOT/'usr/bin'/name
  if p.exists() or p.is_symlink():p.unlink()
  p.symlink_to('/opt/node/bin/'+name)
 # Debian libclang is an isolated bindgen build dependency, not a shipped runtime.
 for p in Path('/usr/lib/llvm-14').rglob('*'):
  if p.is_file() and ('include' in p.parts or p.name.startswith(('libclang','libLLVM'))):
   q=ROOT/'opt/buildtools'/p.relative_to('/');q.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,q)
 library=Path('/usr/lib/llvm-14/lib/libclang.so')
 deps=subprocess.check_output(['ldd',str(library)],text=True)
 for path in re.findall(r'=> (/[^ ]+)',deps):
  p=Path(path)
  if re.match(r'lib(c|m|dl|pthread|rt|stdc\+\+|gcc_s)\.so',p.name):continue
  q=ROOT/'opt/buildtools'/p.relative_to('/');q.parent.mkdir(parents=True,exist_ok=True);shutil.copyfile(p,q)
 guest(ROOT,'rustc','--version');guest(ROOT,'node','--version');guest(ROOT,'npm','--version')
def llvm():
 marker=ROOT/'desktop-done/llvm'
 if marker.exists():return
 url='https://github.com/llvm/llvm-project/releases/download/llvmorg-21.1.8/llvm-project-21.1.8.src.tar.xz'
 p=fetch(url,ROOT/'sources/llvm-project-21.1.8.src.tar.xz','4633a23617fa31a3ea51242586ea7fb1da7140e426bd62fc164261fe036aa142')
 extract(p,ROOT/'sources')
 source=ROOT/'sources/llvm-project-21.1.8.src'
 source.mkdir(exist_ok=True)
 guest(ROOT,'cmake','-S','/sources/llvm-project-21.1.8.src/llvm','-B','/sources/llvm-project-21.1.8.src/build','-G','Ninja','-DCMAKE_BUILD_TYPE=Release','-DCMAKE_INSTALL_PREFIX=/usr','-DLLVM_TARGETS_TO_BUILD=X86;AMDGPU','-DLLVM_BUILD_LLVM_DYLIB=ON','-DLLVM_LINK_LLVM_DYLIB=ON','-DLLVM_ENABLE_RTTI=ON','-DLLVM_INCLUDE_TESTS=OFF','-DLLVM_INCLUDE_BENCHMARKS=OFF','-DLLVM_INCLUDE_EXAMPLES=OFF','-DLLVM_PARALLEL_LINK_JOBS=1','-DCMAKE_EXE_LINKER_FLAGS=-Wl,--no-keep-memory')
 guest(ROOT,'cmake','--build','/sources/llvm-project-21.1.8.src/build','--parallel',JOBS)
 guest(ROOT,'cmake','--install','/sources/llvm-project-21.1.8.src/build');guest(ROOT,'ldconfig');marker.touch()
def desktop_package_order(target,packages):
 ordered=list(packages)
 if target=='amd64':
  pci=next(p for p in ordered if p['name']=='libpciaccess');ordered.remove(pci)
  ordered.insert(next(i for i,p in enumerate(ordered) if p['name']=='libdrm'),pci)
 return ordered
def desktop_recipe(target,script):
 if target=='amd64':
  for driver in ['intel','radeon','amdgpu','nouveau','vmwgfx']:
   script=script.replace('-D'+driver+'=disabled','-D'+driver+'=enabled')
  script=script.replace('-Dvc4=enabled','-Dvc4=disabled')
 return script
def desktop_packages(target):
 manifest=json.loads((REPO/'desktop/manifest.json').read_text())
 for rec in desktop_package_order(target,manifest['packages']):
  marker=ROOT/'desktop-done'/rec['name']
  if marker.exists():continue
  if target=='amd64' and rec['name']=='mesa':llvm()
  p=fetch(rec['url'],ROOT/'sources'/rec['archive'],rec['sha256'])
  folder=ROOT/'sources'/rec['folder']
  if rec['name']!='glib-introspection':
   if folder.exists():shutil.rmtree(folder)
   extract(p,ROOT/'sources')
  script=desktop_recipe(target,(REPO/'desktop'/rec['script']).read_text())
  script=script.replace('-j2',f'-j{JOBS}').replace('PARALLEL_LEVEL=2','PARALLEL_LEVEL='+JOBS).replace('--parallel=2','--parallel='+JOBS)
  if target=='amd64' and rec['name']=='mesa':
   script=script.replace('-Dgallium-drivers=vc4,v3d,virgl,softpipe','-Dgallium-drivers=iris,crocus,radeonsi,virgl,llvmpipe,softpipe').replace('-Dvulkan-drivers=broadcom','-Dvulkan-drivers=intel,intel_hasvk,amd,swrast').replace('-Dllvm=disabled','-Dllvm=enabled').replace('-Ddraw-use-llvm=false','-Ddraw-use-llvm=true')
  out=ROOT/'desktop-scripts'/(rec['name']+'.sh');out.write_text(script)
  with (ROOT/'desktop-logs'/(rec['name']+'.log')).open('w') as log:guest(ROOT,'bash','/desktop-scripts/'+out.name,stdout=log,stderr=subprocess.STDOUT)
  marker.touch()
 # Rebuild the PAM-aware login stack with its original, tested recipe.
 for filename in ['shadow-4.19.3.tar.xz','systemd-259.1.tar.gz']:
  assert (ROOT/'sources'/filename).is_file(),filename
 p=ROOT/'desktop-scripts/pam-stack-native.sh';shutil.copy2(REPO/'desktop/generated/pam-stack-native.sh',p)
 guest(ROOT,'bash','/desktop-scripts/pam-stack-native.sh')
 run('bash',REPO/'desktop/wpa-dbus.sh')
def finalize_lfs_identity():
 # The package chapters finish before the LFS book's final identity files.
 # Verify the base completion checkpoint before identifying this desktop root.
 if not (BASE/'build-done/chapter08-e2fsprogs.sh').is_file():raise ValueError('LFS base is not complete')
 marker=ROOT/'etc/lfs-release'
 if marker.exists() and marker.read_text().strip()!='13.0':raise ValueError('Unexpected LFS base release')
 marker.write_text('13.0\n')
def cosmic(target):
 finalize_lfs_identity()
 src=ROOT/'sources/cosmic-epoch'
 if not (src/'.git').exists():run('git','clone','--no-checkout','https://github.com/pop-os/cosmic-epoch.git',src)
 run('git','-C',src,'checkout','--detach',COSMIC_COMMIT)
 run('git','-C',src,'submodule','update','--init','--recursive')
 run('python3',REPO/'scripts/apply-cosmic-patches.py',src)
 script=ROOT/'desktop-scripts/cosmic-build.sh';shutil.copy2(REPO/'desktop/cosmic-build.sh',script)
 guest(ROOT,'bash','/desktop-scripts/cosmic-build.sh')
 run('python3',REPO/'desktop/hydrate-wallpapers.py')
def configuration(target):
 run('bash',REPO/'desktop/network-audio-configure.sh')
 p=ROOT/'desktop-scripts/cosmic-integration.sh';shutil.copy2(REPO/'desktop/cosmic-integration.sh',p);guest(ROOT,'bash','/desktop-scripts/cosmic-integration.sh')
 copy_overlay(REPO/'rootfs',ROOT)
 for unit in ['bravion-detect-vm.service','pi-firstboot.service','pi-grow-root.service','pi-wifi-country.service','cosmic-greeter.service']:
  run('systemctl','--root='+str(ROOT),'enable',unit)
 if target=='parallels-arm64':run('python3',REPO/'scripts/parallels-tools.py',ROOT,'/inputs/parallels-tools.iso')
 # Install signed Flatpak app/runtime payloads before packaging the image.
 p=ROOT/'desktop-scripts/flatpak-install.sh';shutil.copy2(REPO/'desktop/flatpak-install.sh',p)
 guest(ROOT,'bash','/desktop-scripts/flatpak-install.sh')
 shutil.copy2(REPO/'desktop/brave-launcher.sh',ROOT/'usr/bin/brave');(ROOT/'usr/bin/brave').chmod(0o755)
 guest(ROOT,'ldconfig')
def branding(target):
 src=ROOT/'sources/bravion-store';shutil.copytree(REPO/'ai-tools',src,dirs_exist_ok=True)
 guest(ROOT,'bash','-c','cd /sources/bravion-store && CARGO_PROFILE_RELEASE_LTO=false cargo test --locked && cargo build --locked --release -j1')
 run('python3',REPO/'branding/install-branding.py',ROOT,'--binary',src/'target/release/pi-ai-tools')
 run('python3',REPO/'branding/update-existing-users.py',ROOT)
 version=os.environ.get('BRAVION_VERSION',(REPO/'VERSION').read_text().strip())
 p=ROOT/'etc/os-release';p.write_text(p.read_text().replace('0.11.1',version))
 # Release identities and machine credentials must be generated on the destination.
 (ROOT/'etc/machine-id').write_text('')
 for pattern in ['etc/ssh/ssh_host_*','var/lib/systemd/random-seed']:
  for p in ROOT.glob(pattern):
   if p.is_file() or p.is_symlink():p.unlink()
 assert not (ROOT/'var/lib/pi-lfs/setup-complete').exists()
 assert not any((ROOT/'home').iterdir())
 for script in ['strip-debug.py','normalize_target.py']:run('python3',REPO/'desktop'/script)
def package(target):run('bash',REPO/'desktop/package-desktop.sh',env=dict(os.environ,BRAVION_TARGET=target,BRAVION_ROOT=str(ROOT)))
def compress(target):run('python3',REPO/'scripts/artifacts.py','compress',target)
def verify_artifacts(target):run('python3',REPO/'scripts/artifacts.py','verify',target)
def main():
 p=argparse.ArgumentParser();p.add_argument('stage');p.add_argument('target',choices=['pi4-arm64','parallels-arm64','amd64']);a=p.parse_args()
 expected='x86_64' if a.target=='amd64' else 'aarch64'
 if os.geteuid()!=0 or os.uname().machine!=expected or not Path('/storage').is_dir():raise SystemExit('Use ./bravion build in the isolated target builder.')
 functions={name.replace('_','-'):value for name,value in globals().items() if callable(value)}
 if a.stage not in functions:raise SystemExit('Unknown stage: '+a.stage)
 functions[a.stage](a.target)
if __name__=='__main__':main()
