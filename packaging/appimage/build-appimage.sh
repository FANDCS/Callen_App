#!/usr/bin/env bash
#
# build-appimage.sh — Χτίζει το Callen ως καθολικά φορητό .AppImage (x86_64)
# χρησιμοποιώντας linuxdeploy + linuxdeploy-plugin-gtk, ώστε να μπαζώνονται
# ΟΛΕΣ οι απαραίτητες shared libraries (GTK3, GLib, Pango, κ.λπ.) μέσα στο
# ίδιο το AppImage. Έτσι τρέχει σε σχεδόν οποιαδήποτε σύγχρονη διανομή χωρίς
# να χρειάζεται ο χρήστης να εγκαταστήσει τίποτα.
#
# Χρήση:
#   1. Βάλε αυτό το script στο repo:  packaging/appimage/build-appimage.sh
#   2. Τρέξε το από τη ρίζα του repo:  bash packaging/appimage/build-appimage.sh
#
# Προαπαιτούμενα στο μηχάνημα build (Ubuntu/Debian παράδειγμα):
#   sudo apt update
#   sudo apt install -y clang cmake ninja-build pkg-config libgtk-3-dev \
#                        liblzma-dev libstdc++-12-dev fuse curl patchelf desktop-file-utils
#   flutter config --enable-linux-desktop
#
set -euo pipefail

# --- Ρυθμίσεις έργου (από pubspec.yaml / linux/CMakeLists.txt) ---
APP_NAME="Callen"
BINARY_NAME="callen"
ICON_SRC_REL="assets/icons/phonelefter_trans.png"

# Το script πρέπει να βρίσκεται σε <repo_root>/packaging/appimage/.
# Υπολογίζουμε τη ρίζα του repo από τη ΘΕΣΗ του ίδιου του αρχείου, όχι από
# το directory απ' όπου το καλείς — έτσι δουλεύει είτε το τρέξεις με
# `bash packaging/appimage/build-appimage.sh` από τη ρίζα, είτε μπεις μέσα
# στον φάκελο packaging/appimage και το τρέξεις τοπικά (`./build-appimage.sh`).
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
ROOT_DIR="$(cd "${SCRIPT_DIR}/../.." && pwd)"
cd "${ROOT_DIR}"

if [ ! -f "${ROOT_DIR}/pubspec.yaml" ]; then
  echo "ΣΦΑΛΜΑ: δεν βρέθηκε pubspec.yaml στο ${ROOT_DIR}."
  echo "Βεβαιώσου ότι αυτό το script βρίσκεται στο <repo_root>/packaging/appimage/build-appimage.sh"
  exit 1
fi

ICON_SRC="${ROOT_DIR}/${ICON_SRC_REL}"
VERSION="$(grep '^version:' pubspec.yaml | awk '{print $2}' | cut -d'+' -f1)"

BUILD_DIR="${ROOT_DIR}/build/linux/x64/release/bundle"
APPDIR="${ROOT_DIR}/AppDir"
DIST_DIR="${ROOT_DIR}/dist"
CACHE_DIR="${ROOT_DIR}/.cache"
PACKAGING_DIR="${ROOT_DIR}/packaging/appimage"

echo "==> Καθαρισμός παλιών φακέλων build..."
rm -rf "${APPDIR}" "${DIST_DIR}"
mkdir -p "${DIST_DIR}" "${CACHE_DIR}"

echo "==> Λήψη dependencies..."
flutter pub get

echo "==> Χτίσιμο Flutter Linux release bundle..."
flutter build linux --release

if [ ! -f "${BUILD_DIR}/${BINARY_NAME}" ]; then
  echo "ΣΦΑΛΜΑ: δεν βρέθηκε το εκτελέσιμο ${BUILD_DIR}/${BINARY_NAME}."
  echo "Έλεγξε ότι το BINARY_NAME ταιριάζει με το linux/CMakeLists.txt (set(BINARY_NAME ...))."
  exit 1
fi

echo "==> Δημιουργία δομής AppDir..."
mkdir -p "${APPDIR}/usr/bin"
mkdir -p "${APPDIR}/usr/share/applications"
mkdir -p "${APPDIR}/usr/share/icons/hicolor/256x256/apps"

# Ολόκληρο το Flutter bundle (εκτελέσιμο + lib/ + data/) μένει μαζί,
# γιατί το Flutter engine ψάχνει lib/ και data/ σχετικά με το εκτελέσιμο.
cp -r "${BUILD_DIR}/." "${APPDIR}/usr/bin/"

