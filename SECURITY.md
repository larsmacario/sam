# Sicherheit

## Lokale Daten (UserDefaults)

SAM speichert folgende Daten **lokal auf deinem Mac** in UserDefaults:

- **API-Keys** – nur für die von dir gewählten Dienste
- **Einstellungen** – Modus, STT-Engine, Anbieter, Modell-IDs
- **Eigennamen** – von dir eingetragene Bezeichnungen und Werte (Personalisierung)

API-Keys und Transkripte werden nicht an Dritte gesendet, außer an den von dir gewählten KI-Anbieter (Claude, OpenAI oder Gemini) bzw. an OpenAI bei Whisper online. Eigennamen fließen in die System-Prompts der KI-Anfragen ein.

Empfehlungen:

- Nutze API-Keys mit eingeschränkten Berechtigungen, wo der Anbieter das anbietet
- Teile deinen Mac-Account nicht mit anderen Personen, wenn Keys hinterlegt sind
- Lösche Keys in den SAM-Einstellungen, wenn du sie nicht mehr brauchst

## Berechtigungen

SAM benötigt Mikrofon, Spracherkennung und Bedienungshilfen. Audio wird für die Transkription verarbeitet. Bei der Apple-Engine und Whisper lokal bleibt die Verarbeitung auf dem Gerät. Whisper online, KI- und Chat-Modus senden Daten an Cloud-APIs.

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
