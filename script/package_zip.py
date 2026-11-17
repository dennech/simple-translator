#!/usr/bin/env python3
"""Package only public app files; omit Finder metadata, local paths and owner IDs."""
import pathlib
import stat
import sys
import zipfile

app = pathlib.Path(sys.argv[1])
destination = pathlib.Path(sys.argv[2])
allowed = {
    "Contents/Info.plist",
    "Contents/MacOS/SimpleTranslator",
    "Contents/Resources/AppIcon.icns",
    "Contents/Resources/FreeOptions.json",
    "Contents/_CodeSignature/CodeResources",
}
files = {path.relative_to(app).as_posix(): path for path in app.rglob("*") if path.is_file()}
if set(files) != allowed or any(path.is_symlink() for path in app.rglob("*")):
    raise SystemExit("Unexpected app bundle contents; inspect before packaging.")

with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for relative, path in sorted(files.items()):
        info = zipfile.ZipInfo(f"{app.name}/{relative}", date_time=(2026, 1, 1, 0, 0, 0))
        info.create_system = 3
        mode = 0o755 if relative == "Contents/MacOS/SimpleTranslator" else 0o644
        info.external_attr = (stat.S_IFREG | mode) << 16
        info.compress_type = zipfile.ZIP_DEFLATED
        archive.writestr(info, path.read_bytes())
