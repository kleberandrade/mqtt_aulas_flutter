import json
import os
import subprocess
import tempfile
import unittest
from pathlib import Path
from unittest.mock import patch

from tool.prepare_release import prepare
from tool.publish_release import current_release, publish


class PublicationTests(unittest.TestCase):
    def setUp(self):
        self.temp = tempfile.TemporaryDirectory()
        self.addCleanup(self.temp.cleanup)
        root = Path(self.temp.name)
        self.pubspec = root / 'pubspec.yaml'
        self.pubspec.write_text('version: 1.2.3+7\n')
        self.apk = root / 'app-debug.apk'
        self.apk.write_bytes(b'APK fixture')
        self.bundle = root / 'bundle'
        self.prepare('v1.2.3')
        self.calls = []
        self.release = None
        self.fail_upload = False
        self.patcher = patch('tool.publish_release.run_gh', side_effect=self.gh)
        self.patcher.start()
        self.addCleanup(self.patcher.stop)

    def prepare(self, tag):
        prepare(self.pubspec, self.apk, self.bundle, tag,
                'a' * 40, 'owner/repo', '123')

    def gh(self, *args):
        self.calls.append(args)
        operation = args[1]
        if operation == 'view':
            if self.release is None:
                return subprocess.CompletedProcess(args, 1, '', 'release not found')
            return subprocess.CompletedProcess(args, 0, json.dumps(self.release), '')
        if operation == 'create':
            self.release = {'isDraft': True, 'assets': []}
        if operation == 'upload':
            if self.fail_upload:
                return subprocess.CompletedProcess(args, 1, '', 'upload failed')
            self.release['assets'] = [
                {'name': Path(file).name, 'size': Path(file).stat().st_size}
                for file in args[3:5]]
        if operation == 'edit':
            self.release['isDraft'] = False
        return subprocess.CompletedProcess(args, 0, '', '')

    def test_publish_only_after_assets_are_uploaded_and_rerun_preserves_release(self):
        publish(self.bundle)
        self.assertFalse(self.release['isDraft'])
        self.assertEqual([call[1] for call in self.calls],
                         ['view', 'create', 'upload', 'view', 'edit'])
        self.assertIn('--verify-tag', self.calls[1])
        self.assertIn('--draft', self.calls[1])
        self.calls.clear()
        publish(self.bundle)
        self.assertEqual([call[1] for call in self.calls], ['view'])

    def test_upload_failure_leaves_draft_unpublished_and_retry_can_finish(self):
        self.fail_upload = True
        with self.assertRaisesRegex(RuntimeError, 'upload failed'):
            publish(self.bundle)
        self.assertTrue(self.release['isDraft'])
        self.assertNotIn('edit', [call[1] for call in self.calls])
        self.fail_upload = False
        self.calls.clear()
        publish(self.bundle)
        self.assertFalse(self.release['isDraft'])
        self.assertNotIn('create', [call[1] for call in self.calls])

    def test_published_release_with_missing_asset_fails_without_overwriting(self):
        self.release = {'isDraft': False, 'assets': []}
        with self.assertRaisesRegex(RuntimeError, 'missing'):
            publish(self.bundle)
        self.assertEqual([call[1] for call in self.calls], ['view'])

    def test_tampered_apk_is_rejected_before_contacting_github(self):
        (self.bundle / 'mqtt-lab-v1.2.3-debug.apk').write_bytes(b'changed')
        with self.assertRaisesRegex(ValueError, 'checksum mismatch'):
            publish(self.bundle)
        self.assertEqual(self.calls, [])

    def test_published_one_byte_assets_are_nonempty_and_preserved(self):
        self.release = {'isDraft': False, 'assets': [
            {'name': 'mqtt-lab-v1.2.3-debug.apk', 'size': 1},
            {'name': 'mqtt-lab-v1.2.3-debug.apk.sha256', 'size': 1}]}
        publish(self.bundle)
        self.assertEqual([call[1] for call in self.calls], ['view'])

    def test_cli_boundary_captures_not_found_as_text_without_creating_release(self):
        executable = Path(self.temp.name) / 'gh'
        executable.write_text('#!/bin/sh\nprintf "release not found" >&2\nexit 1\n')
        executable.chmod(0o755)
        self.patcher.stop()
        with patch.dict(os.environ, {'PATH': self.temp.name}):
            self.assertIsNone(current_release('v1.2.3'))

    def test_published_empty_asset_is_rejected(self):
        self.release = {'isDraft': False, 'assets': [
            {'name': 'mqtt-lab-v1.2.3-debug.apk', 'size': 0},
            {'name': 'mqtt-lab-v1.2.3-debug.apk.sha256', 'size': 92}]}
        with self.assertRaisesRegex(RuntimeError, 'nonempty'):
            publish(self.bundle)
        self.assertEqual([call[1] for call in self.calls], ['view'])

    def test_forged_bundle_tag_is_rejected_before_contacting_github(self):
        metadata = self.bundle / 'metadata.json'
        metadata.write_text('{"tag": "v1.2.3/unsafe"}')
        with self.assertRaisesRegex(ValueError, 'Invalid release tag'):
            publish(self.bundle)
        self.assertEqual(self.calls, [])

    def test_view_authorization_failure_does_not_attempt_creation(self):
        with patch('tool.publish_release.run_gh', return_value=
                   subprocess.CompletedProcess([], 1, '', 'permission denied')):
            with self.assertRaisesRegex(RuntimeError, 'permission denied'):
                publish(self.bundle)
        self.assertEqual(self.calls, [])

    def test_prerelease_does_not_become_latest_stable(self):
        self.pubspec.write_text('version: 1.2.3-rc.1+8\n')
        self.prepare('v1.2.3-rc.1')
        publish(self.bundle)
        self.assertIn('--prerelease', self.calls[-1])
        self.assertIn('--latest=false', self.calls[-1])


if __name__ == '__main__':
    unittest.main()
