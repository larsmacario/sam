# Aktueller Stand

## Letzte Änderungen
- **Meeting deaktiviert:** Code im Repo, per `project.yml`-Exclude nicht im Build; Migration `meeting` → KI.
- **KI und Chat vereint:** Nur noch 2 Modi (Diktat ↔ KI); Chat-Panel und Mehrturn-Dialog im KI-Modus mit intelligentem Routing.
- **Release installiert:** `/Applications/SAM.app` (v1.0.0); alte Builds/Launchpad-Einträge bereinigt.

## Fokus
- Installierte Version in `/Applications` manuell testen (fn+⌥, Push-to-talk, Ein-Turn, Mehrturn-Chat).

## Nächste Schritte
1. Commit & Push (Meeting-Entfernung + Modus-Vereinigung).
2. Optional: Meeting später reaktivieren.
3. Optional Release `v1.1.0` taggen.

## Offene Punkte
- API-Keys in UserDefaults (nicht Keychain).
- Keine Notarisierung → Gatekeeper-Warnung für Download-Nutzer.
- Markdown-Links, Streaming, OAuth, Keychain-Migration offen.
