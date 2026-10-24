#!/usr/bin/env bash
#
# Builds the Media Shortcuts Magisk zip.
# Works in Git Bash, WSL, and plain Linux. Needs `zip`.
#
#   ./build.sh

set -euo pipefail

cd "$(dirname "$0")"

PROP=module.prop

[ -f "$PROP" ] || { echo "module.prop not found" >&2; exit 1; }

prop() {
    sed -n "s/^$1=//p" "$PROP" | head -n1 | tr -d '\r'
}

MODULE_ID=$(prop id)
VERSION=$(prop version)
NAME=$(prop name)

[ -n "$MODULE_ID" ] || { echo "module.prop has no id= line" >&2; exit 1; }
[ -n "$VERSION" ] || VERSION=dev

ZIP="${MODULE_ID}-${VERSION}.zip"

# Git Bash on Windows usually has no zip. Hand the whole job to PowerShell.
if ! command -v zip >/dev/null 2>&1; then
    if command -v powershell >/dev/null 2>&1; then
        exec powershell -NoProfile -ExecutionPolicy Bypass -File "$(pwd -W 2>/dev/null || pwd)/build.ps1"
    fi
    echo "zip is not installed. Debian/Ubuntu: apt install zip" >&2
    exit 1
fi

echo
echo "  ${NAME}  ${VERSION}"
echo "  id: ${MODULE_ID}"
echo

STAGE=$(mktemp -d)
trap 'rm -rf "$STAGE"' EXIT

META="$STAGE/META-INF/com/google/android"
mkdir -p "$META"

printf '#MAGISK\n' > "$META/updater-script"

cat > "$META/update-binary" <<'STUB'
#!/sbin/sh
umask 022
OUTFD=$2
ZIPFILE=$3
mount /data 2>/dev/null
[ -f /data/adb/magisk/util_functions.sh ] || { echo "! Magisk not found"; exit 1; }
. /data/adb/magisk/util_functions.sh
install_module
exit 0
STUB

# Everything in the module folder except build tooling and docs.
shopt -s nullglob dotglob
for f in *; do
    case "$f" in
        build.sh|build.ps1|build.bat|README.md|LICENSE|META-INF|.git|.gitignore|.gitattributes|*.zip)
            continue
            ;;
    esac
    cp -a "$f" "$STAGE/"
done

rm -f "$ZIP"

( cd "$STAGE" && zip -rq "$OLDPWD/$ZIP" . )

# Sanity check
for need in module.prop META-INF/com/google/android/update-binary META-INF/com/google/android/updater-script; do
    if ! unzip -Z1 "$ZIP" | grep -qx "$need"; then
        echo "zip is missing: $need" >&2
        exit 1
    fi
done

SIZE=$(du -k "$ZIP" | cut -f1)
COUNT=$(unzip -Z1 "$ZIP" | wc -l)

echo "  built   $(pwd)/$ZIP"
echo "  size    ${SIZE} KB"
echo "  files   ${COUNT}"
echo
echo "  adb push \"$ZIP\" /sdcard/Download/$ZIP"
echo "  adb shell su -c \"magisk --install-module /sdcard/Download/$ZIP\""
echo
