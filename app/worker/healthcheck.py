"""Exit 0 se il worker ha scritto l'heartbeat negli ultimi 30 secondi, altrimenti 1.
Pensato per HEALTHCHECK Docker o per una livenessProbe di tipo exec."""
import os
import sys
import time
import pathlib

f = pathlib.Path(os.environ.get("HEARTBEAT_FILE", "/tmp/heartbeat"))
max_age = int(os.environ.get("HEARTBEAT_MAX_AGE", "30"))
try:
    age = time.time() - float(f.read_text())
except (OSError, ValueError):
    sys.exit(1)
sys.exit(0 if age < max_age else 1)
