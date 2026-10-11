#!/usr/bin/env bash
# Build and package MyApp for Linux (<arch>: x86_64 or aarch64, or riscv64 when cross-compiling):
#
#   $DIST/myapp-<version>-linux-<arch>.AppImage        any distro with glibc >= the build host's
#   $DIST/myapp-<version>-linux-<arch>.AppImage.zsync  delta updates (needs zsyncmake)
#   $DIST/myapp-<version>-linux-<arch>.deb             Debian, Ubuntu, Mint, ...
#   $DIST/myapp-<version>-linux-<arch>.rpm             Fedora, openSUSE, RHEL, ...
#   $DIST/myapp-<version>-linux-<arch>.tar.gz          plain FHS-style tree (bin/, share/)
#
# Cross-compiling (CI: riscv64, tar only): set CROSS_ARCH, CROSS_TARGET (the Rust target),
# CROSS_COMPILE (binutils prefix, for strip) and optionally EMULATOR (e.g. qemu-riscv64).
#
# Usage: packaging/linux/package.sh [--skip-build] [--formats "appimage deb rpm tar"]
#
# Needs: cargo; nfpm for deb/rpm; appimagetool (downloaded if missing). Build on an old distro
# (CI: Ubuntu 22.04, glibc 2.35) so the binary runs on newer ones.
set -euo pipefail
# shellcheck source=packaging/env.sh
. "$(dirname "${BASH_SOURCE[0]}")/../env.sh"
HERE="$ROOT/packaging/linux"
APP_ID=com.example.myapp

SKIP_BUILD=0
FORMATS="appimage deb rpm tar"
while [ $# -gt 0 ]; do
  case "$1" in
    --skip-build) SKIP_BUILD=1; shift ;;
    --formats) FORMATS="$2"; shift 2 ;;
    -h | --help) sed -n '2,17p' "$0"; exit 0 ;;
    *) echo "unknown argument: $1" >&2; exit 2 ;;
  esac
done

ARCH="${CROSS_ARCH:-$(uname -m)}"
case "$ARCH" in
  riscv64) DEB_ARCH=riscv64 ;;
  x86_64) DEB_ARCH=amd64 ;;
  aarch64 | arm64) ARCH=aarch64; DEB_ARCH=arm64 ;;
  *) echo "unsupported architecture $ARCH" >&2; exit 2 ;;
esac
export MYAPP_MAINTAINER="${MYAPP_MAINTAINER:-MyApp maintainers <maintainers@example.com>}"
BASENAME="myapp-$VERSION-linux-$ARCH"

echo "==> MyApp $VERSION for Linux $ARCH ($FORMATS)"

if [ "$SKIP_BUILD" = 0 ]; then
  (cd "$ROOT" && cargo build --release --locked -p myapp ${CROSS_TARGET:+--target "$CROSS_TARGET"})
fi
BIN="$CARGO_TARGET_DIR/${CROSS_TARGET:+$CROSS_TARGET/}release"
WORK="$CARGO_TARGET_DIR/linux-package"
STAGE="$WORK/root"
fresh_dir "$WORK"

# ---- stage an FHS tree (shared by every format) -------------------------------------------------
install -Dm755 "$BIN/myapp" "$STAGE/usr/bin/myapp"
"${CROSS_COMPILE:-}strip" "$STAGE/usr/bin/myapp" 2>/dev/null || true
install -Dm644 "$HERE/$APP_ID.desktop" "$STAGE/usr/share/applications/$APP_ID.desktop"
mkdir -p "$STAGE/usr/share/metainfo"
sed -e "s/@VERSION@/$VERSION/g" -e "s/@DATE@/$MYAPP_BUILD_DATE/g" \
  "$HERE/$APP_ID.metainfo.xml.in" >"$STAGE/usr/share/metainfo/$APP_ID.metainfo.xml"
mkdir -p "$STAGE/usr/share/icons"
cp -R "$ROOT/assets/app-icon/hicolor" "$STAGE/usr/share/icons/"
mkdir -p "$STAGE/usr/share/doc/myapp"
copy_docs "$STAGE/usr/share/doc/myapp"

if command -v desktop-file-validate >/dev/null; then
  desktop-file-validate "$STAGE/usr/share/applications/$APP_ID.desktop"