# .desktop αρχείο
if [ -f "${PACKAGING_DIR}/callen.desktop" ]; then
  cp "${PACKAGING_DIR}/callen.desktop" "${APPDIR}/usr/share/applications/${BINARY_NAME}.desktop"
else
  cat > "${APPDIR}/usr/share/applications/${BINARY_NAME}.desktop" << EOF
[Desktop Entry]
Type=Application
Name=${APP_NAME}
Exec=${BINARY_NAME}
Icon=${BINARY_NAME}
Terminal=false
Categories=Network;Telephony;GTK;
EOF
fi

# Εικονίδιο — προτιμάται τετράγωνο 256x256 αν υπάρχει (packaging/appimage/callen-256.png)
if [ -f "${PACKAGING_DIR}/callen-256.png" ]; then
  cp "${PACKAGING_DIR}/callen-256.png" "${APPDIR}/usr/share/icons/hicolor/256x256/apps/${BINARY_NAME}.png"
else
  echo "    (tip: τρέξε 'convert ${ICON_SRC} -resize 256x256 packaging/appimage/callen-256.png' για καλύτερο εικονίδιο)"
  cp "${ICON_SRC}" "${APPDIR}/usr/share/icons/hicolor/256x256/apps/${BINARY_NAME}.png"
fi

echo "==> Λήψη linuxdeploy + linuxdeploy-plugin-gtk (cache σε .cache/)..."
LINUXDEPLOY="${CACHE_DIR}/linuxdeploy-x86_64.AppImage"
LINUXDEPLOY_GTK="${CACHE_DIR}/linuxdeploy-plugin-gtk.sh"

if [ ! -f "${LINUXDEPLOY}" ]; then
  curl -L -o "${LINUXDEPLOY}" \
    "https://github.com/linuxdeploy/linuxdeploy/releases/download/continuous/linuxdeploy-x86_64.AppImage"
  chmod +x "${LINUXDEPLOY}"
fi
if [ ! -f "${LINUXDEPLOY_GTK}" ]; then
  curl -L -o "${LINUXDEPLOY_GTK}" \
    "https://raw.githubusercontent.com/linuxdeploy/linuxdeploy-plugin-gtk/master/linuxdeploy-plugin-gtk.sh"
  chmod +x "${LINUXDEPLOY_GTK}"
fi

# linuxdeploy τρέχει καλύτερα εξαγμένο (χωρίς FUSE) σε container/CI περιβάλλοντα.
EXTRACT_DIR="${CACHE_DIR}/squashfs-root-linuxdeploy"
if [ ! -d "${EXTRACT_DIR}" ]; then
  ( cd "${CACHE_DIR}" && "${LINUXDEPLOY}" --appimage-extract >/dev/null && mv squashfs-root "$(basename "${EXTRACT_DIR}")" )
fi
LINUXDEPLOY_BIN="${EXTRACT_DIR}/AppRun"

echo "==> Εκτέλεση linuxdeploy (bundling GTK/GLib/Pango + όλων των shared libs)..."
export NO_STRIP=1
export DEPLOY_GTK_VERSION=3
PATH="${CACHE_DIR}:${PATH}" "${LINUXDEPLOY_BIN}" \
  --appdir "${APPDIR}" \
  --executable "${APPDIR}/usr/bin/${BINARY_NAME}" \
  --desktop-file "${APPDIR}/usr/share/applications/${BINARY_NAME}.desktop" \
  --icon-file "${APPDIR}/usr/share/icons/hicolor/256x256/apps/${BINARY_NAME}.png" \
  --plugin gtk \
  --output appimage

# Το linuxdeploy παράγει το .AppImage στον τρέχοντα φάκελο· το μετακινούμε στο dist/
GENERATED="$(find "${ROOT_DIR}" -maxdepth 1 -name "${APP_NAME}*.AppImage" -newer "${APPDIR}" | head -n1)"
OUTPUT_FILE="${DIST_DIR}/${APP_NAME}-${VERSION}-x86_64.AppImage"
mv "${GENERATED}" "${OUTPUT_FILE}"
chmod +x "${OUTPUT_FILE}"

echo ""
echo "==> Έτοιμο: ${OUTPUT_FILE}"
echo "    Τρέξε το με:  ./$(basename "${OUTPUT_FILE}")"
echo "    (Δεν χρειάζεται καμία εγκατάσταση — μόνο chmod +x και διπλό κλικ / εκτέλεση.)"
