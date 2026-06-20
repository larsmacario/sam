# Projekt: SAM

## Ziel
Voice-First KI-Assistent für macOS (Menüleiste), Push-to-talk, Diktat-, KI-, Chat- und Meeting-Modus. Zielgruppe: Mac-Nutzer, die diktieren, KI-Aktionen am Cursor ausführen, im Mehrturn-Chat arbeiten oder Meetings aufnehmen und zusammenfassen wollen.

## Tech-Stack
- Swift 6, SwiftUI + AppKit (NSPopover, NSPanel)
- macOS 15+, XcodeGen, WhisperKit 1.0
- LLM: Claude, OpenAI, Gemini via `LLMProviding` (`processAction`, `sendChat`, `summarizeMeeting`)
- Persistenz: UserDefaults (Settings, API-Keys, Eigennamen); Meeting-JSON in App Support oder wählbarem Ordner

## Architektur
- `AppState` orchestriert Hotkey → STT → Diktat / KI / Chat / Meeting
- Vier `InputMode`: `.dictation`, `.ai`, `.chat`, `.meeting` (fn+⌥ rotiert)
- Meeting: `MeetingSessionController` (Audio-Pipeline, Chunk-Transkription, LLM-Summary) + `MeetingStore` (JSON)
- UI: Settings (4 Tabs inkl. Meetings), Overlay (Pille, Chat, Meeting-Pille/Start-Sheet/Summary)
- `LinkifiedText`: klickbare URLs im Chat

## Entscheidungen & Constraints
- Menüleisten-App (`LSUIElement`), kein Dock-Icon
- SAM in `/Applications` empfohlen (Autostart, Bedienungshilfen)
- Meeting: fn+⌘ Toggle Start/Stop im Meeting-Modus; Zustimmungsdialog beim ersten Start
- API-Keys in UserDefaults (Keychain-Migration geplant)
