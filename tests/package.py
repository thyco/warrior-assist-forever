"""Exercise archive contents and reject unsafe manifest paths in a disposable tree."""

from pathlib import Path
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

    def run():
        return subprocess.run(["python3", str(root / "scripts/package.py")], capture_output=True, text=True)

    # Repeated manifest entries must not create duplicate ZIP members.
    manifest.write_text(original + "\nCore.lua\n")
    result = run()
    assert result.returncode == 0, result.stderr
    with zipfile.ZipFile(root / "dist/WarriorAssistForever-0.3.0.zip") as archive:
        names = archive.namelist()
        assert "WarriorAssistForever/WarriorAssistForever.toc" in names
        assert len(names) == len(set(names))
        assert archive.testzip() is None
        assert "WarriorAssistForever/Libs/LibCustomGlow-1.0/LICENSE" in names
        assert "WarriorAssistForever/Libs/LibCustomGlow-1.0/DKForce-LICENSE" in names
        assert "WarriorAssistForever/Libs/README.md" in names
        assert "WarriorAssistForever/Media/Warrior.tga" in names
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
