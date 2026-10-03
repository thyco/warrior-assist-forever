#!/usr/bin/env python3
"""Build and verify an installable addon ZIP from the TOC and library files."""

from pathlib import Path
import re
import zipfile


ROOT = Path(__file__).resolve().parents[1]
ADDON = ROOT / "WarriorAssistForever"
MANIFEST = ADDON / "WarriorAssistForever.toc"


def main():
    manifest = MANIFEST.read_text()
    version = re.search(r"^## Version: ([0-9]+\.[0-9]+\.[0-9]+)$", manifest, re.MULTILINE)
    if not version:
        raise SystemExit("Manifest must contain a semantic version")

    files = {MANIFEST}
    for line in manifest.splitlines():
        entry = line.strip()
        if entry and not entry.startswith("#"):
            source = (ADDON / entry).resolve()
            if not source.is_relative_to(ADDON) or not source.is_file():
                raise SystemExit(f"Invalid or missing manifest entry: {entry}")
            files.add(source)

    # Include bundled library files and media textures alongside Lua.
    for directory in ("Libs", "Media"):
        for asset in sorted((ADDON / directory).rglob("*")):
            if asset.is_file():
                source = asset.resolve()
                if not source.is_relative_to(ADDON):
                    raise SystemExit(f"Bundled asset is outside the addon directory: {asset}")
                files.add(source)

    destination = ROOT / "dist" / f"WarriorAssistForever-{version[1]}.zip"
    destination.parent.mkdir(exist_ok=True)
    with zipfile.ZipFile(destination, "w", zipfile.ZIP_DEFLATED) as archive:
        for source in sorted(files):
            archive.write(source, source.relative_to(ROOT))

    with zipfile.ZipFile(destination) as archive:
        names = archive.namelist()
        if ("WarriorAssistForever/WarriorAssistForever.toc" not in names
                or len(names) != len(set(names))
                or len(names) != len(files)
                or archive.testzip() is not None):
            raise SystemExit("Archive verification failed")

    print(f"Built {destination} ({len(files)} files)")


if __name__ == "__main__":
    main()
