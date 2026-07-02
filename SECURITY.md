# Sicherheit

## Lokale Daten

SAM speichert folgende Daten **lokal auf deinem Mac**:

| Datentyp | Speicherort | Verschlüsselt |
|----------|-------------|---------------|
| **API-Keys** | macOS-Keychain | Ja (System-Keychain) |
| **Einstellungen** (Modus, STT, Anbieter, Modell) | UserDefaults | Nein |
| **Eigennamen** (Personalisierung) | UserDefaults | Nein |

API-Keys liegen **nicht** in UserDefaults und werden bei App-Start automatisch aus älteren UserDefaults-Einträgen in die Keychain migriert.

## Was geht wohin? (Datenflüsse)

| Modus / Engine | Audio | Transkript | Markierter Text | Eigennamen | Ziel |
|----------------|-------|------------|-----------------|------------|------|
| **Diktat** + Apple on-device | Lokal | Lokal | — | — | Keine Cloud |
| **Diktat** + Whisper lokal | Lokal | Lokal | — | — | Keine Cloud (Modell-Download von Hugging Face beim ersten Start) |
| **Diktat** + Whisper online | → OpenAI | → OpenAI | — | — | OpenAI Transcription API |
| **KI-Modus** (Ein-Turn) | Lokal (STT) | → LLM | → LLM | → LLM | Gewählter Anbieter (Claude, OpenAI, Gemini) |
| **KI-Modus** (Mehrturn-Chat) | Lokal (STT) | → LLM (gesamte Session) | — | → LLM | Gewählter Anbieter |

**Wichtig:** Im KI-Modus kann SAM über Bedienungshilfen **markierten Text** aus der aktiven App lesen und zusammen mit deiner Spracheingabe an den gewählten LLM senden. Eigennamen fließen in System-Prompts ein.

Chat-Historie liegt nur **im RAM** und wird bei jedem Request erneut an den LLM gesendet.

## Empfehlungen

- Nutze API-Keys mit eingeschränkten Berechtigungen, wo der Anbieter das anbietet
- Teile deinen Mac-Account nicht mit anderen Personen, wenn Keys hinterlegt sind
- Lösche Keys in den SAM-Einstellungen, wenn du sie nicht mehr brauchst
- Für maximale Privatsphäre: Diktat-Modus mit Apple on-device oder Whisper lokal (kein KI-Modus, kein Whisper online)

## Berechtigungen

SAM benötigt Mikrofon, Spracherkennung und Bedienungshilfen. Audio wird für die Transkription verarbeitet. Details zu den Datenflüssen siehe Tabelle oben.

## Meldung von Schwachstellen

Wenn du eine Sicherheitslücke findest, melde sie bitte **nicht** als öffentliches GitHub-Issue.

Stattdessen:

1. Öffne ein **privates** Security Advisory auf GitHub (Repository → Security → Advisories → Report a vulnerability), oder
2. Kontaktiere den Maintainer direkt über die auf dem GitHub-Profil hinterlegten Kanäle.

Wir bemühen uns um eine Antwort innerhalb von 7 Tagen.

## Unterstützte Versionen

| Version | Unterstützt |
|---------|-------------|
| 1.0.x   | Ja          |
