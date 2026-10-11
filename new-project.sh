#!/usr/bin/env bash
# Create a new cross-platform Rust GUI project from template/.
#
# Usage: ./new-project.sh <dir> <crate> "<Display Name>" <app.id> <owner/repo> "<Vendor>"
# Example: ./new-project.sh ~/myprojects/notecraft notecraft "NoteCraft" com.acme.notecraft acme/notecraft "Acme Ltd"
#
# Copies template/ to <dir>, replaces the placeholders (SPEC.md, top of the file), renames the
# files that carry them, fills the WiX GUIDs and writes placeholder icons. <dir> must not exist.
set -euo pipefail

if [ $# -ne 6 ]; then
  sed -n '2,8p' "$0"
  exit 2
fi
DIR="$1" CRATE="$2" NAME="$3" APP_ID="$4" REPO="$5" VENDOR="$6"
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

[[ "$CRATE" =~ ^[a-z][a-z0-9-]*$ ]] || { echo "error: crate name must be lowercase letters, digits and '-'" >&2; exit 1; }
[[ "$APP_ID" =~ ^[a-zA-Z][a-zA-Z0-9_-]*(\.[a-zA-Z][a-zA-Z0-9_-]*)+$ ]] || { echo "error: app id must be reverse-DNS, e.g. com.acme.$CRATE" >&2; exit 1; }
[[ "$REPO" =~ ^[^/]+/[^/]+$ ]] || { echo "error: repo must be owner/name" >&2; exit 1; }
[ ! -e "$DIR" ] || { echo "error: $DIR already exists" >&2; exit 1; }

UPPER="$(printf '%s' "$CRATE" | tr 'a-z-' 'A-Z_')"
guid() { python3 -c 'import uuid; print(str(uuid.uuid4()).upper())'; }

mkdir -p "$(dirname "$DIR")"
cp -R "$HERE/template" "$DIR"
cd "$DIR"

# Rename files whose names carry a placeholder (deepest first).
find . -depth -name '*myapp*' | while read -r path; do
  base="$(basename "$path")"
  new="${base//com.example.myapp/$APP_ID}"
  new="${new//myapp/$CRATE}"
  mv "$path" "$(dirname "$path")/$new"
done

# Replace placeholders in every text file. Order matters: the longest, most specific first.
export CRATE NAME APP_ID REPO VENDOR UPPER
UPGRADE_CODE="$(guid)"
GUID_APP="$(guid)"
GUID_STARTMENU="$(guid)"
GUID_DESKTOP="$(guid)"
export UPGRADE_CODE GUID_APP GUID_STARTMENU GUID_DESKTOP
find . -type f ! -name '*.png' ! -name '*.ico' ! -name '*.icns' -print0 | xargs -0 python3 -I -c '
import os, sys
env = os.environ
pairs = [
    ("com.example.myapp", env["APP_ID"]),
    ("com.example", env["APP_ID"].rsplit(".", 1)[0]),
    ("example/myapp", env["REPO"]),
    ("Example Org", env["VENDOR"]),
    ("@UPGRADE_CODE@", env["UPGRADE_CODE"]),
    ("@GUID_APP@", env["GUID_APP"]),
    ("@GUID_STARTMENU@", env["GUID_STARTMENU"]),
    ("@GUID_DESKTOP@", env["GUID_DESKTOP"]),
    ("MYAPP", env["UPPER"]),
    ("MyApp", env["NAME"]),
    ("myapp_core", env["CRATE"].replace("-", "_") + "_core"),
    ("myapp_ui", env["CRATE"].replace("-", "_") + "_ui"),
    ("myapp", env["CRATE"]),
]
for path in sys.argv[1:]:
    try:
        text = open(path, encoding="utf-8").read()
    except UnicodeDecodeError:
        continue
    new = text
    for old, rep in pairs:
        new = new.replace(old, rep)
    if new != text:
        open(path, "w", encoding="utf-8").write(new)
'

python3 -I "$HERE/placeholder-icons.py" "$DIR" "$APP_ID" "$CRATE"

# The new names can change import order and line lengths, which `cargo fmt --check` (the first CI
# gate) would reject. Reformat once, so the project starts green.
if command -v cargo >/dev/null 2>&1; then
  cargo fmt --all || echo "warning: cargo fmt failed; run it before the first commit" >&2
else
  echo "warning: cargo not found; run 'cargo fmt --all' before the first commit" >&2
fi

# The specification travels with the project, unchanged (it names the placeholders on purpose),
# together with where and from which template commit the project was made.
mkdir -p docs
cp "$HERE/SPEC.md" "$HERE/CICD.md" docs/
{
  echo "template: $HERE"
  echo "source: $(git -C "$HERE" remote get-url origin 2>/dev/null || echo none)"
  echo "commit: $(git -C "$HERE" rev-parse HEAD 2>/dev/null || echo unknown)"
  echo "created: $(date -u +%Y-%m-%d)"
  echo "crate=$CRATE name=$NAME app_id=$APP_ID repo=$REPO vendor=$VENDOR"
} >docs/template-origin.txt

echo
echo "Created $NAME in $DIR. Next:"
echo "  cd $DIR && git init -b main && cargo generate-lockfile && cargo xtask ci"
echo "  Replace the placeholder icons in assets/app-icon/ and review packaging/linux/*.metainfo.xml.in"
