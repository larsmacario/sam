# Projekt: SAM

## Sprache
Antworte auf Deutsch.

## Was das ist
SAM ist eine native macOS-Menüleisten-App: ein Voice-First-Assistent (ähnlich Wispr Flow). fn-Taste halten → sprechen → lokale Transkription → Claude antwortet. Persönliche KI für den Eigengebrauch.

## Wichtige Befehle
- Dev:   `open Sam.xcodeproj` (nach `xcodegen generate`)
- Build: `xcodebuild` bzw. Build in Xcode
- Test:  `xcodebuild test` (folgt)

## Konventionen
- Code/Variablennamen Englisch, Kommentare Deutsch
- API-Key nur im macOS Keychain, nie im Klartext
- Auth hinter Protokoll gekapselt (API-Key jetzt, OAuth später)
- Keine festen Modi – Claude erkennt Intent aus dem gesprochenen Text

## Memory
Lies zu Beginn jeder Session `.agents/memory/project.md` und `.agents/memory/current.md`.
Bei `update memory`: aktualisiere `current.md`, `project.md` nur bei Architektur-Änderungen.
