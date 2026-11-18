#!/usr/bin/python3
"""COSMIC edition console setup: existing account/key wizard with NetworkManager Wi-Fi.
Install existing work/build/pi_setup.py at /usr/libexec/pi-lfs/pi_setup_base.py.
Passwords are entered directly into nmcli's inherited terminal; never argv or logs.
"""
import os
from pathlib import Path
import re
import runpy
import subprocess


def run(*args, check=True):
    result = subprocess.run(args, check=check, text=True, stdout=subprocess.PIPE,
                            stderr=subprocess.PIPE, env={**os.environ, 'LC_ALL': 'C'})
    return result.stdout.strip()


def split_escaped(line):
    fields, part, escaped = [], [], False
    for char in line:
        if escaped:
            part.append(char)
            escaped = False
        elif char == '\\':
            escaped = True
        elif char == ':':
            fields.append(''.join(part))
            part = []
        else:
            part.append(char)
    if escaped:
        part.append('\\')
    return fields + [''.join(part)]


def parse_scan(output):
    found = {}
    for line in output.splitlines():
        fields = split_escaped(line)
        if len(fields) != 3:
            continue
        ssid, strength, flags = fields
        if not ssid or not strength.isdigit():
            continue
        if any(token in flags for token in ('802.1X', 'EAP', 'WEP', 'OWE')):
            security = 'unsupported'
        elif 'WPA3' in flags:
            security = 'WPA3'
        elif 'WPA' in flags:
            security = 'WPA2'
        elif flags in ('', '--'):
            security = 'open'
        else:
            security = 'unsupported'
        entry = dict(ssid=ssid, signal=int(strength), security=security)
        key = (ssid, security)
        if key not in found or entry['signal'] > found[key]['signal']:
            found[key] = entry
    return sorted(found.values(), key=lambda entry: entry['signal'], reverse=True)


def country_configuration(country):
    country = country.upper()
    if not re.fullmatch('[A-Z]{2}', country):
        raise ValueError('Use a valid two-letter country code.')
    return 'WIFI_COUNTRY=' + country + '\n'


def connect(interface, ssid, hidden=False):
    # NetworkManager chooses WPA2/WPA3 authentication from scanned capabilities.
    if not 1 <= len(ssid.encode('utf-8')) <= 32 or any(ord(c) < 32 or ord(c) == 127 for c in ssid):
        raise ValueError('Use a network name of 1 to 32 bytes without control characters.')
    args = ['nmcli', '--ask', '--wait', '60', 'device', 'wifi', 'connect', ssid,
            'ifname', interface]
    if hidden:
        args += ['hidden', 'yes']
    # Inherit stdin/stdout/stderr: --ask obtains the secret privately from the local TTY.
    subprocess.run(args, check=True)


def wifi_setup(base):
    interface = base['wireless_interface']()
    countries = Path('/usr/share/zoneinfo/iso3166.tab')
    allowed = set()
    if countries.exists():
        allowed = {line.split('\t')[0] for line in countries.read_text().splitlines()
                   if line and not line.startswith('#')}
    while True:
        country = input('Wi-Fi country code (e.g. CA, US, GB): ').strip().upper()
        try:
            configuration = country_configuration(country)
            if allowed and country not in allowed:
                raise ValueError('Use a valid two-letter country code.')
            break
        except ValueError as error:
            print(error)
    run('rfkill', 'unblock', 'wifi', check=False)
    run('iw', 'reg', 'reload')
    run('iw', 'reg', 'set', country)
    base['private_write']('/etc/default/pi-wifi-country', configuration)
    run('systemctl', 'enable', 'pi-wifi-country.service')
    run('nmcli', 'radio', 'wifi', 'on')
    while True:
        print('\nScanning nearby networks...')
        networks = parse_scan(run('nmcli', '--terse', '--escape', 'yes', '--fields',
                                  'SSID,SIGNAL,SECURITY', 'device', 'wifi', 'list',
                                  'ifname', interface, '--rescan', 'yes'))
        for number, entry in enumerate(networks, 1):
            print(f"{number:2}. {entry['ssid']!r}  {entry['signal']}%  {entry['security']}")
        choice = input('Network number, [r]escan, [h]idden, or [s]kip: ').strip().lower()
        if choice == 's':
            return
        if choice == 'r':
            continue
        hidden = choice == 'h'
        if hidden:
            ssid = input('Hidden network name: ')
            print('Only personal WPA2/WPA3 or open networks are supported here.')
        elif choice.isdigit() and 1 <= int(choice) <= len(networks):
            entry = networks[int(choice) - 1]
            if entry['security'] == 'unsupported':
                print('Configure this network later in COSMIC Settings.'); continue
            ssid = entry['ssid']
        else:
            continue
        try:
            print('NetworkManager will prompt for the Wi-Fi password if needed.')
            connect(interface, ssid, hidden)
        except ValueError as error:
            print(error); continue
        except subprocess.CalledProcessError:
            # Do not print subprocess command lines or secret-related error values.
            print('Could not connect. Check the password and signal, then retry.'); continue
        print(run('nmcli', '--fields', 'GENERAL.STATE,IP4.ADDRESS,IP4.GATEWAY',
                  'device', 'show', interface))
        return


def main():
    base = runpy.run_path('/usr/libexec/pi-lfs/pi_setup_base.py', run_name='pi_setup_base')
    # Reuse account creation, secure password handling, SSH key import and completion marker.
    # runpy's returned mapping may differ from function globals, so update the actual globals.
    base['main'].__globals__['wifi_setup'] = lambda: wifi_setup(base)
    base['main']()


if __name__ == '__main__':
    try:
        main()
    except (KeyboardInterrupt, EOFError):
        print('\nSetup interrupted. It will resume on next boot.')
        raise SystemExit(1)
