"""Seed the locked registry records required by Lito 0.8.1's bundle exporter.

Locked resolution skips the registry index, but `lito fetch --output` still
expects cached records. Keep only locked releases so new registry publications
and HTTP cache validators cannot change the fixed-output bundle.
"""

import hashlib
import json
from pathlib import Path
import subprocess
import sys
import tomllib


lock = tomllib.loads(Path(sys.argv[1]).read_text())
cache = Path(sys.argv[2]) / "registry" / "index"
for package in lock["packages"]:
    source = package.get("source", "")
    if not source.startswith("registry+"):
        continue
    registry = source.removeprefix("registry+")
    endpoint = f"{registry}v1/index/{package['name']}.json"
    index = json.loads(subprocess.check_output([
        "curl", "--fail", "--silent", "--show-error", "--location",
        "--retry", "5", "--retry-all-errors", endpoint,
    ]))
    releases = [
        release for release in index["releases"]
        if release["version"] == package["version"]
        and release["checksum"] == package["checksum"]
    ]
    if len(releases) != 1:
        raise ValueError(f"Missing or mismatched registry release: {package['name']}")
    index["releases"] = releases
    record = {
        "schema": "lito.registry.index-cache.v1",
        "registry": registry,
        "package": package["name"],
        "endpoint": endpoint,
        "etag": None,
        "body": json.dumps(index, sort_keys=True, separators=(",", ":")),
    }
    destination = cache / hashlib.sha256(registry.encode()).hexdigest()
    destination.mkdir(parents=True, exist_ok=True)
    (destination / f"{package['name']}.json").write_text(
        json.dumps(record, sort_keys=True, separators=(",", ":")) + "\n"
    )
