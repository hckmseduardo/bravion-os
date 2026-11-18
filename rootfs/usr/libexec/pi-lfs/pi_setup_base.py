#!/usr/bin/python3
"""Local first-boot account and Wi-Fi setup for Bravion OS."""
import getpass
import grp
import pwd
import hashlib
import os
from pathlib import Path
import re
import subprocess
import tempfile
import time


def run(*args, check=True):
    return subprocess.run(args, check=check, text=True, stdout=subprocess.PIPE,
                          stderr=subprocess.PIPE).stdout.strip()


def private_write(path, content):
    path = Path(path)
    path.parent.mkdir(parents=True, exist_ok=True)
    fd, temporary = tempfile.mkstemp(dir=path.parent, prefix='.setup-')
    try:
        os.fchmod(fd, 0o600)
        with os.fdopen(fd, 'w') as stream:
            stream.write(content)
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(temporary, path)
    finally:
        if os.path.exists(temporary):
            os.unlink(temporary)


def security(flags):
    if 'EAP' in flags or 'OWE' in flags:
        return 'unsupported'
    if 'SAE' in flags:
        return 'WPA3'
    if 'PSK' in flags:
        return 'WPA2'
    if 'WEP' in flags or 'WPA' in flags or 'RSN' in flags:
        return 'unsupported'
    return 'open'


def unescape_ssid(value):
    output = bytearray()
    i = 0
    while i < len(value):
        if value[i:i+2] == '\\x' and re.fullmatch('[0-9a-fA-F]{2}', value[i+2:i+4]):
            output.append(int(value[i+2:i+4], 16)); i += 4
        elif value[i:i+2] == '\\\\':
            output.append(92); i += 2
        elif value[i] == chr(92) and i + 1 < len(value) and value[i+1] in 'nrt"e':
            output.append({'n': 10, 'r': 13, 't': 9, '"': 34, 'e': 27}[value[i+1]])
            i += 2
        else:
            output.extend(value[i].encode('utf-8')); i += 1
    return bytes(output)


def parse_scan(output):
    found = {}
    for line in output.splitlines():
        parts = line.split('\t', 4)
        if len(parts) != 5:
            continue
        bssid, frequency, signal, flags, name = parts
        if not signal.lstrip('-').isdigit():
            continue
        ssid = unescape_ssid(name)
        if not ssid:
            continue
        entry = dict(ssid=ssid, signal=int(signal), security=security(flags), bssid=bssid)
        key = (ssid, entry['security'])
        if key not in found or entry['signal'] > found[key]['signal']:
            found[key] = entry
    return sorted(found.values(), key=lambda entry: entry['signal'], reverse=True)


def wifi_config(country, ssid, password, mode, hidden=False):
    country = country.upper()
    if not re.fullmatch('[A-Z]{2}', country):
        raise ValueError('Use a two-letter country code.')
    if not 1 <= len(ssid) <= 32:
        raise ValueError('The network name must contain 1 to 32 bytes.')
    lines = ['ctrl_interface=/run/wpa_supplicant', 'update_config=0',
             'country=' + country, '', 'network={', '    ssid=' + ssid.hex()]
    if hidden:
        lines.append('    scan_ssid=1')
    if mode == 'open':
        lines.append('    key_mgmt=NONE')
    elif mode == 'WPA2':
        raw = password.encode('utf-8')
        if not 8 <= len(raw) <= 63:
            raise ValueError('WPA2 passwords must contain 8 to 63 bytes.')
        psk = hashlib.pbkdf2_hmac('sha1', raw, ssid, 4096, 32).hex()
        lines += ['    key_mgmt=WPA-PSK WPA-PSK-SHA256', '    ieee80211w=1', '    psk=' + psk]
    elif mode == 'WPA3':
        if not 1 <= len(password.encode('utf-8')) <= 63 or any(ord(c) < 32 for c in password):
            raise ValueError('Use a WPA3 password of 1 to 63 bytes without control characters.')
        lines += ['    key_mgmt=SAE', '    ieee80211w=2', '    sae_password=' + password.encode('utf-8').hex()]
    else:
        raise ValueError('Enterprise, WEP and enhanced-open networks are not supported by this wizard.')
    return '\n'.join(lines + ['}', ''])


def wireless_interface():
    for path in sorted(Path('/sys/class/net').glob('*')):
        if (path / 'wireless').exists() or (path / 'phy80211').exists():
            return path.name
    raise RuntimeError('No wireless interface found. Check the Wi-Fi firmware and kernel logs.')


