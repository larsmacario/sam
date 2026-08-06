# SAM installieren (ohne Xcode)

Diese Anleitung richtet sich an Nutzer **ohne Programmierkenntnisse**. Du brauchst nur einen Browser und den Finder – **kein Xcode**, **keinen Apple-Developer-Account** und **keinen Account beim SAM-Entwickler**.

## Was du brauchst – und was nicht

| Brauchst du | Brauchst du nicht |
|---|---|
| Mac mit **macOS 15 (Sequoia)** oder neuer | Xcode |
| Internet (nur zum Download) | Apple Developer Account |
| Optional: API-Key für KI-Modus | API-Key für Diktat (funktioniert ohne) |

## Installation in 3 Schritten

### Schritt 1: App herunterladen

1. Öffne die **SAM-Website** (Link im GitHub-Repo unter „About" → Website).
2. Klicke **„SAM für macOS herunterladen"**.
3. Du erhältst **`SAM.dmg`**.

> **Alternative:** [GitHub Releases](https://github.com/larsmacario/sam/releases) – DMG-Mirror.

### Schritt 2: App installieren

1. Doppelklick auf **`SAM.dmg`**.
2. Ziehe **`SAM.app`** auf den Ordner **Programme**.

> **Tipp:** SAM sollte in **Programme** liegen, damit „Beim Anmelden starten" und die Bedienungshilfen-Freigabe zuverlässig funktionieren.

### Schritt 3: App zum ersten Mal öffnen

SAM kommt nicht aus dem Mac App Store. macOS warnt deshalb beim ersten Start – das ist **normal**.

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
|---|---|
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

**Modus wechseln:** **fn + ⌥** tippen (Fallback: **rechte ⌥**) wechselt zwischen **Diktat** und **KI**.

## Einstellungen

Klicke auf das **SAM-Symbol** in der Menüleiste. Das Panel hat vier Tabs:

| Tab | Wofür |
|---|---|
| **Start** | Autostart, aktiver Modus, Tastenkürzel, Berechtigungen |
| **Sprache** | Spracherkennungs-Engine und Transkriptionssprache |
| **KI** | Anbieter, Modell und API-Key |
| **Wörterbuch** | Eigennamen für Personalisierung |

## KI-Modus einrichten (optional)

Für KI-Aktionen am Cursor oder den Mehrturn-Chat brauchst du einen **eigenen API-Key** – das ist kein Developer-Account, sondern ein Zugang beim KI-Anbieter:

1. Klicke auf das **SAM-Symbol** in der Menüleiste.
2. Wechsle zum Tab **KI**.
3. Wähle einen **Anbieter** und trage deinen **API-Key** ein.
4. Klicke **Schlüssel testen**.

API-Keys erhältst du bei den Anbietern:

- Claude: [console.anthropic.com](https://console.anthropic.com/settings/keys)
- OpenAI: [platform.openai.com](https://platform.openai.com/api-keys)
- Gemini: [aistudio.google.com](https://aistudio.google.com/app/apikey)

**KI-Modus nutzen:**

- **Ein-Turn-Aktion:** Mit **fn + ⌥** zum KI-Modus wechseln, Text markieren oder Cursor setzen, dann **fn + ⌘** sprechen (z. B. „Übersetze ins Englische") – Ergebnis wird eingefügt.
- **Mehrturn-Chat:** Im KI-Modus **fn + ⌘** sprechen oder im Chat-Fenster tippen – SAM erkennt automatisch, ob eine Cursor-Aktion oder ein Dialog gemeint ist.

## Eigennamen anpassen (optional)

Unter Tab **Wörterbuch** kannst du beliebige Einträge mit Bezeichnung und Wert anlegen:

- **Assistentenname** – Name in Chat- und Antwort-Fenstern (Standard: SAM)
- **Dein Name** – wie die KI dich anspricht
- Weitere z. B. **Firmenname**, **Aussprache**, **Projektname**

Vorschläge erscheinen als Chips – ein Klick legt einen neuen Eintrag an. Beide Felder (Bezeichnung und Wert) müssen ausgefüllt sein, damit die KI den Eintrag nutzt.

## Hilfe

Weitere Details, Tastenkürzel und Fehlerbehebung: [README.md](../README.md)
