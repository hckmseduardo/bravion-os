import json, re
from pathlib import Path
from book import initial_build_command
root=Path('/workspace/build'); out=root/'scripts'; out.mkdir(exist_ok=True)
records=json.loads((root/'book/commands.json').read_text())
manifest=(Path('/workspace/research/wget-list').read_text()).splitlines()
files=[x.rsplit('/',1)[-1] for x in manifest if '.tar.' in x or x.endswith('.tgz')]
alias={'gcc-libstdc++':'gcc','linux-headers':'linux','libelf':'elfutils','xml-parser':'XML-Parser','Python':'Python','flit-core':'flit_core','sqlite':'sqlite-autoconf'}
skip_pages={'pkgmgt','grub','stripping','cleanup'}
# Commands intended for interactive use, optional compatibility builds, or tests.
skips={
 'chapter05/glibc':set(range(8,15)),
 'chapter07/createfiles':{5},
 'chapter08/glibc':{5,6,10,16,19},
 'chapter08/gmp':{0,4,5},
 'chapter08/libxcrypt':{5},
 'chapter08/ncurses':{6},
 'chapter08/gcc':{5,6,7,8,14,15,16,17,18,19,20},
 'chapter08/shadow':{9},
 'chapter08/coreutils':{3,4,5,6,7},
 'chapter08/bash':{3,5},
 'chapter08/texinfo':{5,6},
 'chapter08/systemd':{3,6},
 'chapter08/vim':{9},
 'chapter08/gawk':{3},
}
rows=[]
for record in records:
    page=record['page']; name=Path(page).stem; key=page[:-5]; chapter=page[7:9]
    if name in skip_pages or chapter=='07' and name in {'changingowner','kernfs','chroot'}: continue
    contents=[]
    for number,block in enumerate(record['commands']):
        if number in skips.get(key,set()) or not initial_build_command(block): continue
        if any(x in block for x in ['su tester','su -s /usr/bin/expect tester','TEST_JOBS=','HARNESS_JOBS=','bash tests/run.sh','vim -c',"grep '^FAIL:'"]): continue
        if key=='chapter08/glibc' and number==15: block='localedef -i C -f UTF-8 C.UTF-8\nlocaledef -i en_US -f UTF-8 en_US.UTF-8'
        block=block.replace('/usr/share/zoneinfo/<xxx>', '/usr/share/zoneinfo/Etc/UTC').replace('PAGE=<paper_size>', 'PAGE=A4')
        if name.startswith('gcc') and not name=='gcc-libstdc++' and number==0:
            contents.append("sed -i 's@lib64@lib@g' gcc/config/aarch64/t-aarch64-linux")
        # The LFS user account is not named root even when the container is.
        block=block.replace('--with-gcc-arch=native','--with-gcc-arch=armv8-a')
        block=block.replace('openssl-3.6.1','openssl-3.5.9')
        if key=='chapter08/Python' and number==0:
            block=block.replace('            --enable-optimizations '+chr(92)+chr(10),'')
        if block.strip()=='ninja': block='ninja -j2'
        if key=='chapter08/gcc' and number==10:
            block='chown -R root:root /usr/lib/gcc/$(gcc -dumpmachine)/15.2.0/include\nif test -d /usr/lib/gcc/$(gcc -dumpmachine)/15.2.0/include-fixed; then chown -R root:root /usr/lib/gcc/$(gcc -dumpmachine)/15.2.0/include-fixed; fi'
        contents.append(block)
    if name=='expect': contents.insert(0, 'tar -xOf ../gcc-15.2.0.tar.xz gcc-15.2.0/config.guess > tclconfig/config.guess\ntar -xOf ../gcc-15.2.0.tar.xz gcc-15.2.0/config.sub > tclconfig/config.sub\n')
    if key=='chapter08/systemd': contents.insert(-1,'echo \'NAME="Linux From Scratch"\' > /etc/os-release')
    package=alias.get(name, name.replace('-pass1','').replace('-pass2',''))
    archive=next((f for f in files if re.match(re.escape(package)+r'[-_\d]',f,re.I) and not 'man-pages' in f and not '-doc-' in f),None)
    if name=='openssl': archive='openssl-3.5.9.tar.gz'
    if name=='man-pages': archive=next(f for f in files if f.startswith('man-pages-'))
    if name=='creatingdirs' or name=='createfiles': archive=None
    if not archive and name not in {'creatingdirs','createfiles'}: raise ValueError((page,package))
    filename=page.replace('/','-').replace('.html','.sh')
    script='#!/bin/bash\nset -euo pipefail\numask 022\nset -x\n'
    if chapter in {'07','08'} and name!='gcc': script+='export MAKEFLAGS=-j4\n'
    if archive:
        script+='cd /sources\n' if chapter in {'07','08'} else 'cd "$LFS/sources"\n'
        script+=f"archive={archive!r}\nsource_dir=$(tar -tf \"$archive\" | sed -n '1s@/.*@@p')\n"
        # No pipeline early exit: pipefail must not turn tar's SIGPIPE into failure.
        script+='rm -rf "$source_dir"\ntar -xf "$archive"\ncd "$source_dir"\n'
    script+='\n\n'.join(contents)+'\n'
    if archive:
        script+='cd ..\n' if False else '\n'
        script+='cd /sources\n' if chapter in {'07','08'} else 'cd "$LFS/sources"\n'
        script+='rm -rf "$source_dir"\n'
    (out/filename).write_text(script)
    rows.append({'page':page,'script':filename,'archive':archive})
(out/'order.json').write_text(json.dumps(rows,indent=2))
print('Generated',len(rows),'build scripts')
