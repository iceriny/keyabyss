"""Measure moving native combat at 1080P; replaces the historical frozen Canvas probe."""
from pathlib import Path
import runpy, sys
sys.argv = [sys.argv[0], '--performance-only']
runpy.run_path(str(Path(__file__).with_name('native-renderer-browser.py')), run_name='__main__')
