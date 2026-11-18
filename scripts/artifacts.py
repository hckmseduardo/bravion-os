#!/usr/bin/env python3
"""Compress, package, and independently validate generated images."""
from pathlib import Path
import argparse,hashlib,json,os,re,secrets,shutil,subprocess,uuid,xml.etree.ElementTree as ET,zipfile
REPO=Path(__file__).resolve().parents[1]
def version():
 v=os.environ.get('BRAVION_VERSION',(REPO/'VERSION').read_text().strip())
 if not re.fullmatch(r'[A-Za-z0-9][A-Za-z0-9._-]*',v):raise ValueError('Unsafe release version')
 return v
def image_name(target,v):
 suffix={'pi4-arm64':'raspberry-pi4-arm64','parallels-arm64':'parallels-arm64','amd64':'amd64'}[target]
 return f'bravion-os-{v}-{suffix}.img'
def digest(p):
 with p.open('rb') as f:return hashlib.file_digest(f,'sha256').hexdigest()
def sidecar(p):Path(str(p)+'.sha256').write_text(digest(p)+'  '+p.name+'\n')
def pvm(raw,out,v):
 hds=Path('/build/bravion-release.hds')
 subprocess.run(['qemu-img','convert','-f','raw','-O','parallels',str(raw),str(hds)],check=True)
 subprocess.run(['qemu-img','compare','-f','raw','-F','parallels',str(raw),str(hds)],check=True)
 config=ET.parse(REPO/'templates/parallels/config.pvs');root=config.getroot();identity='{'+str(uuid.uuid4())+'}'
 for node in root.iter():
  if node.tag in {'VmUuid','SourceVmUuid'}:node.text=identity
  elif node.tag=='VmName':node.text='Bravion OS '+v
  elif node.tag=='MAC':node.text='001C42'+secrets.token_hex(3).upper()
  elif node.tag=='UseAllDisplays':node.text='1'
 hdd=root.find('Hardware/Hdd');mib=raw.stat().st_size//1048576
 if hdd is not None:
  for tag,value in [('Size',mib),('SizeOnDisk',hds.stat().st_size//1048576)]:
   node=hdd.find(tag)
   if node is not None:node.text=str(value)
 desc=ET.parse(REPO/'templates/parallels/DiskDescriptor.xml');sectors=raw.stat().st_size//512
 for path,value in [('Disk_Parameters/Disk_size',sectors),('Disk_Parameters/Cylinders',sectors//512),('StorageData/Storage/End',sectors)]:desc.getroot().find(path).text=str(value)
 desc.getroot().find('Disk_Parameters/UID').text='{'+str(uuid.uuid4())+'}'
 name='Bravion OS '+v+'.pvm/';filename=desc.getroot().find('StorageData/Storage/Image/File').text
 part=out.with_name(out.name+'.part')
 with zipfile.ZipFile(part,'w',compression=zipfile.ZIP_DEFLATED,compresslevel=3,allowZip64=True) as z:
  z.writestr(name+'config.pvs',ET.tostring(root,encoding='utf-8',xml_declaration=True))
  z.writestr(name+'harddisk1.hdd/DiskDescriptor.xml',ET.tostring(desc.getroot(),encoding='utf-8',xml_declaration=True))
  z.write(hds,name+'harddisk1.hdd/'+filename)
  z.writestr(name+'README.txt',f'Bravion OS {v}, Apple Silicon ARM64 Parallels.\nOpen this .pvm and create your account at first boot. No default password.\nOfficial Tools were sourced from the builder operator\'s Parallels installation.\nCOSMIC uses the corrected extended-desktop mouse mapping; vendor graphical DynRes is disabled.\n')
 with zipfile.ZipFile(part) as z:
  if z.testzip() is not None:raise ValueError('PVM ZIP integrity failed')
 part.replace(out);sidecar(out)
def compress(target):
 v=version();raw=Path('/outputs')/image_name(target,v)
 if not raw.is_file() or raw.is_symlink():raise ValueError('Expected generated regular image')
 if target=='parallels-arm64':
  # Capacity remains available to first-boot root growth; ZIP stores content.
  capacity=max(16*1024**3,((raw.stat().st_size+1024**3-1)//1024**3)*1024**3)
  with raw.open('r+b') as f:f.truncate(capacity)
  sidecar(raw)
  pvm(raw,Path('/outputs')/f'Bravion-OS-{v}-Parallels-arm64.pvm.zip',v)
 else:
  out=Path(str(raw)+'.xz');part=Path(str(out)+'.part')
  with part.open('wb') as f:subprocess.run(['xz','-T2','-3','-c',str(raw)],stdout=f,check=True)
  subprocess.run(['xz','-t',str(part)],check=True);part.replace(out);sidecar(raw);sidecar(out)
def verify(target):
 v=version();raw=Path('/outputs')/image_name(target,v)
 out=Path('/outputs')/(f'Bravion-OS-{v}-Parallels-arm64.pvm.zip' if target=='parallels-arm64' else raw.name+'.xz')
 for p in [raw,out]:
  expected=Path(str(p)+'.sha256').read_text().split()[0]
  if digest(p)!=expected:raise ValueError('Artifact checksum changed: '+p.name)
 if target=='parallels-arm64':
  with zipfile.ZipFile(out) as z:
   if z.testzip() is not None:raise ValueError('ZIP integrity failed')
   text=z.read(next(n for n in z.namelist() if n.endswith('config.pvs'))).decode()
   assert '<UseAllDisplays>1</UseAllDisplays>' in text
 else:subprocess.run(['xz','-t',str(out)],check=True)
 subprocess.run(['python3',str(REPO/'scripts/boot-probe.py'),target,str(raw)],check=True)
 report={'version':v,'target':target,'artifact':out.name,'bytes':out.stat().st_size,'sha256':digest(out),'archive_integrity':True,'kernel_and_first_boot_service_smoke':True,'fresh_graphical_login_tested':False,'physical_hardware_tested':False}
 (out.parent/(target+'-validation.json')).write_text(json.dumps(report,indent=2)+'\n')
 print(json.dumps(report),flush=True)
if __name__=='__main__':
 p=argparse.ArgumentParser();p.add_argument('action',choices=['compress','verify']);p.add_argument('target',choices=['pi4-arm64','parallels-arm64','amd64']);a=p.parse_args()
 {'compress':compress,'verify':verify}[a.action](a.target)
