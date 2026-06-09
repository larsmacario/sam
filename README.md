# SAM

**SAM** ist ein Voice-First-Assistent für macOS – ähnlich Wispr Flow. Halte eine Taste, sprich, lasse los: Deine Sprache wird transkribiert und je nach Modus direkt eingefügt oder von einer KI beantwortet.

SAM läuft als **Menüleisten-App** (kein Dock-Icon), startet optional beim Anmelden und bleibt immer im Hintergrund bereit.

## Funktionen

- **Push-to-talk:** fn + ⌘ halten, sprechen, loslassen
- **Zwei Modi:** Diktat (Sprache → Text) und KI (Sprache → Antwort)
- **Drei STT-Engines:** Apple on-device (live), Whisper lokal (offline), Whisper online (OpenAI)
- **Drei KI-Anbieter:** Claude, OpenAI, Gemini – frei wählbar
- **Intent-Routing:** KI entscheidet, ob Text eingefügt oder in einem Fenster gezeigt wird

## Schnellstart (ohne Xcode)

> Ausführliche Schritt-für-Schritt-Anleitung: [docs/INSTALLATION.md](docs/INSTALLATION.md)

1. Unter **[Releases](https://github.com/larsmacario/sam/releases)** die neueste `SAM.zip` herunterladen
2. `SAM.app` nach **Programme** ziehen
3. **Rechtsklick → Öffnen** (einmalig wegen macOS Gatekeeper)
4. Onboarding durchlaufen – **Diktat-Modus** sofort ohne API-Key testen

### Gatekeeper-Hinweis

SAM ist nicht notarisiert (kein App-Store-Build). Beim ersten Start zeigt macOS eine Sicherheitswarnung. **Rechtsklick → Öffnen** umgeht das einmalig. Danach startet SAM normal per Doppelklick.

## Voraussetzungen

| | Nutzer (Release) | Entwickler (Quellcode) |
|---|---|---|
| macOS | 15 (Sequoia) oder neuer | 15 oder neuer |
| Xcode | nicht nötig | 16+ (Swift 6) |
| API-Key | nur für KI-Modus | nur für KI-Modus |

**Diktat-Modus** funktioniert ohne API-Key und ohne Cloud – nur lokale Spracherkennung.

## Nutzung

### Tastenkürzel

| Aktion | Tastenkombination | Fallback |
|--------|-------------------|----------|
| Aufnehmen (halten) | fn + ⌘ | rechte ⌘ |
| Modus wechseln (tippen) | fn + ⌥ | rechte ⌥ |

### Modi

- **Diktat:** Sprache → Text wird direkt ins aktive Feld eingefügt. Kein KI-Aufruf, kein API-Key.
- **KI:** Sprache → Transkription → KI → Antwort wird eingefügt oder in einem schwebenden Fenster gezeigt.

### Einstellungen öffnen

Klicke auf das **Wellenform-Symbol** in der Menüleiste. Über das **Zahnrad** erreichst du Provider, Modelle und API-Keys.

### Spracherkennung (STT)

| Engine | Beschreibung |
|--------|--------------|
| Apple on-device | Standard, Live-Text während des Sprechens |
| Whisper lokal | Offline via WhisperKit, Modell-Download beim ersten Start |
| Whisper online | OpenAI-Transkriptions-API, nutzt OpenAI-API-Key |

### KI-Anbieter

| Anbieter | API-Key erstellen |
|----------|-------------------|
| Claude (Anthropic) | [console.anthropic.com](https://console.anthropic.com/settings/keys) |
| OpenAI | [platform.openai.com](https://platform.openai.com/api-keys) |
| Gemini (Google) | [aistudio.google.com](https://aistudio.google.com/app/apikey) |

## Erststart & Berechtigungen

SAM benötigt drei Berechtigungen (Onboarding führt dich durch):

1. **Mikrofon** – Sprachaufnahme
2. **Spracherkennung** – lokale Transkription
3. **Bedienungshilfen** – globaler Hotkey und Texteinfügen

Falls eine Freigabe fehlt, öffne **Systemeinstellungen → Datenschutz & Sicherheit** und aktiviere SAM unter Mikrofon, Spracherkennung und Bedienungshilfen.

## Installation aus Quellcode (Entwickler)

```bash
git clone https://github.com/larsmacario/sam.git
cd SAM
open Sam.xcodeproj
```

1. In Xcode unter **Signing & Capabilities** dein Apple-ID-Team wählen (Bundle ID bei Bedarf anpassen)
2. **Product → Run** (⌘R)
3. Optional nach dem Build:

```bash
BUILT_PRODUCTS_DIR="$(xcodebuild -scheme Sam -configuration Debug -showBuildSettings | awk -F' = ' '/BUILT_PRODUCTS_DIR/{print $2; exit}')"
BUILT_PRODUCTS_DIR="$BUILT_PRODUCTS_DIR" ./Scripts/install-to-applications.sh
```

Das kopiert `SAM.app` nach `/Applications` – empfohlen für Autostart und stabile Bedienungshilfen-Freigaben.

### Projekt mit XcodeGen regenerieren

Falls du `project.yml` änderst:

```bash
xcodegen generate
```

### Abhängigkeiten

- [WhisperKit](https://github.com/argmaxinc/WhisperKit) 1.0.0 (Swift Package Manager, automatisch via Xcode)

## Fehlerbehebung

| Problem | Lösung |
|---------|--------|
| fn-Taste reagiert nicht | Fallback: **rechte ⌘** halten (Aufnahme), **rechte ⌥** tippen (Modus) |
| Hotkey / Einfügen funktioniert nicht | Bedienungshilfen-Freigabe prüfen; SAM in `/Applications` legen |
| „Kein API-Key" im KI-Modus | API-Key in Einstellungen hinterlegen oder mit fn+⌥ in Diktat wechseln |
| Whisper lokal hängt | Erster Start lädt das Modell (~500 MB für „small") – warten |
| Autostart funktioniert nicht | SAM muss in `/Applications` liegen |
| Gatekeeper blockiert App | Rechtsklick → Öffnen (siehe Schnellstart) |

## Bekannte Einschränkungen

- **API-Keys** werden lokal in UserDefaults gespeichert (nur auf deinem Mac, nicht im Keychain). Keychain-Speicherung ist für eine spätere Version geplant.
- **Keine Notarisierung** in v1 – einmalige Gatekeeper-Warnung beim ersten Öffnen.
- **Streaming** von KI-Antworten ist nicht implementiert (Request/Response).
- **Modell-IDs** können sich ändern, wenn Anbieter ihre APIs aktualisieren – in den Einstellungen anpassbar.

## Projektstruktur

```
Sam/
├── App/          # Einstieg, AppDelegate, AppState
├── Core/         # Hotkey, Audio, STT, LLM-Clients, Output
├── UI/           # Settings, Onboarding, Overlay, Design
├── Services/     # SettingsStore, LaunchAtLogin, Permissions
└── Resources/    # Info.plist, App-Icon
```

## Releases erstellen (Maintainer)

```bash
git tag v1.0.0
git push origin v1.0.0
```

GitHub Actions baut automatisch `SAM.zip` und hängt sie an das Release an. Details: [.github/workflows/release.yml](.github/workflows/release.yml).

Nach dem ersten Push: Repo-Beschreibung und Topics setzen – siehe [docs/GITHUB_SETUP.md](docs/GITHUB_SETUP.md).

## Entwickler-Hinweise

- `.agents/` enthält Kontext für KI-Coding-Assistenten (optional)
- `AGENTS.md` / `CLAUDE.md` – Projekt-Anweisungen für Assistenten

## Lizenz

MIT – siehe [LICENSE](LICENSE).

SAM ist ein unabhängiges Open-Source-Projekt. Keine offizielle Partnerschaft mit Anthropic, OpenAI oder Google. API-Kosten trägt der Nutzer selbst.

## Sicherheit

Schwachstellen bitte melden – siehe [SECURITY.md](SECURITY.md).
