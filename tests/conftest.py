"""Make the repository's standalone engine modules importable from the test suite.

The engines live under `scripts/` rather than an installed package, so the suite adds that
directory to the import path once, here, instead of every test file repeating the dance.
"""

import sys
from pathlib import Path

SCRIPTS = Path(__file__).resolve().parent.parent / "scripts"
if str(SCRIPTS) not in sys.path:
    sys.path.insert(0, str(SCRIPTS))
