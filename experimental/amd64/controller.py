from pathlib import Path
import datetime,json,subprocess
root=Path('/build/amd64-status'); root.mkdir(parents=True,exist_ok=True); work=Path('/workspace/experimental/amd64')
status=root/'status.json'
def record(phase,state,**extra):
 status.write_text(json.dumps(dict(architecture='x86_64',phase=phase,state=state,updated_utc=datetime.datetime.now(datetime.timezone.utc).isoformat(),**extra),indent=2)+'\n')
for phase,script in [('LFS temporary toolchain','bootstrap.sh'),('LFS base system','chroot-build.sh')]:
 record(phase,'running')
 print('START',phase,flush=True)
 result=subprocess.run(['bash',str(work/script)])
 if result.returncode:
  record(phase,'failed',exit_code=result.returncode)
  raise SystemExit(result.returncode)
 print('DONE',phase,flush=True)
record('LFS base system','complete',pending=['Generic x86_64 kernel and UEFI boot','BLFS desktop dependencies and COSMIC','Architecture-aware optional app downloads','Bravion identity and first-boot setup','Bootable image packaging and VM validation'])