def wifi_setup():
    interface = wireless_interface()
    countries = Path('/usr/share/zoneinfo/iso3166.tab')
    allowed = set()
    if countries.exists():
        allowed = {line.split('\t')[0] for line in countries.read_text().splitlines() if line and not line.startswith('#')}
    while True:
        country = input('Wi-Fi country code (e.g. CA, US, GB): ').strip().upper()
        if re.fullmatch('[A-Z]{2}', country) and (not allowed or country in allowed):
            break
        print('Enter a valid two-letter country code.')
    run('rfkill', 'unblock', 'wifi', check=False)
    run('ip', 'link', 'set', interface, 'up')
    run('iw', 'reg', 'set', country)
    config_path = Path('/etc/wpa_supplicant/wpa_supplicant-' + interface + '.conf')
    if not config_path.exists():
        private_write(config_path, 'ctrl_interface=/run/wpa_supplicant\nupdate_config=0\ncountry=' + country + '\n')
    run('systemctl', 'enable', '--now', 'wpa_supplicant@' + interface + '.service')
    run('wpa_cli', '-i', interface, 'set', 'country', country, check=False)
    while True:
        print('\nScanning nearby networks...')
        run('wpa_cli', '-i', interface, 'scan', check=False)
        time.sleep(5)
        networks = parse_scan(run('wpa_cli', '-i', interface, 'scan_results'))
        for number, entry in enumerate(networks, 1):
            name = repr(entry['ssid'].decode('utf-8', errors='replace'))
            print(f"{number:2}. {name}  {entry['signal']} dBm  {entry['security']}")
        choice = input('Network number, [r]escan, [h]idden, or [s]kip: ').strip().lower()
        if choice == 's':
            return
        if choice == 'r':
            continue
        hidden = choice == 'h'
        if hidden:
            ssid = input('Hidden network name: ').encode('utf-8')
            mode = input('Security [WPA2/WPA3/open]: ').strip()
        elif choice.isdigit() and 1 <= int(choice) <= len(networks):
            entry = networks[int(choice)-1]; ssid = entry['ssid']; mode = entry['security']
        else:
            continue
        if mode == 'unsupported':
            print('This network requires configuration outside the wizard.'); continue
        password = '' if mode == 'open' else getpass.getpass('Wi-Fi password: ')
        try:
            configuration = wifi_config(country, ssid, password, mode, hidden)
        except ValueError as error:
            print(error); continue
        backup = config_path.read_text() if config_path.exists() else None
        private_write(config_path, configuration)
        run('systemctl', 'restart', 'wpa_supplicant@' + interface + '.service')
        associated = False
        for _ in range(30):
            status = run('wpa_cli', '-i', interface, 'status', check=False)
            if 'wpa_state=COMPLETED' in status:
                associated = True; break
            time.sleep(1)
        if not associated:
            print('Could not connect. Check the password and signal.')
            if backup is not None:
                private_write(config_path, backup)
                run('systemctl', 'restart', 'wpa_supplicant@' + interface + '.service', check=False)
            continue
        print('Wi-Fi associated. Waiting for an IP address...')
        run('networkctl', 'reconfigure', interface, check=False)
        address = ''
        for _ in range(30):
            address = run('ip', '-4', '-o', 'addr', 'show', 'dev', interface, 'scope', 'global')
            if address: break
            time.sleep(1)
        print(address or 'Connected to Wi-Fi, but DHCP has not assigned an IPv4 address.')
        try:
            print('DNS check:', run('getent', 'ahostsv4', 'www.linuxfromscratch.org').splitlines()[0])
        except (subprocess.CalledProcessError, IndexError):
            print('DNS lookup failed. Check router connectivity or a captive portal.')
        return


def account_name_available(name):
    if not re.fullmatch('[a-z][a-z0-9_-]{0,30}', name):
        return False
    for lookup in (pwd.getpwnam, grp.getgrnam):
        try:
            lookup(name)
            return False
        except KeyError:
            pass
    return True


def account_setup():
    while True:
        user = input('Administrator username [pi]: ').strip() or 'pi'
        if account_name_available(user):
            break
        print('Choose a new lowercase username, starting with a letter.')
    while True:
        password = getpass.getpass('New console password (at least 10 characters): ')
        if len(password) >= 10 and password == getpass.getpass('Repeat console password: '):
            break
        print('Passwords must match and contain at least 10 characters.')
    run('useradd', '-m', '-U', '-s', '/bin/bash', '-G', 'wheel', user)
    subprocess.run(['chpasswd'], input=user + ':' + password + '\n', text=True, check=True)
    key_file = Path('/boot/firmware/ssh-authorized-keys')
    keys = key_file.read_text().strip() if key_file.exists() else ''
    if not keys:
        print('Paste an SSH public key to enable remote login, or press Enter to add it later.')
        keys = input('SSH public key: ').strip()
    if keys:
        with tempfile.NamedTemporaryFile(mode='w', delete=False) as stream:
            stream.write(keys + '\n'); temporary = stream.name
        try:
            run('ssh-keygen', '-l', '-f', temporary)
            directory = Path('/home') / user / '.ssh'
            directory.mkdir(mode=0o700)
            private_write(directory / 'authorized_keys', keys + '\n')
            run('chown', '-R', user + ':' + user, str(directory))
            if key_file.exists(): key_file.unlink()
            print('SSH key installed. Remote login uses SSH keys only.')
        except subprocess.CalledProcessError:
            print('Invalid SSH public key; remote login remains unavailable. Add a valid key later.')
        finally:
            os.unlink(temporary)
    else:
        print('No SSH key installed. Use the local console to add one later.')
    private_write('/etc/pi-lfs-admin', user + '\n')


def main():
    if os.geteuid() != 0:
        raise SystemExit('Run sudo pi-setup to change network settings.')
    first = not Path('/var/lib/pi-lfs/setup-complete').exists()
    print('\nBravion OS — USB edition\n')
    if first and not Path('/etc/pi-lfs-admin').exists():
        account_setup()
    try:
        wifi_setup()
    except (RuntimeError, subprocess.CalledProcessError) as error:
        print('Wi-Fi setup could not finish:', str(error))
        print('Ethernet remains available. Run sudo pi-setup to retry.')
    if first:
        private_write('/var/lib/pi-lfs/setup-complete', 'complete\n')
        print('\nSetup complete. Log in with your new console account.\n')

if __name__ == '__main__':
    try:
        main()
    except (KeyboardInterrupt, EOFError):
        print('\nSetup interrupted. It will resume on next boot.'); raise SystemExit(1)
