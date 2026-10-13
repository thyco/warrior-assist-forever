"""Exercise archive contents and reject unsafe manifest paths in a disposable tree."""

from pathlib import Path
import re
import shutil
import subprocess
import tempfile
import zipfile


ROOT = Path(__file__).resolve().parents[1]
with tempfile.TemporaryDirectory() as temporary:
    root = Path(temporary)
    shutil.copytree(ROOT / "WarriorAssistForever", root / "WarriorAssistForever")
    (root / "scripts").mkdir()
    shutil.copy2(ROOT / "scripts/package.py", root / "scripts/package.py")
    manifest = root / "WarriorAssistForever/WarriorAssistForever.toc"
    original = manifest.read_text()
    version = re.search(r"^## Version: ([0-9]+\.[0-9]+\.[0-9]+)$", original, re.MULTILINE)
    assert version is not None
    archive_path = root / "dist" / f"WarriorAssistForever-{version[1]}.zip"

    def run():
        return subprocess.run(["python3", str(root / "scripts/package.py")], capture_output=True, text=True)

    # Repeated manifest entries must not create duplicate ZIP members.
    manifest.write_text(original + "\nCore.lua\n")
    result = run()
    assert result.returncode == 0, result.stderr
    with zipfile.ZipFile(archive_path) as archive:
        names = archive.namelist()
        assert "WarriorAssistForever/WarriorAssistForever.toc" in names
        assert len(names) == len(set(names))
        assert archive.testzip() is None
        assert "WarriorAssistForever/Libs/LibCustomGlow-1.0/LICENSE" in names
        assert "WarriorAssistForever/Libs/LibCustomGlow-1.0/DKForce-LICENSE" in names
        assert "WarriorAssistForever/Libs/README.md" in names
        assert "WarriorAssistForever/Media/Warrior.tga" in names
        corner_name = "WarriorAssistForever/Media/ShieldCorner.tga"
        assert corner_name in names
        corner = archive.read(corner_name)
        assert corner[2] == 2, "shield corner uses uncompressed true-color TGA"
        assert int.from_bytes(corner[12:14], "little") == 64
        assert int.from_bytes(corner[14:16], "little") == 64
        assert corner[16] == 32 and corner[17] == 0x28
        assert len(corner) == 18 + 64 * 64 * 4

        def alpha_at(x, y):
            return corner[18 + (y * 64 + x) * 4 + 3]

        assert alpha_at(0, 0) == 0 and alpha_at(8, 8) == 255, (
            "triangle has a rounded outer corner and an opaque interior"
        )
        assert alpha_at(63, 63) == 0, "triangle stays transparent outside its diagonal"

        for entry in ("Features/ReactiveAbilities.lua", "Services/Buttons.lua",
                      "Services/Stance.lua", "Services/ReactiveSpells.lua"):
            assert "WarriorAssistForever/" + entry in names
        assert all(name.startswith("WarriorAssistForever/") for name in names)
        for name in names:
            assert archive.read(name) == (root / name).read_bytes(), name

    outside = root / "outside.lua"
    outside.write_text("outside addon")
    (root / "WarriorAssistForever/escape.lua").symlink_to(outside)
    for entry in ("../outside.lua", str(outside), "escape.lua", "missing.lua"):
        manifest.write_text(original + "\n" + entry + "\n")
        result = run()
        assert result.returncode != 0, entry
        assert "Invalid or missing manifest entry" in result.stderr, result.stderr

print("package: unique install root, licenses, exact bytes, CRC, traversal/symlink/missing rejection passed")
