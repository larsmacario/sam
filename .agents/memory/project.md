# Projekt: SAM

## Ziel
Voice-First KI-Assistent für macOS (Menüleiste), Push-to-talk, Diktat- und KI-Modus. Zielgruppe: Mac-Nutzer, die diktieren, KI-Aktionen am Cursor ausführen oder im Mehrturn-Dialog arbeiten wollen.

## Tech-Stack
- Swift 6, SwiftUI + AppKit (NSPopover, NSPanel)
- macOS 15+, XcodeGen, WhisperKit 1.0
- LLM: Claude, OpenAI, Gemini via `LLMProviding` (`processAction`, `sendChat`)
- Persistenz: UserDefaults (Settings, Eigennamen), Keychain (API-Keys)

## Architektur
- `AppState` orchestriert Hotkey → STT → Diktat / KI (mit intelligentem Routing)
- Zwei `InputMode`: `.dictation`, `.ai` (fn+⌥ rotiert)
- KI-Modus: Ein-Turn (`processAction`) oder Mehrturn (`sendChat` via `ChatSessionController`)
- Meeting-Code im Repo, aktuell per Build-Exclude deaktiviert
- UI: Settings (4 Tabs), Overlay (Pille, Chat-Panel, Antwort)
- `LinkifiedText`: klickbare URLs im Chat

## Entscheidungen & Constraints
- Menüleisten-App (`LSUIElement`), kein Dock-Icon
- SAM in `/Applications` empfohlen (Autostart, Bedienungshilfen)
- API-Keys in UserDefaults (Keychain-Migration geplant)
