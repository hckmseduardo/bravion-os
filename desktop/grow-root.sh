#!/bin/bash
# Expand only this image's mounted ext4 root. Never reboot; retry on a later boot.
set -euo pipefail
export PATH=/usr/sbin:/usr/bin:/sbin:/bin
plan_layout() {
python3 -I - "$@" <<'PY'
import json, os, sys

def plan(table, disk, root, sectors):
    t = table['partitiontable']
    assert t['label'] == 'dos', 'expected DOS partition table'
    assert t['id'].lower() == '0x4c465350', 'unexpected disk ID'
    assert t['device'] == disk and t['unit'] == 'sectors', 'unexpected disk/unit'
    assert t.get('sectorsize', 512) == 512, 'expected 512-byte sectors'
    p = t['partitions']
    assert len(p) == 2, 'expected exactly boot and root partitions'
    boot, r = p
    suffix = 'p' if disk[-1].isdigit() else ''
    assert boot['node'] == disk + suffix + '1', 'unexpected boot device'
    assert r['node'] == root == disk + suffix + '2', 'unexpected root device'
    assert int(boot['start']) == 2048, 'unexpected boot start'
    assert int(boot['size']) in (196608, 524288), 'unexpected boot size'
    assert boot['type'].lower().lstrip('0') in ('c','ef'), 'expected FAT32 LBA or EFI boot'
    assert boot.get('bootable') is True, 'expected bootable first partition'
    assert r['type'].lower() == '83' and not r.get('bootable', False), 'unexpected root type'
    start, size = int(r['start']), int(r['size'])
    assert start == int(boot['start']) + int(boot['size']), 'unexpected root start/gap'
    assert size > 0 and start + size <= sectors, 'partition exceeds actual disk'
    # DOS LBA fields are 32-bit. Leave any incomplete final MiB unused.
    end = min(sectors, 2**32) // 2048 * 2048
    assert end >= start + size, 'aligned disk end would shrink the root'
    return start, size, end - start

if sys.argv[1:] == ['--self-test']:
    import copy
    base = {'partitiontable': {'label':'dos','id':'0x4c465350',
      'device':'/dev/mmcblk0','unit':'sectors','sectorsize':512,
      'partitions':[{'node':'/dev/mmcblk0p1','start':2048,'size':196608,'type':'c','bootable':True},
                    {'node':'/dev/mmcblk0p2','start':198656,'size':1001472,'type':'83'}]}}
    assert plan(base, '/dev/mmcblk0', '/dev/mmcblk0p2', 4000000) == (198656,1001472,3801088)
    assert plan(base, '/dev/mmcblk0', '/dev/mmcblk0p2', 1200128) == (198656,1001472,1001472)
    usb = json.loads(json.dumps(base).replace('/dev/mmcblk0p','/dev/sda').replace('/dev/mmcblk0','/dev/sda'))
    assert plan(usb, '/dev/sda', '/dev/sda2', 4000000)[2] == 3801088
    efi = copy.deepcopy(base); efi['partitiontable']['partitions'][0]['type']='ef'
    assert plan(efi, '/dev/mmcblk0', '/dev/mmcblk0p2', 4000000)[2] == 3801088
    cases = []
    for field, value in [('id','0x12345678'),('label','gpt'),('sectorsize',4096),('device','/dev/sdb')]:
        x=copy.deepcopy(base); x['partitiontable'][field]=value; cases.append(x)
    for field,value in [('start',198657),('type','8e'),('node','/dev/mmcblk0p3')]:
        x=copy.deepcopy(base);x['partitiontable']['partitions'][1][field]=value;cases.append(x)
    x=copy.deepcopy(base);x['partitiontable']['partitions'].append({});cases.append(x)
    for x in cases:
        try: plan(x,'/dev/mmcblk0','/dev/mmcblk0p2',4000000)
        except (AssertionError,KeyError,TypeError,ValueError): pass
        else: raise AssertionError('unsafe layout accepted')
    try:plan(base,'/dev/mmcblk0','/dev/mmcblk0p2',1000000)
    except AssertionError:pass
    else:raise AssertionError('shrinking disk accepted')
    print('PASS: growth, no-op, USB naming, and 9 unsafe-layout rejection checks')
else:
    try:
        print(*plan(json.loads(os.environ['PILFS_LAYOUT']), *sys.argv[1:3], int(sys.argv[3])))
    except (AssertionError, KeyError, TypeError, ValueError) as e:
        sys.exit('Refusing root expansion: ' + str(e))
PY
}
if [[ ${1:-} == --self-test ]]; then plan_layout --self-test; exit; fi
[[ $# == 0 ]] || { echo 'Usage: grow-root.sh [--self-test]' >&2; exit 2; }
[[ $EUID == 0 ]] || exit 1
exec 9>/run/pi-grow-root.lock
flock -n 9 || exit 0
state=/var/lib/pi-lfs
[[ ! -e "$state/grow-root.done" ]] || exit 0
trap 'echo "Pi LFS root expansion stopped at line $LINENO; boot may continue." >&2' ERR
[[ $(findmnt -nro FSTYPE /) == ext4 ]]
major_minor=$(findmnt -nro MAJ:MIN /)
rootdev=$(lsblk -nrpo NAME,MAJ:MIN | awk -v id="$major_minor" '$2 == id {print $1}')
[[ -b "$rootdev" && $(blkid -s PARTUUID -o value "$rootdev") == 4c465350-02 ]]
parent=$(lsblk -dnro PKNAME "$rootdev")
[[ -n "$parent" ]]
disk=/dev/$(basename "$parent")
[[ -b "$disk" && $(lsblk -dnro TYPE "$disk") == disk ]]
layout=$(sfdisk --json "$disk")
read_plan=$(PILFS_LAYOUT="$layout" plan_layout "$disk" "$rootdev" "$(blockdev --getsz "$disk")")
read -r start old_size new_size <<< "$read_plan"
mkdir -p "$state"
if (( new_size > old_size )); then
    sfdisk --dump "$disk" > "$state/grow-root-table.before"
    # -N changes only partition 2; start/type and disk ID are preserved explicitly.
    printf 'start=%s, size=%s, type=83\n' "$start" "$new_size" |
        sfdisk --no-reread --no-tell-kernel -N 2 "$disk"
    sync
    partx --update --nr 2 "$disk" || true
    udevadm settle || true
fi
if (( $(blockdev --getsz "$rootdev") < new_size )); then
    echo 'Root table expanded; kernel still has the old size. Filesystem expansion will retry next boot.'
    exit 0
fi
[[ $(blockdev --getsz "$rootdev") == "$new_size" ]]
resize2fs "$rootdev"
touch "$state/grow-root.done"
echo 'Pi LFS root filesystem now fills the available aligned root partition.'
