# Aktueller Stand

## Letzte Änderungen
- **Security-Hardening:** API-Keys in Keychain (Migration von UserDefaults), `.gitignore` erweitert, `SECURITY.md` mit Datenfluss-Tabelle, optional signierte Releases.
- **Meeting deaktiviert:** Code im Repo, per `project.yml`-Exclude nicht im Build; Migration `meeting` → KI.
- **KI und Chat vereint:** Nur noch 2 Modi (Diktat ↔ KI); Chat-Panel und Mehrturn-Dialog im KI-Modus mit intelligentem Routing.

## Fokus
- Security-Fixes testen (Keychain-Migration bei bestehenden Keys).

## Nächste Schritte
1. Commit & Push (Security + Modus-Vereinigung).
2. Optional: Apple-Secrets für signierte Releases setzen.
3. Optional Release `v1.1.0` taggen.

## Offene Punkte
- Keine Notarisierung ohne Apple-Developer-Secrets → Gatekeeper-Warnung für Download-Nutzer.
- Markdown-Links, Streaming, OAuth offen.
