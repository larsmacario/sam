# Aktueller Stand

## UI-Redesign (SAM-Designbundle)
- Glassmorphism-Look aus Claude-Design umgesetzt (`Sam/UI/SamDesign.swift` Tokens).
- Pille = **Dynamic Island** (dunkles Glas, Icon-Badge, Live-Waveform via TimelineView, Timer). Modus-Farben: Diktat #0A84FF, KI #BF5AF2.
- Settings = Glas-Popover mit Tabs „Anpassen"/„Zugang" (`SamControls.swift`: SecLabel/SamGroup/SamRow/Keycap/PillTabs), gefüllt mit echten SAM-Optionen.
- Sprechblasen-Spitze weggelassen (MenuBarExtra-.window-Limit; AppKit-NSPopover bei Bedarf).
- Waveform ist animiert/synthetisch (noch kein echter Mikrofon-Pegel).

## Steuerung (neu)
- **fn + ⌘ halten** = aufnehmen (Push-to-talk) im aktiven Modus.
- **fn + ⌥ tippen** = Eingabemodus wechseln (Diktat ↔ KI), klar sichtbar in der Pille.
- **Diktat-Modus**: Sprache → Text direkt einfügen, kein KI-Aufruf, kein API-Key.
- **KI-Modus**: Sprache → KI → Antwort (einfügen vs. Fenster via Tool-Use).
- Alte fn/rechte-Cmd-Auswahl entfernt; `InputMode` in `Sam/Core/InputMode.swift`.

## Spracherkennung (STT) – neu
- 3 wählbare Engines (`STTEngine`): Apple on-device (Default, Live-Text), Whisper lokal (WhisperKit), Whisper online (OpenAI).
- Abstraktion `Transcribing` + `TranscriberFactory`; Audio wird auf 16 kHz mono umgerechnet (`AudioSampleCollector`), WAV-Encoder für die OpenAI-API.
- Whisper = Batch (kein Live-Text); Pille zeigt „Transkribiere…".
- WhisperKit v1.0.0 als SPM-Dependency (`argmaxinc/WhisperKit`, Produkt `WhisperKit`); Modell-Download zur Laufzeit (small Default).
- Whisper online: 3 gültige OpenAI-Modelle (`gpt-4o-mini-transcribe` Default, `gpt-4o-transcribe`, `whisper-1` Legacy). Diarize/Snapshot-Modelle bewusst nicht im Picker.

## Letzte Änderungen
- Whisper-Online-Modell-Check: API-Stand verifiziert, Picker-Beschriftungen mit Preis/Legacy-Hinweisen aktualisiert.
- Multi-Provider-Refactor umgesetzt: SAM unterstützt **Claude, OpenAI, Gemini**.
- Neue Abstraktion `LLMProviding` + `LLM.swift` (Provider/Modelle/Tools/Factory); `ClaudeClient`, `OpenAIClient`, `GeminiClient` implementieren sie.
- Keychain + Settings auf einen API-Key-Slot **pro Provider** umgestellt; UI (Settings/Onboarding) mit Provider-Auswahl.
- Swift-6-Concurrency-Fehler behoben (NSLock.withLock, kAXTrustedCheckOptionPrompt, AppDelegate-Capture, CFMachPort-Box).
- **Clean Build grün: 0 Errors, 0 Warnings.** `SAM.app` wird erzeugt (LSUIElement=true → kein Dock, immer im Vordergrund).

## Fokus
- Manuelle Hardware-Verifikation durch Nutzer steht aus (Signing, Berechtigungen, echter Sprach-Loop).

## Nächste Schritte
1. In Xcode öffnen, Signing-Team wählen, Build & Run.
2. Berechtigungen erteilen (Mikrofon, Spracherkennung, Accessibility).
3. In Einstellungen Provider wählen + API-Key hinterlegen + „Verbindung testen".
4. fn-Hotkey halten, sprechen, Golden Path testen; bei fn-Problemen Fallback rechte Cmd.

## Offene Punkte
- fn-Hotkey auf Hardware verifizieren (Hauptrisiko; Fallback rechte Cmd vorhanden).
- Modell-IDs (v.a. Claude) sind angenommene Stände – ggf. an aktuelle API anpassen.
- Whisper-Online-Diktat mit OpenAI-Key manuell pro Modell testen.
- Streaming der Antworten nicht implementiert (v1 nutzt einfache Request/Response).
- OAuth (Subscription) weiterhin offen, ToS-Vorbehalt.
