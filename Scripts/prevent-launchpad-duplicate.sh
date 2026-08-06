#!/bin/bash
# Verhindert doppelte SAM-Einträge im Launchpad:
# Die DerivedData-Kopie wird aus Launch Services entfernt, sobald /Applications/SAM.app existiert.

set -euo pipefail

APP="${BUILT_PRODUCTS_DIR:-}/SAM.app"
DEST="/Applications/SAM.app"
LSREGISTER="/System/Library/Frameworks/CoreServices.framework/Frameworks/LaunchServices.framework/Support/lsregister"

if [ ! -d "$APP" ]; then
  exit 0
fi

if [ ! -d "$DEST" ]; then
  exit 0
fi

"$LSREGISTER" -u "$APP" 2>/dev/null || true
rm -rf "$APP"
echo "note: DerivedData SAM.app entfernt – nur /Applications/SAM.app bleibt im Launchpad"
