import hashlib
import json
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

from tool.prepare_release import prepare, read_version


class ReleasePreparationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        self.root = Path(self.temp.name)
        self.pubspec = self.root / 'pubspec.yaml'
        self.pubspec.write_text('name: example\nversion: 1.2.3+7\n')
        self.apk = self.root / 'app-debug.apk'
        self.apk.write_bytes(b'APK test fixture\x00\xff')
        self.output = self.root / 'nested' / 'release'

    def bundle(self, tag='v1.2.3'):
        return prepare(self.pubspec, self.apk, self.output, tag,
                       'a' * 40, 'owner/repo', '123')

    def test_command_line_prepares_bundle_and_requires_provenance(self):
        command = [sys.executable, '-m', 'tool.prepare_release',
                   '--pubspec', str(self.pubspec), '--apk', str(self.apk),
                   '--output', str(self.output), '--tag', 'v1.2.3',
                   '--sha', 'a' * 40, '--repository', 'owner/repo', '--run-id', '123']
        result = subprocess.run(command, capture_output=True, text=True, check=True)
        self.assertEqual(json.loads(result.stdout)['tag'], 'v1.2.3')
        for required in ['--sha', '--repository', '--run-id']:
            incomplete = command.copy()
            index = incomplete.index(required)
            del incomplete[index:index + 2]
            result = subprocess.run(incomplete, capture_output=True, text=True)
            self.assertEqual(result.returncode, 2)
            self.assertIn(required, result.stderr)

    def test_exact_apk_checksum_and_english_notes(self):
        metadata = self.bundle()
        apk = self.output / 'mqtt-lab-v1.2.3-debug.apk'
        self.assertEqual(apk.read_bytes(), self.apk.read_bytes())
        expected = hashlib.sha256(apk.read_bytes()).hexdigest()
        self.assertEqual(Path(str(apk) + '.sha256').read_text(),
                         f'{expected}  {apk.name}\n')
        notes = (self.output / 'notes.md').read_text()
        self.assertIn('debug-signed APK for testing', notes)
        self.assertIn('1.2.3 (build 7)', notes)
        self.assertIn('https://github.com/owner/repo/actions/runs/123', notes)
        self.assertIn('a' * 40, notes)
        self.assertFalse(metadata['prerelease'])

    def test_mismatched_or_unsafe_tag_produces_no_bundle(self):
        for tag in ['v2.0.0', 'v1.2.3/evil', 'v1.2.3; echo secret', '1.2.3']:
            with self.subTest(tag=tag), self.assertRaises(ValueError):
                self.bundle(tag)
        self.assertFalse(self.output.exists())

    def test_prerelease_is_preserved_and_classified(self):
        self.pubspec.write_text('version: 1.2.3-rc.1+8\n')
        metadata = self.bundle('v1.2.3-rc.1')
        self.assertTrue(metadata['prerelease'])
        self.assertEqual(metadata['tag'], 'v1.2.3-rc.1')
        self.assertTrue((self.output / 'mqtt-lab-v1.2.3-rc.1-debug.apk').is_file())

    def test_manual_preparation_uses_pubspec_without_a_tag(self):
        self.assertEqual(self.bundle('')['tag'], 'v1.2.3')

    def test_invalid_pubspec_versions_fail(self):
        for version in ['1.2.3', '1.2.3+0', '01.2.3+1', '1.2.3-01+1', 'foo', '1.2.3+2147483648']:
            self.pubspec.write_text('version: ' + version + '\n')
            with self.subTest(version=version), self.assertRaises(ValueError):
                read_version(self.pubspec)

    def test_version_boundary_and_valid_prerelease_identifiers(self):
        for version in ['1.2.3+2100000000', '1.2.3-rc.0+1', '1.2.3-rc.alpha+1']:
            self.pubspec.write_text('version: ' + version + '\n')
            self.assertEqual('+'.join(read_version(self.pubspec)), version)
        self.pubspec.write_text('name: missing_version\n')
        with self.assertRaises(ValueError):
            read_version(self.pubspec)

    def test_provenance_rejects_invalid_repository_and_run_id(self):
        for repository, run_id in [('bad/repo/path', '123'), ('owner/repo', 'not-a-run')]:
            with self.subTest(repository=repository, run_id=run_id), self.assertRaises(ValueError):
                prepare(self.pubspec, self.apk, self.output, 'v1.2.3',
                        'a' * 40, repository, run_id)
        self.assertFalse(self.output.exists())

    def test_empty_apk_and_invalid_provenance_do_not_create_outputs(self):
        self.apk.write_bytes(b'')
        with self.assertRaises(ValueError):
            self.bundle()
        self.apk.write_bytes(b'apk')
        with self.assertRaises(ValueError):
            prepare(self.pubspec, self.apk, self.output, 'v1.2.3',
                    'not-a-sha', 'owner/repo', '123')
        self.assertFalse(self.output.exists())


if __name__ == '__main__':
    unittest.main()
