#!/usr/bin/env bash
# Erstellt SAM.dmg mit Drag-to-Applications-Layout.
# Nutzung: create-dmg.sh <pfad-zu/SAM.app> [ausgabe/SAM.dmg]

set -euo pipefail

APP_PATH="${1:?SAM.app Pfad fehlt}"
OUTPUT_DMG="${2:-SAM.dmg}"

if [[ ! -d "$APP_PATH" ]]; then
  echo "Fehler: $APP_PATH existiert nicht" >&2
  exit 1
fi

APP_NAME="$(basename "$APP_PATH")"
STAGING="$(mktemp -d)"
trap 'rm -rf "$STAGING"' EXIT

ditto "$APP_PATH" "$STAGING/$APP_NAME"
ln -s /Applications "$STAGING/Applications"

hdiutil create \
  -volname "SAM" \
  -srcfolder "$STAGING" \
  -ov \
  -format UDZO \
  "$OUTPUT_DMG"

echo "DMG erstellt: $OUTPUT_DMG"
