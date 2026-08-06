# SAM

**SAM** ist ein Voice-First-Assistent für macOS – ähnlich Wispr Flow. Halte eine Taste, sprich, lasse los: Deine Sprache wird transkribiert und je nach Modus direkt eingefügt oder von einer KI beantwortet.

SAM läuft als **Menüleisten-App** (kein Dock-Icon), startet optional beim Anmelden und bleibt immer im Hintergrund bereit.

---

## Für Nutzer: Installation ohne Entwickler-Konto

Du brauchst **kein Xcode**, **keinen Apple-Developer-Account** und **keine Programmierkenntnisse**. Ein normaler Mac mit macOS 15 oder neuer reicht.

| Brauchst du | Brauchst du nicht |
|---|---|
| Mac mit **macOS 15 (Sequoia)** oder neuer | Xcode |
| Download von der **SAM-Website** (DMG) | Apple Developer Account ($99/Jahr) |
| Einmalig **Rechtsklick → Öffnen** (siehe unten) | API-Key (nur für KI-Modus nötig) |
| Optional: eigener **API-Key** für KI-Funktionen | Account beim SAM-Entwickler |

> **Ausführliche Anleitung mit Screenshots-Hinweisen:** [docs/INSTALLATION.md](docs/INSTALLATION.md)

### Schritt 1: App herunterladen

