# SAM installieren (ohne Xcode)

Diese Anleitung richtet sich an Nutzer **ohne Programmierkenntnisse**. Du brauchst nur einen Browser und den Finder.

## Voraussetzungen

- Mac mit **macOS 15 (Sequoia)** oder neuer
- Internetverbindung (nur zum Download der App)

## Installation in 3 Schritten

### Schritt 1: App herunterladen

1. Öffne die GitHub-Seite von SAM.
2. Klicke rechts auf **Releases** (oder den Link „Latest release").
3. Lade die Datei **`SAM.zip`** der neuesten Version herunter (z. B. `v1.0.0`).

### Schritt 2: App installieren

1. Öffne die heruntergeladene ZIP-Datei (Doppelklick).
2. Ziehe **`SAM.app`** in den Ordner **Programme** (Finder → Programme, oder `/Applications`).

> **Tipp:** SAM sollte in **Programme** liegen, damit „Beim Anmelden starten" und die Bedienungshilfen-Freigabe zuverlässig funktionieren.

### Schritt 3: App zum ersten Mal öffnen

macOS warnt beim ersten Start bei Apps, die nicht vom App Store kommen. Das ist normal.

**So umgehst du die Warnung:**

1. Gehe zu **Programme**.
2. **Rechtsklick** (oder Ctrl+Klick) auf **SAM**.
3. Wähle **Öffnen** (nicht Doppelklick).
4. Im Dialog auf **Öffnen** klicken.

Diesen Schritt musst du nur **einmal** machen. Danach startet SAM wie jede andere App.

**Alternative (falls nötig):** Systemeinstellungen → Datenschutz & Sicherheit → unten „Trotzdem öffnen" bei SAM.

## Erster Start: Berechtigungen

SAM führt dich durch ein kurzes Onboarding. Erlaube nacheinander:

| Berechtigung | Wofür |
|--------------|-------|
| **Mikrofon** | Sprache aufnehmen |
| **Spracherkennung** | Sprache in Text umwandeln (läuft lokal auf deinem Mac) |
| **Bedienungshilfen** | Globaler Hotkey und Texteinfügen in andere Apps |

Falls eine Freigabe fehlt:

- **Mikrofon / Spracherkennung:** Systemeinstellungen → Datenschutz & Sicherheit → Mikrofon bzw. Spracherkennung → SAM aktivieren
- **Bedienungshilfen:** Systemeinstellungen → Datenschutz & Sicherheit → Bedienungshilfen → SAM aktivieren

## Sofort loslegen (ohne API-Key)

SAM startet im **Diktat-Modus**. Damit kannst du **ohne API-Key** sofort testen:

1. Öffne eine App mit Textfeld (Notizen, Mail, …).
2. Halte **fn + ⌘** gedrückt (Fallback: **rechte ⌘**).
3. Sprich deinen Text.
4. Lasse die Tasten los → der Text wird eingefügt.

**Modus wechseln:** **fn + ⌥** tippen (Fallback: **rechte ⌥**) rotiert durch Diktat, KI und Chat.

## Einstellungen

Klicke auf das **SAM-Symbol** in der Menüleiste. Das Panel hat vier Tabs:

| Tab | Wofür |
|-----|-------|
| **Start** | Autostart, aktiver Modus, Tastenkürzel, Berechtigungen |
| **Sprache** | Spracherkennungs-Engine und Transkriptionssprache |
| **KI** | Anbieter, Modell und API-Key |
| **Namen** | Eigennamen für Personalisierung |

## KI- und Chat-Modus einrichten (optional)

Für Antworten von Claude, OpenAI oder Gemini:

1. Klicke auf das **SAM-Symbol** in der Menüleiste.
2. Wechsle zum Tab **KI**.
3. Wähle einen **Anbieter** und trage deinen **API-Key** ein.
4. Klicke **Schlüssel testen**.

API-Keys erhältst du bei den Anbietern:

- Claude: [console.anthropic.com](https://console.anthropic.com/settings/keys)
- OpenAI: [platform.openai.com](https://platform.openai.com/api-keys)
- Gemini: [aistudio.google.com](https://aistudio.google.com/app/apikey)

**Chat-Modus:** Mit **fn + ⌥** bis zum Chat-Modus wechseln, dann **fn + ⌘** zum Sprechen oder im Chat-Fenster tippen.

## Eigennamen anpassen (optional)

Unter Tab **Namen** kannst du beliebige Einträge mit Bezeichnung und Wert anlegen:

- **Assistentenname** – Name in Chat- und Antwort-Fenstern (Standard: SAM)
- **Dein Name** – wie die KI dich anspricht
- Weitere z. B. **Firmenname**, **Aussprache**, **Projektname**

Vorschläge erscheinen als Chips – ein Klick legt einen neuen Eintrag an. Beide Felder (Bezeichnung und Wert) müssen ausgefüllt sein, damit die KI den Eintrag nutzt.

## Hilfe

Weitere Details, Tastenkürzel und Fehlerbehebung: [README.md](../README.md)
