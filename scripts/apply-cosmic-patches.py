#!/usr/bin/env python3
from pathlib import Path
import argparse,hashlib,shutil,subprocess
p=argparse.ArgumentParser();p.add_argument('epoch',type=Path);a=p.parse_args()
repo=Path(__file__).resolve().parents[1];source=repo/'patches/cosmic';comp=a.epoch/'cosmic-comp';module=comp/'src/input/mod.rs'
if 'mod absolute_pointer;' not in module.read_text():
 subprocess.run(['git','-C',str(comp),'apply','--check',str(source/'cosmic-comp-parallels-pointer.patch')],check=True)
 subprocess.run(['git','-C',str(comp),'apply',str(source/'cosmic-comp-parallels-pointer.patch')],check=True)
shutil.copyfile(source/'absolute_pointer.rs',comp/'src/input/absolute_pointer.rs')
assert 'map_absolute_pointer(' in module.read_text()
print('Applied scoped Parallels extended-pointer correction')