1. Öffne die **SAM-Website** (Link unter „About" im GitHub-Repo, oder nach Deploy deine Vercel-URL – siehe [docs/WEBSITE_DEPLOY.md](docs/WEBSITE_DEPLOY.md))
2. Klicke **„SAM für macOS herunterladen"**
3. Du erhältst **`SAM.dmg`**

> **Alternative:** [GitHub Releases](https://github.com/larsmacario/sam/releases) – dort liegt dieselbe DMG als Mirror.

### Schritt 2: Installieren

1. Doppelklick auf **`SAM.dmg`** → Disk Image öffnet sich
2. Ziehe **`SAM.app`** auf den Ordner **Programme**

> SAM sollte in **Programme** liegen – das ist wichtig für Autostart und die Bedienungshilfen-Freigabe.

### Schritt 3: Zum ersten Mal öffnen

SAM kommt nicht aus dem Mac App Store. macOS zeigt deshalb beim ersten Start eine Sicherheitswarnung – das ist **normal** und kein Zeichen für Schadsoftware.

**So öffnest du SAM trotzdem:**

1. Gehe zu **Programme**
2. **Rechtsklick** (oder Ctrl+Klick) auf **SAM**
3. Wähle **Öffnen** – nicht Doppelklick
4. Im Dialog erneut auf **Öffnen** klicken

Diesen Schritt brauchst du nur **einmal**. Danach startet SAM wie jede andere App per Doppelklick.

**Falls kein Dialog erscheint:** Systemeinstellungen → Datenschutz & Sicherheit → unten bei SAM auf **Trotzdem öffnen** klicken.

### Schritt 4: Berechtigungen erteilen

SAM führt dich durch ein kurzes Onboarding. Erlaube nacheinander:

| Berechtigung | Wofür |
|---|---|
| **Mikrofon** | Sprache aufnehmen |
| **Spracherkennung** | Sprache in Text umwandeln (läuft lokal auf deinem Mac) |
| **Bedienungshilfen** | Globaler Hotkey und Texteinfügen in andere Apps |

Fehlt eine Freigabe: **Systemeinstellungen → Datenschutz & Sicherheit** → Mikrofon, Spracherkennung oder Bedienungshilfen → SAM aktivieren.

### Schritt 5: Sofort testen (ohne API-Key)

SAM startet im **Diktat-Modus**. Damit kannst du **ohne API-Key und ohne Cloud** sofort loslegen:

1. Öffne eine App mit Textfeld (Notizen, Mail, …)
2. Halte **fn + ⌘** gedrückt (Fallback: **rechte ⌘**)
3. Sprich deinen Text
4. Lasse die Tasten los → der Text wird eingefügt

**Modus wechseln:** **fn + ⌥** tippen (Fallback: **rechte ⌥**) wechselt zwischen **Diktat** und **KI**.

### Schritt 6: KI-Modus einrichten (optional)

Für KI-Aktionen (übersetzen, umformulieren, E-Mails schreiben) oder den Mehrturn-Chat brauchst du einen **eigenen API-Key** bei einem Anbieter deiner Wahl:

1. Klicke auf das **SAM-Symbol** in der Menüleiste
2. Wechsle zum Tab **KI**
3. Wähle einen **Anbieter** und trage deinen **API-Key** ein
4. Klicke **Schlüssel testen**

| Anbieter | API-Key erstellen |
|---|---|
| Claude (Anthropic) | [console.anthropic.com](https://console.anthropic.com/settings/keys) |
| OpenAI | [platform.openai.com](https://platform.openai.com/api-keys) |
| Gemini (Google) | [aistudio.google.com](https://aistudio.google.com/app/apikey) |

Das ist **kein Developer-Account** – nur ein kostenpflichtiger oder kostenloser Zugang beim jeweiligen KI-Anbieter. API-Kosten trägst du selbst.

---

## Funktionen

- **Push-to-talk:** fn + ⌘ halten, sprechen, loslassen
- **Zwei Modi:** Diktat und KI (fn + ⌥ zum Wechseln)
- **Drei STT-Engines:** Apple on-device (live), Whisper lokal (offline), Whisper online (OpenAI)
- **Drei KI-Anbieter:** Claude, OpenAI, Gemini – frei wählbar
- **Personalisierung:** Eigennamen (Assistent, Nutzer, Firma, Aussprache …) in den Einstellungen – fließen in KI-Prompts und UI

## Nutzung

### Tastenkürzel

| Aktion | Tastenkombination | Fallback |
|---|---|---|
| Aufnehmen (halten) | fn + ⌘ | rechte ⌘ |
| Modus wechseln (tippen) | fn + ⌥ | rechte ⌥ |

### Modi

- **Diktat:** Sprache → Text wird direkt ins aktive Feld eingefügt. Kein KI-Aufruf, kein API-Key.
- **KI:** Sprache oder Text → je nach Kontext:
  - **Ein-Turn-Aktion** am Cursor (Text markiert oder Cursor gesetzt): z. B. „Übersetze ins Englische" → Ergebnis wird eingefügt
  - **Mehrturn-Chat** im Chat-Fenster: Nachfragen per Textfeld oder fn+⌘

### Einstellungen öffnen

Klicke auf das **Wellenform-Symbol** in der Menüleiste. Das Einstellungs-Panel hat **vier Tabs**:

| Tab | Inhalt |
|---|---|
| **Start** | Status, Eingabemodus, Tastenkürzel, Berechtigungen, Autostart |
| **Sprache** | STT-Engine, Whisper-Modell, Transkriptionssprache |
| **KI** | Anbieter, Modell-ID, API-Key, Verbindungstest |
| **Wörterbuch** | Eigennamen-Liste (Label + Wert) für Personalisierung |

**Eigennamen:** Beliebig viele Einträge mit Bezeichnung und Wert – z. B. „Assistentenname", „Dein Name", „Firmenname", „Aussprache". Der Eintrag **Assistentenname** steuert die Anzeige in Chat- und Antwort-Fenstern; **Dein Name** wird in KI-Prompts verwendet.

### Spracherkennung (STT)

| Engine | Beschreibung |
|---|---|
| Apple on-device | Standard, Live-Text während des Sprechens |
| Whisper lokal | Offline via WhisperKit, Modell-Download beim ersten Start |
| Whisper online | OpenAI-Transkriptions-API, nutzt OpenAI-API-Key |

## Fehlerbehebung

| Problem | Lösung |
|---|---|
| „SAM kann nicht geöffnet werden" / Gatekeeper-Warnung | Rechtsklick → Öffnen (siehe Schritt 3 oben) |
| fn-Taste reagiert nicht | Fallback: **rechte ⌘** halten (Aufnahme), **rechte ⌥** tippen (Modus) |
| Hotkey / Einfügen funktioniert nicht | Bedienungshilfen-Freigabe prüfen; SAM in Programme legen |
| „Kein API-Key" im KI-Modus | API-Key unter Tab **KI** hinterlegen oder mit fn+⌥ in Diktat wechseln |
| Tab in Einstellungen reagiert nicht | App neu starten; SAM sollte in Programme liegen |
| Whisper lokal hängt | Erster Start lädt das Modell (~500 MB für „small") – warten |
| Autostart funktioniert nicht | SAM muss in Programme liegen |

## Bekannte Einschränkungen

- **API-Keys** werden in der macOS-Keychain gespeichert; **Eigennamen** in UserDefaults (nur lokal auf deinem Mac).
- **Keine Notarisierung** in v1 – einmalige Gatekeeper-Warnung beim ersten Öffnen (Rechtsklick → Öffnen). Maintainer: optionale Signierung siehe [docs/RELEASE_SIGNING.md](docs/RELEASE_SIGNING.md).
- **Streaming** von KI-Antworten ist nicht implementiert (Request/Response).
- **Modell-IDs** können sich ändern, wenn Anbieter ihre APIs aktualisieren – in den Einstellungen anpassbar.

---

## Für Entwickler: Installation aus Quellcode

| | Nutzer (Release) | Entwickler (Quellcode) |
|---|---|---|
| macOS | 15 (Sequoia) oder neuer | 15 oder neuer |
| Xcode | nicht nötig | 16+ (Swift 6) |
| API-Key | nur für KI-Modus | nur für KI-Modus |

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

### Projektstruktur

```
Sam/
├── App/          # Einstieg, AppDelegate, AppState
├── Core/         # Hotkey, Audio, STT, LLM-Clients, Chat, Output
├── Models/       # ProperNameEntry (Eigennamen)
├── UI/           # Settings (4 Tabs), Onboarding, Overlay, Design
├── Services/     # SettingsStore, LaunchAtLogin, Permissions
└── Resources/    # Info.plist, App-Icon
```

## Releases erstellen (Maintainer)

```bash
git tag v1.0.1
git push origin v1.0.1
```

GitHub Actions baut automatisch **`SAM.dmg`**, lädt sie optional auf **Vercel Blob** hoch (Website-Download) und hängt sie an das Release an. Details: [.github/workflows/release.yml](.github/workflows/release.yml).

- Blob-Setup: [docs/BLOB_SETUP.md](docs/BLOB_SETUP.md)
- Website deployen: [docs/WEBSITE_DEPLOY.md](docs/WEBSITE_DEPLOY.md)
- Launch-Checkliste: [docs/LAUNCH.md](docs/LAUNCH.md)

## Entwickler-Hinweise

- `.agents/` enthält Kontext für KI-Coding-Assistenten (optional)
- `AGENTS.md` / `CLAUDE.md` – Projekt-Anweisungen für Assistenten

## Lizenz

MIT – siehe [LICENSE](LICENSE).

SAM ist ein unabhängiges Open-Source-Projekt. Keine offizielle Partnerschaft mit Anthropic, OpenAI oder Google.

## Sicherheit

Schwachstellen bitte melden – siehe [SECURITY.md](SECURITY.md).
