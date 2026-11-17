"""Publish a prepared bundle through gh; completed public releases stay unchanged."""
import argparse
import json
import re
import subprocess
from pathlib import Path

from tool.prepare_release import SEMVER, checksum


def run_gh(*args):
    return subprocess.run(['gh', *args], capture_output=True, text=True)


def checked(*args):
    result = run_gh(*args)
    if result.returncode:
        raise RuntimeError(result.stderr.strip() or 'GitHub release operation failed.')
    return result.stdout


def current_release(tag):
    result = run_gh('release', 'view', tag, '--json', 'isDraft,assets')
    if result.returncode == 0:
        return json.loads(result.stdout)
    if 'release not found' in result.stderr.lower():
        return None
    raise RuntimeError(result.stderr.strip() or 'Could not inspect the release.')


def load_bundle(directory):
    metadata = json.loads((directory / 'metadata.json').read_text())
    tag = metadata['tag']
    if not re.fullmatch('v' + SEMVER, tag):
        raise ValueError('Invalid release tag.')
    apk = directory / ('mqtt-lab-' + tag + '-debug.apk')
    sha = Path(str(apk) + '.sha256')
    if sha.read_text() != checksum(apk) + '  ' + apk.name + '\n':
        raise ValueError('APK checksum mismatch; refusing to publish.')
    return tag, apk, sha


def require_assets(release, apk, sha):
    assets = {asset['name']: asset for asset in release['assets']}
    for file in (apk, sha):
        if file.name not in assets or assets[file.name]['size'] <= 0:
            raise RuntimeError('Release is missing a nonempty asset: ' + file.name)


def publish(directory):
    tag, apk, sha = load_bundle(directory)
    notes = str(directory / 'notes.md')
    release = current_release(tag)
    if release and not release['isDraft']:
        require_assets(release, apk, sha)
        print('Release already published; existing notes and assets are unchanged.')
        return
    if release is None:
        checked('release', 'create', tag, '--verify-tag', '--draft',
                '--title', tag + ' — MQTT Lab', '--notes-file', notes)
    checked('release', 'upload', tag, str(apk), str(sha), '--clobber')
    require_assets(current_release(tag), apk, sha)
    flags = ['--prerelease=false']
    if '-' in tag:
        flags = ['--prerelease', '--latest=false']
    checked('release', 'edit', tag, '--draft=false', '--notes-file', notes, *flags)
    print('Published ' + tag + ' with the debug APK and SHA-256 checksum.')


if __name__ == '__main__':
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('directory', type=Path)
    publish(parser.parse_args().directory)
