# Aktueller Stand

## Letzte Änderungen
- **Meeting-Modus (4. Modus):** fn+⌥ rotiert Diktat → KI → Chat → Meeting; fn+⌘ startet/stoppt Aufnahme; Start-Dialog mit Name + Zustimmung (`KeyPanel` für Tastatureingabe).
- **Meeting-Pille:** Größe wie Diktat-Pille; Waveform nur während aktiver Aufnahme, Idle kompakt mit Text.
- **Meeting-Historie:** JSON-Speicher in `MeetingStore`; Speicherordner wählbar unter Einstellungen → Meetings → Historie.
- **Release** in `/Applications/SAM.app` installiert (13.06.2026).

## Fokus
- Meeting-Flow manuell testen: Moduswechsel, Name eingeben, Aufnahme, Zusammenfassung, Ordnerwahl, Historie.

## Nächste Schritte
1. Commit & Push (Meeting-Modus, UI-Fixes, Speicherordner).
2. Optional: bestehende Meetings beim Ordnerwechsel migrieren.
3. Optional Release `v1.1.0` taggen.

## Offene Punkte
- API-Keys in UserDefaults (nicht Keychain).
- Keine Notarisierung → Gatekeeper-Warnung für Download-Nutzer.
- Ordnerwechsel zeigt nur Meetings im neuen Ordner (keine automatische Migration).
- Markdown-Links, Streaming, OAuth, Keychain-Migration offen.
