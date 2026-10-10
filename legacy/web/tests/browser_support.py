"""Resolve a test browser without assuming a Linux installation path."""
import os
from pathlib import Path
from shutil import which


def launch_browser(playwright):
    explicit = os.environ.get('CHROMIUM')
    if explicit:
        executable = Path(explicit)
        if not executable.is_file():
            raise RuntimeError(f'CHROMIUM does not point to a file: {explicit}')
    else:
        candidates = [Path(playwright.chromium.executable_path)]
        for key in ('PROGRAMFILES', 'PROGRAMFILES(X86)', 'LOCALAPPDATA'):
            if os.environ.get(key):
                base = Path(os.environ[key])
                candidates += [base / 'Google/Chrome/Application/chrome.exe',
                               base / 'Microsoft/Edge/Application/msedge.exe']
        candidates += [Path(found) for name in ('chromium', 'chromium-browser', 'google-chrome')
                       if (found := which(name))]
        executable = next((p for p in candidates if p.is_file()), None)
        if executable is None:
            raise RuntimeError('No browser found. Run: python -m playwright install chromium; '
                               'or set CHROMIUM to your Chrome/Edge executable.')
    print(f'Test browser: {executable}', flush=True)
    return playwright.chromium.launch(executable_path=str(executable), headless=True)
