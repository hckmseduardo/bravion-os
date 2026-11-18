from pathlib import Path
import subprocess, tempfile, unittest

LAUNCHER = Path(__file__).resolve().parents[1] / 'brave-launcher.sh'

class BraveLauncherTests(unittest.TestCase):
    def arguments(self, vm):
        with tempfile.TemporaryDirectory() as directory:
            root = Path(directory)
            marker = root / 'pi-lfs-vm'
            if vm:
                marker.touch()
            binary = root / 'browser'
            binary.write_text('#!/bin/sh\nprintf "%s\\n" "$@"\n')
            binary.chmod(0o755)
            launcher = root / 'brave'
            launcher.write_text(LAUNCHER.read_text().replace('/etc/pi-lfs-vm', str(marker)).replace('/usr/bin/flatpak', str(binary)))
            result = subprocess.run(['sh', str(launcher), 'https://example.com/a b?x=1&y=2'], check=True, capture_output=True, text=True)
            return result.stdout.splitlines()

    def test_vm_fallback_preserves_wayland_and_url(self):
        self.assertEqual(self.arguments(True), ['run', '--system', 'com.brave.Browser', '--ozone-platform=wayland', '--disable-gpu', 'https://example.com/a b?x=1&y=2'])

    def test_physical_pi_retains_gpu_rendering(self):
        self.assertEqual(self.arguments(False), ['run', '--system', 'com.brave.Browser', '--ozone-platform=wayland', 'https://example.com/a b?x=1&y=2'])

if __name__ == '__main__':
    unittest.main()
