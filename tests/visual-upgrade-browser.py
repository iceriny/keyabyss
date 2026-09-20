"""Compatibility entry for the current native visual suite."""
from pathlib import Path
import runpy
runpy.run_path(str(Path(__file__).with_name('native-renderer-browser.py')), run_name='__main__')
