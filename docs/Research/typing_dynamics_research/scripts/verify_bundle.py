"""Verify retained artifacts and arithmetic without changing scientific outputs.

Hashes refer to the delivered snapshot. Deliberate reruns can change runtime
metadata, so preserve the original archive for a clean integrity comparison.
"""
from pathlib import Path
import hashlib
import json
import sys

import numpy as np
import pandas as pd

ROOT = Path(__file__).resolve().parents[1]


def require(condition: bool, message: str) -> None:
    if not condition:
        raise RuntimeError(message)


def main() -> None:
    manifest_path = ROOT / 'MANIFEST.sha256.json'
    require(manifest_path.exists(), 'Missing delivery manifest')
    manifest = json.loads(manifest_path.read_text(encoding='utf-8'))
    for name, expected in manifest['files'].items():
        path = ROOT / name
        require(path.is_file(), f'Missing artifact: {name}')
        actual = hashlib.sha256(path.read_bytes()).hexdigest()
        require(actual == expected, f'Artifact changed: {name}')

    ledger = pd.read_csv(ROOT / 'results/analysis/execution_ledger.csv')
    checked = 0
    for row in ledger.itertuples():
        path = ROOT / row.output
        require(hashlib.sha256(path.read_bytes()).hexdigest() == row.output_sha256,
                f'Execution ledger hash mismatch: {row.name}')
        data = pd.read_csv(path)
        require(len(data) == row.executed_sessions, f'Row count mismatch: {row.name}')
        require(np.isfinite(data[['wpm5', 'actual_wpm', 'lpm', 'cpm']]).all().all(),
                f'Non-finite rate: {row.name}')
        require(np.allclose(data.cpm, 5 * data.wpm5, atol=1e-8),
                f'WPM/CPM identity failed: {row.name}')
        require(np.allclose(data.cpm, data.lpm + data.actual_wpm, atol=1e-8),
                f'Letter/space identity failed: {row.name}')
        require((data.duration_s > 0).all(), f'Nonpositive duration: {row.name}')
        require((data[['wpm5', 'actual_wpm', 'lpm', 'cpm']] >= 0).all().all(),
                f'Negative rate: {row.name}')
        checked += len(data)

    digest = json.loads((ROOT / 'results/analysis/digest.json').read_text(encoding='utf-8'))
    require(checked == digest['executed_sessions'], 'Execution total mismatch')
    figures = json.loads((ROOT / 'figures/manifest.json').read_text(encoding='utf-8'))
    require(len(figures) == 31, 'Expected 31 independent figures')
    for figure in figures:
        for ext in ('png', 'svg', 'pdf'):
            p = ROOT / 'figures' / f'{figure["stem"]}.{ext}'
            require(p.is_file() and p.stat().st_size > 1000, f'Invalid figure: {p.name}')
    require((ROOT / 'report/research_report.pdf').read_bytes().startswith(b'%PDF-'),
            'Report is not a PDF')
    print(json.dumps({'status': 'passed', 'hashed_files': len(manifest['files']),
                      'checked_sessions': checked, 'figures': len(figures)}, indent=2))


if __name__ == '__main__':
    try:
        main()
    except (OSError, ValueError, RuntimeError, KeyError) as exc:
        print(f'Verification failed: {exc}', file=sys.stderr)
        raise SystemExit(1)
