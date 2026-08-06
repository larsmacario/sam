# Projekt: SAM

## Sprache
Antworte auf Deutsch.

## Was das ist
Voice-First macOS-Menüleisten-Assistent (Wispr-Flow-ähnlich): Push-to-talk → STT → Diktat-Einfügen oder KI-Aktion/Chat. Läuft als `.accessory`-App ohne Dock-Icon.

## Wichtige Befehle
- Dev: Xcode **Product → Run** (⌘R) — baut, installiert nach `/Applications`, startet `/Applications/SAM.app`
- Build: `xcodebuild -scheme Sam -configuration Debug build`
- Install: automatisch via Scheme Post-Action `Scripts/install-to-applications.sh` (manuell mit `BUILT_PRODUCTS_DIR=… ./Scripts/install-to-applications.sh`)
- Regenerieren: `xcodegen generate`

## Konventionen
- Swift 6, SwiftUI + AppKit (`NSPanel`-Overlays)
- Variablen/Types Englisch, User-facing Text Deutsch
- Chat-UI in `Sam/UI/OverlayWindow.swift`, Orchestrierung in `Sam/App/AppState.swift`
- Nur `/Applications/SAM.app` im Launchpad — DerivedData-Kopie nach Build/Install entfernen

## Memory
Lies zu Beginn jeder Session `.agents/memory/project.md` und `.agents/memory/current.md`.
Bei `update memory`: aktualisiere `current.md`, `project.md` nur bei Architektur-Änderungen.
