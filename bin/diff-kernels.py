#!/usr/bin/env python3

import sys
import difflib
from pathlib import Path

if len(sys.argv) != 4:
    print("Compares 2 directories of kernel sources")
    print("It can be useful if you have accidentally modified a source file.")
    print("")
    print("Usage: kernel_diff.py <tree_old> <tree_new> <output_dir>")
    sys.exit(1)

tree_old = Path(sys.argv[1]).resolve()
tree_new = Path(sys.argv[2]).resolve()
out_dir = Path(sys.argv[3]).resolve()

changed_dir = out_dir / "changed"
added_dir = out_dir / "added"
removed_dir = out_dir / "removed"

for d in (changed_dir, added_dir, removed_dir):
    d.mkdir(parents=True, exist_ok=True)


def wanted(path: Path) -> bool:
    return path.suffix in (".c", ".h")


def rel(path, base):
    return path.relative_to(base)


old_files = {
    rel(p, tree_old): p for p in tree_old.rglob("*") if p.is_file() and wanted(p)
}

new_files = {
    rel(p, tree_new): p for p in tree_new.rglob("*") if p.is_file() and wanted(p)
}

# Deleted files
for r in sorted(old_files.keys() - new_files.keys()):
    target = removed_dir / r
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(str(r) + "\n")

# Added files
for r in sorted(new_files.keys() - old_files.keys()):
    target = added_dir / r
    target.parent.mkdir(parents=True, exist_ok=True)
    target.write_text(str(r) + "\n")

# Modified files
for r in sorted(old_files.keys() & new_files.keys()):
    with old_files[r].open(errors="ignore") as f:
        old_lines = f.readlines()
    with new_files[r].open(errors="ignore") as f:
        new_lines = f.readlines()

    if old_lines != new_lines:
        diff = difflib.unified_diff(
            old_lines,
            new_lines,
            fromfile=f"{tree_old.name}/{r}",
            tofile=f"{tree_new.name}/{r}",
            lineterm="",
        )

        diff_path = changed_dir / (str(r) + ".diff")
        diff_path.parent.mkdir(parents=True, exist_ok=True)
        diff_path.write_text("\n".join(diff))

print("Diff generated in:", out_dir)
