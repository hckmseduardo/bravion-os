import importlib.util, pathlib, tempfile, unittest
P=pathlib.Path(__file__).parents[1]/'build'/'pi_setup.py'
class SetupTests(unittest.TestCase):
    def load(self):
        self.assertTrue(P.exists(),'setup module must exist')
        s=importlib.util.spec_from_file_location('setup',P); m=importlib.util.module_from_spec(s); s.loader.exec_module(m); return m
    def test_scan_preserves_tabs_and_escaped_names(self):
        m=self.load()
        rows=m.parse_scan('bssid / frequency / signal level / flags / ssid\naa:bb\t2412\t-42\t[WPA2-PSK-CCMP][ESS]\tA\\x20B\ncc:dd\t2462\t-30\t[ESS]\tCafe\n')
        self.assertEqual(rows[0]['ssid'],b'Cafe'); self.assertEqual(rows[1]['ssid'],b'A B')
    def test_ssid_cannot_inject_configuration(self):
        m=self.load(); text=m.wifi_config('CA', b'evil"\nnetwork={', 'correct horse battery staple','WPA2')
        self.assertIn('ssid=6576696c220a6e6574776f726b3d7b',text)
        self.assertEqual(text.count('network={'),1)
        self.assertNotIn('correct horse',text)
    def test_decodes_wpa_control_character_escapes(self):
        m=self.load()
        self.assertEqual(m.unescape_ssid(r'Line\nTab\tQuote\"Slash\\'), b'Line\nTab\tQuote"Slash\\')
    def test_wpa3_password_special_characters_are_preserved(self):
        m=self.load()
        password='quote"slash'+chr(92)+'end'
        text=m.wifi_config('CA',b'Test',password,'WPA3')
        self.assertIn('sae_password='+password.encode().hex(), text)
    def test_rejects_invalid_country_and_password(self):
        m=self.load()
        for country,password in [('CAX','longpassword'),('CA','short')]:
            with self.assertRaises(ValueError): m.wifi_config(country,b'Test',password,'WPA2')
    def test_account_names_cannot_collide_with_existing_groups(self):
        import grp
        m=self.load()
        self.assertFalse(m.account_name_available(grp.getgrgid(0).gr_name))
    def test_credentials_are_private(self):
        m=self.load()
        with tempfile.TemporaryDirectory() as d:
            p=pathlib.Path(d)/'wifi.conf'; m.private_write(p,'secret')
            self.assertEqual(p.stat().st_mode & 0o777,0o600)
    def test_enterprise_is_not_treated_as_open(self):
        m=self.load(); self.assertEqual(m.security('[WPA2-EAP-CCMP][ESS]'),'unsupported')
if __name__=='__main__': unittest.main()
