#!/usr/bin/python3
"""Hold the Wi-Fi radio off until local setup has selected a country."""
import configparser
from pathlib import Path
import re
import os


def hold_wifi_until_country(root=Path('/')):
    country = root / 'etc/default/pi-wifi-country'
    if country.exists() and re.fullmatch(r'WIFI_COUNTRY=[A-Z]{2}\n?', country.read_text()):
        return False
    state = root / 'var/lib/NetworkManager/NetworkManager.state'
    config = configparser.ConfigParser()
    config.optionxform = str
    if state.exists():
        config.read(state)
    if not config.has_section('main'):
        config.add_section('main')
    if not config.has_option('main', 'NetworkingEnabled'):
        config.set('main', 'NetworkingEnabled', 'true')
    config.set('main', 'WirelessEnabled', 'false')
    state.parent.mkdir(parents=True, exist_ok=True)
    temporary = state.with_suffix('.state.tmp')
    with temporary.open('w') as stream:
        config.write(stream)
    temporary.chmod(0o600)
    os.replace(temporary, state)
    return True


if __name__ == '__main__':
    hold_wifi_until_country()
