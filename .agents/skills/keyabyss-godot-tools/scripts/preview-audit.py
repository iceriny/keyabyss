"""Compare selected authored files with the generated MCP preview; never refresh it."""

import argparse
import hashlib
import json
import os
from pathlib import Path
import subprocess
import sys
from datetime import datetime, timezone
from uuid import uuid4


ROOT = Path(__file__).resolve().parents[4]
SKIP = {'.godot', '.git', '.temp', '.delete', '__pycache__'}


def digest(path):
    with path.open('rb') as stream:
        return hashlib.file_digest(stream, 'sha256').hexdigest()


def files_under(base, relative):
    path = base / relative
    if path.is_file():
        return {relative}
    result = set()
    if path.is_dir():
        for directory, children, files in os.walk(path):
            children[:] = [name for name in children if name not in SKIP]
            result.update((Path(directory) / name).relative_to(base).as_posix() for name in files)
    return result


def expected_project():
    # Match godot.ps1 preview's authored configuration transform, preserving CRLF.
    settings = (ROOT / 'project.godot').read_bytes().decode('utf-8-sig')
    settings = settings.replace('config/custom_user_dir_name="Keyabyss"',
                                'config/custom_user_dir_name="Keyabyss-M1-Preview"')
    entry = 'McpInteractionServer="*res://mcp_interaction_server.gd"'
    if '[autoload]' in settings:
        settings = settings.replace('[autoload]', '[autoload]\n' + entry)
    else:
        settings += '\n[autoload]\n' + entry + '\n'
    return hashlib.sha256(settings.encode('utf-8')).hexdigest()


def git(*args):
    return subprocess.run(['git', '-C', str(ROOT), *args], check=True,
                          capture_output=True, encoding='utf-8').stdout.rstrip('\r\n')


def main():
    parser = argparse.ArgumentParser(description=__doc__)
    group = parser.add_mutually_exclusive_group(required=True)
    group.add_argument('--paths', nargs='+', help='Copied paths relative to source root; files or directories.')
    group.add_argument('--all-runtime', action='store_true', help='Hash every path copied by the toolchain lock.')
    args = parser.parse_args()
    lock = json.loads((ROOT / 'tools/godot/toolchain.json').read_text(encoding='utf-8-sig'))
    copied = lock['runtimeDirectories'] + lock['runtimeFiles']
    selected = copied if args.all_runtime else args.paths
    paths = []
    for entry in selected:
        candidate = (ROOT / entry.removeprefix('res://').replace('\\', '/')).resolve()
        if not candidate.is_relative_to(ROOT):
            parser.error(f'Path is outside source root: {entry}')
        relative = candidate.relative_to(ROOT).as_posix()
        if not any(relative == item or relative.startswith(item + '/') for item in copied):
            parser.error(f'Path is not copied by preview: {entry}')
        if any(part in SKIP for part in Path(relative).parts):
            parser.error(f'Generated/cache path is not an authored comparison target: {entry}')
        paths.append(relative)
    preview = ROOT / '.temp/godot-mcp/project'
    if not (preview / 'project.godot').is_file():
        parser.error('No generated preview. Stop the old instance and use godot.ps1 preview first.')
    source_files, preview_files = set(), set()
    for relative in paths:
        source = files_under(ROOT, relative)
        generated = files_under(preview, relative)
        if not source and not generated and not args.all_runtime:
            parser.error(f'No files in either source or preview: {relative}')
        source_files.update(source)
        preview_files.update(generated)
    checks = []
    for relative in sorted(source_files | preview_files):
        source = ROOT / relative
        generated = preview / relative
        source_hash = digest(source) if relative in source_files else None
        preview_hash = digest(generated) if relative in preview_files else None
        expected_hash = expected_project() if relative == 'project.godot' else source_hash
        state = ('preview-only' if source_hash is None else
                 'missing-from-preview' if preview_hash is None else
                 'match' if expected_hash == preview_hash else 'changed')
        checks.append(dict(path=relative, state=state, sourceSha256=source_hash,
                           expectedPreviewSha256=expected_hash, previewSha256=preview_hash))
    differences = [item for item in checks if item['state'] != 'match']
    created = datetime.now(timezone.utc)
    evidence = ROOT / '.temp/skill-tools' / ('preview-' + created.strftime('%Y%m%d-%H%M%S') + '-' + uuid4().hex[:8])
    evidence.mkdir(parents=True)
    report = dict(createdUtc=created.isoformat(), projectRoot=str(ROOT), previewRoot=str(preview),
                  sourceHead=git('rev-parse', 'HEAD'),
                  sourceStatus=git('status', '--porcelain=v1', '--untracked-files=all').splitlines(),
                  toolchainSha256=digest(ROOT / 'tools/godot/toolchain.json'), paths=paths,
                  checks=checks, passed=not differences,
                  scope='Selected files on disk at audit time; not imported resources, runtime values or unsaved editor state.')
    (evidence / 'report.json').write_text(json.dumps(report, ensure_ascii=False, indent=2) + '\n', encoding='utf-8')
    for item in differences:
        print(f"{item['state']}: {item['path']}")
    print(f'Compared {len(checks)} files; {len(differences)} differences. Evidence: {evidence}')
    return 1 if differences else 0


if __name__ == '__main__':
    try:
        sys.exit(main())
    except (OSError, subprocess.CalledProcessError) as error:
        print(f'Preview audit failed: {error}', file=sys.stderr)
        sys.exit(2)
