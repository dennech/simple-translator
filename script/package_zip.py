#!/usr/bin/env python3
"""Package only public app files; omit Finder metadata, local paths and owner IDs."""
import pathlib
import os
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
    "Contents/Resources/Sparkle-LICENSE.txt",
    "Contents/_CodeSignature/CodeResources",
}
framework = pathlib.Path("Contents/Frameworks/Sparkle.framework")
# Derive the framework inventory from the dependency whose checksum SwiftPM verified.
reference = pathlib.Path(sys.argv[3])
def entries(root):
    return {path.relative_to(root) for path in root.rglob("*") if path.is_symlink() or path.is_file()}

files = entries(app)
if files != {pathlib.Path(name) for name in allowed} | {framework / name for name in entries(reference)}:
    raise SystemExit("Unexpected app bundle contents.")

with zipfile.ZipFile(destination, "w", compression=zipfile.ZIP_DEFLATED, compresslevel=9) as archive:
    for relative in sorted(files):
        path = app / relative
        is_link = path.is_symlink()
        data = os.fsencode(os.readlink(path)) if is_link else path.read_bytes()
        if relative.is_relative_to(framework):
            original = reference / relative.relative_to(framework)
            if is_link != original.is_symlink() or (is_link and not path.resolve(strict=True).is_relative_to((app / framework).resolve())):
                raise SystemExit("Unexpected framework link.")
            expected = os.fsencode(os.readlink(original)) if is_link else original.read_bytes()
            if data != expected:
                raise SystemExit("Embedded framework differs from the pinned release.")
        elif is_link:
            raise SystemExit("Unexpected app bundle link.")
        info = zipfile.ZipInfo(f"{app.name}/{relative}", date_time=(2026, 1, 1, 0, 0, 0))
        info.create_system = 3
        mode = 0o755 if path.stat().st_mode & 0o111 else 0o644
        info.external_attr = ((stat.S_IFLNK | 0o777) if is_link else (stat.S_IFREG | mode)) << 16
        info.compress_type = zipfile.ZIP_DEFLATED
        archive.writestr(info, data)
