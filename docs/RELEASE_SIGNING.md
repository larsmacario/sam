# Release-Signing und Notarisierung (Maintainer)

Standard-Releases aus GitHub Actions sind **nicht signiert** (`CODE_SIGNING_ALLOWED=NO`). Nutzer sehen beim Öffnen der DMG bzw. App die Gatekeeper-Warnung und müssen Rechtsklick → Öffnen verwenden.

Mit einem **Apple Developer Program**-Account ($99/Jahr) kannst du Releases signieren und notarisieren lassen.

## Voraussetzungen

1. Apple Developer ID Application-Zertifikat
2. App-spezifisches Passwort für Notarisierung
3. GitHub Repository Secrets

## GitHub Secrets

| Secret | Inhalt |
|--------|--------|
| `APPLE_CERTIFICATE_BASE64` | Developer-ID-Zertifikat als `.p12`, base64-kodiert |
| `APPLE_CERTIFICATE_PASSWORD` | Passwort der `.p12`-Datei |
| `APPLE_ID` | Apple-ID des Developer-Accounts |
| `APPLE_APP_SPECIFIC_PASSWORD` | App-spezifisches Passwort (appleid.apple.com) |
| `APPLE_TEAM_ID` | Team-ID aus developer.apple.com |

Zertifikat exportieren:

```bash
base64 -i Certificates.p12 | pbcopy
```

## Workflow

Der Release-Workflow (`/.github/workflows/release.yml`) signiert und notarisiert automatisch, **wenn** `APPLE_CERTIFICATE_BASE64` gesetzt ist. Ohne Secrets bleibt das bisherige unsigned Build-Verhalten.

## Lokales Signieren (manuell)

```bash
xcodebuild -scheme Sam -configuration Release \
  -destination 'platform=macOS' \
  CODE_SIGN_STYLE=Manual \
  DEVELOPMENT_TEAM=DEINTEAMID \
  CODE_SIGN_IDENTITY="Developer ID Application: Dein Name (TEAMID)"
```

Danach `notarytool` für Notarisierung und `stapler` zum Anheften des Tickets.

## Referenzen

- [Apple: Notarize macOS software](https://developer.apple.com/documentation/security/notarizing-macos-software-before-distribution)
- [GitHub Actions: macOS code signing](https://docs.github.com/en/actions/deployment/deploying-xcode-applications)
