"""Bundle the Android assets. Skips sounds, backups and the local dev flag."""
import os
import zipfile

ROOT = os.path.abspath(os.path.join(os.path.dirname(__file__), ".."))
OUT = os.path.join(ROOT, "android", "app", "src", "main", "assets", "data.zip")
SKIP_DIRS = {"sounds", ".git", "__pycache__", "_backup_original"}
ROOT_FILES = ("init.lua", "otclientrc.lua", "cacert.pem")


def include(path):
    parts = set(path.replace("\\", "/").split("/"))
    if parts & SKIP_DIRS:
        return False
    name = os.path.basename(path)
    if name == "devserver.flag" or name.endswith(".log"):
        return False
    return True


def main():
    os.makedirs(os.path.dirname(OUT), exist_ok=True)
    count = 0
    with zipfile.ZipFile(OUT, "w", compression=zipfile.ZIP_DEFLATED) as zf:
        for folder in ("data", "modules", "mods"):
            base = os.path.join(ROOT, folder)
            for dirpath, dirnames, filenames in os.walk(base):
                dirnames[:] = [name for name in dirnames if name not in SKIP_DIRS]
                for filename in filenames:
                    full = os.path.join(dirpath, filename)
                    rel = os.path.relpath(full, ROOT).replace("\\", "/")
                    if not include(rel):
                        continue
                    zf.write(full, rel)
                    count += 1
        for filename in ROOT_FILES:
            full = os.path.join(ROOT, filename)
            if os.path.isfile(full):
                zf.write(full, filename)
                count += 1
    print(f"files={count} zip={os.path.getsize(OUT)}")


if __name__ == "__main__":
    main()
