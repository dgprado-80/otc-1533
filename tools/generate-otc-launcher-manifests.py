"""Build client.windows.json and assets.windows.json for the BestServerOt launcher."""
import hashlib
import json
import os
import sys

ROOT = os.path.abspath(sys.argv[1])
REVISION = int(sys.argv[2])
VERSION = sys.argv[3] if len(sys.argv) > 3 else "15.30"

SKIP_FILES = {
    "client.windows.json",
    "assets.windows.json",
    "BestServerOt.exe",
    "BestServerOt.exe.sha256",
    "UPLOAD-LEIA-ME.txt",
    "devserver.flag",
}
SKIP_DIRS = {"_backup_original", ".git", "__pycache__"}


def sha256_file(path):
    digest = hashlib.sha256()
    with open(path, "rb") as handle:
        for chunk in iter(lambda: handle.read(1024 * 1024), b""):
            digest.update(chunk)
    return digest.hexdigest()


def entry(rel, path):
    digest = sha256_file(path)
    size = os.path.getsize(path)
    return {
        "localfile": rel,
        "url": rel,
        "packedhash": digest,
        "unpackedhash": digest,
        "packedsize": size,
        "unpackedsize": size,
        "unpack": False,
    }


client_files = []
asset_files = []
for dirpath, dirnames, filenames in os.walk(ROOT):
    dirnames[:] = [name for name in dirnames if name not in SKIP_DIRS]
    for name in filenames:
        if name in SKIP_FILES or name.endswith(".log") or name.endswith(".zip") or name.endswith(".disabled"):
            continue
        full = os.path.join(dirpath, name)
        rel = os.path.relpath(full, ROOT).replace("\\", "/")
        item = entry(rel, full)
        if rel.startswith("data/"):
            asset_files.append(item)
        else:
            client_files.append(item)

if not any(item["localfile"] == "BestOTC.exe" for item in client_files):
    raise SystemExit("BestOTC.exe ausente no pacote")
if not asset_files:
    raise SystemExit("data/ vazio")

client_manifest = {
    "version": VERSION,
    "revision": REVISION,
    "executable": "BestOTC.exe",
    "generation": "second",
    "files": client_files,
}
assets_manifest = {
    "version": 1,
    "files": asset_files,
}

for filename, payload in (
    ("client.windows.json", client_manifest),
    ("assets.windows.json", assets_manifest),
):
    path = os.path.join(ROOT, filename)
    with open(path, "w", encoding="utf-8", newline="\n") as handle:
        json.dump(payload, handle, separators=(",", ":"))
    print(f"{filename} files={len(payload['files'])} bytes={os.path.getsize(path)}")

print(f"revision={REVISION} version={VERSION}")
