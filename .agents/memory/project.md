# Projekt: SAM

## Ziel
Voice-First KI-Assistent für macOS (Menüleiste), Push-to-talk, Diktat/KI/Chat-Modi. Zielgruppe: Mac-Nutzer, die schnell diktieren oder KI-gestützt arbeiten wollen.

## Tech-Stack
- Swift 6, SwiftUI + AppKit (NSPopover, NSPanel)
- macOS 15+, XcodeGen, WhisperKit 1.0
- LLM: Claude, OpenAI, Gemini via `LLMProviding`
- Persistenz: UserDefaults (Settings, API-Keys, Eigennamen)

## Architektur
- `AppState` orchestriert Hotkey → STT → LLM/Output
- `SettingsStore` zentral für alle Einstellungen inkl. `ProperNameEntry`
- UI: Settings-Popover (4 Tabs), Overlay (Pille, Antwort, Chat-Sidepanel)
- Chat: `ChatSessionController` mit nicht-persistierter Historie

## Entscheidungen & Constraints
- Menüleisten-App (`LSUIElement`), kein Dock-Icon
- SAM in `/Applications` empfohlen (Autostart, Bedienungshilfen)
- Eigennamen per Label-Konvention: „Assistentenname“, „Dein Name“
- API-Keys in UserDefaults (Keychain-Migration geplant)
