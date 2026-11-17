"""Prepare versioned APK release assets; publishing is a separate workflow job."""
import argparse
import hashlib
import json
import re
import shutil
from pathlib import Path

SEMVER = r'(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)(?:-[0-9A-Za-z-]+(?:\.[0-9A-Za-z-]+)*)?'


def read_version(pubspec):
    match = re.search(r'^version:\s*[\'"]?([^\s\'"#]+)', pubspec.read_text(), re.MULTILINE)
    if not match:
        raise ValueError('pubspec.yaml must declare version: X.Y.Z+BUILD.')
    parsed = re.fullmatch(r'(' + SEMVER + r')\+([1-9][0-9]*)', match.group(1))
    if not parsed:
        raise ValueError('Use a semantic version and positive Android build number.')
    version, build = parsed.groups()
    validate_prerelease(version)
    if int(build) > 2100000000:
        raise ValueError('Android build number exceeds 2100000000.')
    return version, build


def validate_prerelease(version):
    if '-' not in version:
        return
    for part in version.split('-', 1)[1].split('.'):
        if part.isdigit() and len(part) > 1 and part.startswith('0'):
            raise ValueError('Numeric prerelease identifiers cannot have leading zeroes.')


def validate_provenance(sha, repository, run_id):
    if not re.fullmatch(r'[0-9a-f]{40}', sha):
        raise ValueError('A full source commit SHA is required.')
    if not re.fullmatch(r'[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+', repository):
        raise ValueError('Repository must be owner/name.')
    if not re.fullmatch(r'[0-9]+', run_id):
        raise ValueError('A GitHub Actions run ID is required.')


def checksum(path):
    digest = hashlib.sha256()
    with path.open('rb') as stream:
        for chunk in iter(lambda: stream.read(1024 * 1024), b''):
            digest.update(chunk)
    return digest.hexdigest()


def prepare(pubspec, apk, output, tag, sha, repository, run_id):
    version, build = read_version(pubspec)
    expected = 'v' + version
    if tag and tag != expected:
        raise ValueError('Release tag must match pubspec.yaml: ' + expected)
    validate_provenance(sha, repository, run_id)
    if apk.stat().st_size == 0:
        raise ValueError('The debug APK is empty.')
    return write_bundle(apk, output, expected, version, build, sha, repository, run_id)


def write_bundle(apk, output, tag, version, build, sha, repository, run_id):
    output.mkdir(parents=True, exist_ok=True)
    name = 'mqtt-lab-' + tag + '-debug.apk'
    target = output / name
    shutil.copyfile(apk, target)
    (output / (name + '.sha256')).write_text(checksum(target) + '  ' + name + '\n')
    template = Path(__file__).resolve().parents[1] / 'docs' / 'RELEASE_NOTES.md'
    notes = template.read_text().format(tag=tag, version=version, build=build,
                                       sha=sha, repository=repository, run_id=run_id, apk=name)
    (output / 'notes.md').write_text(notes)
    metadata = {'tag': tag, 'prerelease': '-' in version, 'apk': name}
    (output / 'metadata.json').write_text(json.dumps(metadata, indent=2) + '\n')
    return metadata


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument('--pubspec', type=Path, default=Path('pubspec.yaml'))
    parser.add_argument('--apk', type=Path, default=Path('build/app/outputs/flutter-apk/app-debug.apk'))
    parser.add_argument('--output', type=Path, default=Path('.dart_tool/release'))
    parser.add_argument('--tag', default='')
    parser.add_argument('--sha', required=True)
    parser.add_argument('--repository', required=True)
    parser.add_argument('--run-id', required=True)
    args = parser.parse_args()
    metadata = prepare(args.pubspec, args.apk, args.output, args.tag,
                       args.sha, args.repository, args.run_id)
    print(json.dumps(metadata))


if __name__ == '__main__':
    main()
