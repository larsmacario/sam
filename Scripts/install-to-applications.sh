#!/bin/bash
# Kopiert SAM.app nach /Applications — fester Pfad für stabile Bedienungshilfen-Freigaben.
# Deaktivieren: SKIP_INSTALL_TO_APPLICATIONS=1

set -euo pipefail

APP_NAME="SAM.app"
BUILT_APP="${BUILT_PRODUCTS_DIR:-}/${APP_NAME}"
DEST="/Applications/${APP_NAME}"

if [ "${SKIP_INSTALL_TO_APPLICATIONS:-0}" = "1" ]; then
  echo "note: Installation nach /Applications übersprungen (SKIP_INSTALL_TO_APPLICATIONS=1)"
  exit 0
fi

if [ ! -d "$BUILT_APP" ]; then
  echo "warning: ${BUILT_APP} nicht gefunden – Installation übersprungen"
  exit 0
fi

LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

echo "Installiere ${BUILT_APP} → ${DEST} …"
osascript -e 'tell application "SAM" to quit' 2>/dev/null || true
sleep 0.5
ditto "$BUILT_APP" "$DEST"
"$LSREGISTER" -f -R -trusted "$DEST"
"$LSREGISTER" -u "$BUILT_APP" 2>/dev/null || true
rm -rf "$BUILT_APP"
echo "SAM installiert unter ${DEST}"
