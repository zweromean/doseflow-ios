#!/usr/bin/env python3
"""Reject IPA layouts iOS cannot install, before packaging."""
import plistlib
import sys
from pathlib import Path


def verify(app):
    def info(bundle):
        with (bundle / 'Info.plist').open('rb') as file:
            return plistlib.load(file)
    parent = info(app)['CFBundleIdentifier']
    seen = {parent}
    for extension in sorted((app / 'PlugIns').glob('*.appex')):
        extension_id = info(extension)['CFBundleIdentifier']
        if not extension_id.startswith(parent + '.'):
            raise ValueError(f'{extension_id} must start with {parent}.')
        if extension_id in seen:
            raise ValueError(f'Duplicate bundle identifier: {extension_id}')
        seen.add(extension_id)
        print(f'Validated extension: {extension_id}')
    print(f'Validated app: {parent}')


if __name__ == '__main__':
    verify(Path(sys.argv[1]))
