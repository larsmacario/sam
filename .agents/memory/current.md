# Aktueller Stand

## Letzte Änderungen
- **4-Tab-Einstellungen:** Start, Sprache, KI, Namen – Tab-Leiste mit vollflächigen Klickzielen.
- **Eigennamen:** Dynamische Label/Wert-Liste in `SettingsStore`, KI-Prompts + UI personalisiert.
- **Chat-Modus:** Mehrturn-Dialog im Sidepanel (`ChatSession`, `OverlayWindow`).
- **Doku:** README, INSTALLATION, SECURITY, GITHUB_SETUP aktualisiert.

## Fokus
- Commit & Push der Feature-Änderungen; optional Release `v1.1.0` taggen.

## Nächste Schritte
1. Release taggen nach Push (`v1.1.0` mit Chat + Personalisierung).
2. Manuell: Eigennamen + Tab-Navigation in installierter `/Applications/SAM.app` verifizieren.

## Offene Punkte
- API-Keys in UserDefaults (nicht Keychain).
- Keine Notarisierung → Gatekeeper-Warnung für Download-Nutzer.
- Streaming, OAuth, Keychain-Migration offen.