fi
if command -v appstreamcli >/dev/null; then
  appstreamcli validate --no-net --explain "$STAGE/usr/share/metainfo/$APP_ID.metainfo.xml"
fi

has() { case " $FORMATS " in *" $1 "*) return 0 ;; *) return 1 ;; esac; }

# ---- .tar.gz ------------------------------------------------------------------------------------
if has tar; then
  mkdir -p "$WORK/tar"
  cp -R "$STAGE/usr" "$WORK/tar/$BASENAME"
  tar -C "$WORK/tar" -czf "$DIST/$BASENAME.tar.gz" "$BASENAME"
  echo "wrote $DIST/$BASENAME.tar.gz"
fi

# ---- .deb / .rpm --------------------------------------------------------------------------------
if has deb || has rpm; then
  command -v nfpm >/dev/null || { echo "error: nfpm not found (https://nfpm.goreleaser.com/install/)" >&2; exit 1; }
  export VERSION
  export NFPM_ARCH="$DEB_ARCH"
  # nfpm expands env vars in fields like `version` and `arch`, but not in `contents[].src`.
  sed "s|\${STAGE}|$STAGE|g" "$HERE/nfpm.yaml" >"$WORK/nfpm.yaml"
  for fmt in deb rpm; do
    if has "$fmt"; then (cd "$ROOT" && nfpm package -f "$WORK/nfpm.yaml" -p "$fmt" -t "$DIST/$BASENAME.$fmt"); fi
  done
fi

# ---- AppImage -----------------------------------------------------------------------------------
if has appimage; then
  APPDIR="$WORK/MyApp.AppDir"
  cp -R "$STAGE" "$APPDIR"
  mv "$APPDIR/usr/share/doc" "$WORK/doc-unused"
  ln -s usr/bin/myapp "$APPDIR/AppRun"
  cp "$HERE/$APP_ID.desktop" "$APPDIR/$APP_ID.desktop"
  cp "$ROOT/assets/app-icon/hicolor/256x256/apps/$APP_ID.png" "$APPDIR/$APP_ID.png"
  ln -s "$APP_ID.png" "$APPDIR/.DirIcon"

  TOOL="${APPIMAGETOOL:-$(command -v appimagetool || true)}"
  if [ -z "$TOOL" ]; then
    TOOL="$CARGO_TARGET_DIR/appimagetool-$ARCH.AppImage"
    if [ ! -x "$TOOL" ]; then
      curl -fsSL -o "$TOOL" "https://github.com/AppImage/appimagetool/releases/download/continuous/appimagetool-$ARCH.AppImage"
      chmod +x "$TOOL"
    fi
  fi
  # Absolute, because appimagetool runs in $DIST below.
  OUT="$(cd "$DIST" && pwd)/$BASENAME.AppImage"
  APPDIR="$(cd "$APPDIR" && pwd)"
  TOOL="$(cd "$(dirname "$TOOL")" && pwd)/$(basename "$TOOL")"
  # A .zsync left by an earlier run would hide a missing zsyncmake and describe another file.
  if [ -e "$OUT.zsync" ]; then mv "$OUT.zsync" "$WORK/old.zsync"; fi
  # Update information for AppImageUpdate: the .zsync published next to each AppImage on GitHub
  # Releases (`latest` = newest non-pre-release). Forks point at their own releases.
  REPO="${GITHUB_REPOSITORY:-example/myapp}"
  UPDATE_INFO="gh-releases-zsync|${REPO%%/*}|${REPO#*/}|latest|myapp-*-linux-$ARCH.AppImage.zsync"
  # Extract-and-run: works without FUSE (containers, CI). The output embeds the static runtime.
  (cd "$DIST" && ARCH="$ARCH" APPIMAGE_EXTRACT_AND_RUN=1 "$TOOL" --no-appstream -u "$UPDATE_INFO" "$APPDIR" "$OUT")
  echo "wrote $OUT"
  if [ -s "$OUT.zsync" ]; then
    echo "wrote $OUT.zsync"
  else
    warn "zsyncmake not found, so $OUT.zsync was not written; AppImage delta updates need it"
  fi
fi

if [ -z "${CROSS_TARGET:-}" ]; then
  "$STAGE/usr/bin/myapp" --version
elif [ -n "${EMULATOR:-}" ]; then
  "$EMULATOR" "$STAGE/usr/bin/myapp" --version
fi
echo "==> done"
ls -lh "$DIST"
