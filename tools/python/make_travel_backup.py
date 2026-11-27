"""Package all Git-tracked source plus evidence for the three travel builds.

Run from any folder: python tools/python/make_travel_backup.py
Uses only Python's standard library. Does not include Git history or Godot caches.
"""

from datetime import datetime, timezone
import hashlib
import json
from pathlib import Path
import subprocess
import zipfile


ROOT = Path(__file__).resolve().parents[2]
EVIDENCE = ("rts_mission_1_forest", "rts_mission_1", "forest_fight_4")


def main():
    tracked = subprocess.check_output(
        ["git", "ls-files", "-z"], cwd=ROOT
    ).decode("utf-8").split("\0")
    paths = {p for p in tracked if p}
    for name in EVIDENCE:
        paths.update(
            p.relative_to(ROOT).as_posix()
            for p in (ROOT / "render_captures" / name).rglob("*")
            if p.is_file()
        )
    stamp = datetime.now(timezone.utc).strftime("%Y-%m-%d_%H%M%SZ")
    output = ROOT / "builds" / f"Balance5-travel-{stamp}.zip"
    output.parent.mkdir(exist_ok=True)
    manifest = {
        "created_utc": stamp,
        "base_commit": subprocess.check_output(
            ["git", "rev-parse", "HEAD"], cwd=ROOT, text=True
        ).strip(),
        "working_tree_status": subprocess.check_output(
            ["git", "status", "--porcelain=v1"], cwd=ROOT, text=True
        ),
        "files": {},
    }
    with zipfile.ZipFile(output, "w", zipfile.ZIP_DEFLATED, compresslevel=6) as archive:
        for name in sorted(paths):
            data = (ROOT / name).read_bytes()
            manifest["files"][name] = {
                "bytes": len(data), "sha256": hashlib.sha256(data).hexdigest()
            }
            archive.writestr(f"Balance5/{name}", data)
        archive.writestr(
            "Balance5/TRAVEL_MANIFEST.json",
            json.dumps(manifest, indent=2, ensure_ascii=False) + "\n",
        )
    with zipfile.ZipFile(output) as archive:
        bad = archive.testzip()
        if bad:
            raise RuntimeError(f"Corrupt archive member: {bad}")
    with output.open("rb") as stream:
        digest = hashlib.file_digest(stream, "sha256").hexdigest()
    output.with_suffix(".zip.sha256").write_text(
        f"{digest}  {output.name}\n", encoding="utf-8"
    )
    print(f"Verified ZIP: {output}")
    print(f"Files: {len(paths)} plus manifest; bytes: {output.stat().st_size}")
    print(f"SHA256: {digest}")


if __name__ == "__main__":
    main()
