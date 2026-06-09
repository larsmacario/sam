## Sprache
Antworte **immer auf Deutsch**, auch bei technischen Themen. Wechsle die Sprache nie selbstständig, auch wenn Code, Logs oder Fehlermeldungen auf Englisch sind.

## Agent-Setup prüfen
Zu Beginn jeder neuen Aufgabe prüfe, ob diese Dateien im Projekt existieren:
- `.agents/AGENTS.md` – Projekt-Anweisungen für Codex
- `.agents/memory/project.md` – Projekt-Übersicht (selten Updates)
- `.agents/memory/current.md` – aktueller Stand (oft Updates)

**Wenn vorhanden:** Lies sie. Sie sind deine einzige Verbindung zu früheren Sitzungen.

**Wenn etwas fehlt** und die Aufgabe nicht trivial ist, frage:
> „Folgende Agent-Dateien fehlen: [Liste]. Soll ich sie anlegen?"

Bei Zustimmung: Lege die fehlenden Dateien mit den Templates unten an. Fülle sie soweit möglich aus dem vorhandenen Projekt-Kontext (z. B. `package.json`, `README.md`, Code-Struktur). Frage nur nach, was du nicht selbst herausfinden kannst. **Halte alle Einträge knapp – max. 3–4 Bulletpoints pro Sektion.**

## Trigger: `update memory`
1. Lies die Memory-Dateien.
2. Aktualisiere **immer** `current.md` (letzte Änderungen, Fokus, nächste Schritte, offene Punkte).
3. Aktualisiere `project.md` **nur**, wenn sich Architektur, Tech-Stack oder Grundsatzentscheidungen geändert haben.
4. `AGENTS.md` **nie** automatisch ändern – das ist eine bewusste Nutzer-Entscheidung.
5. Fasse in 2–3 Sätzen zusammen, was geändert wurde.

## Trigger: `/plan` oder „Planner Mode"
1. Analysiere den bestehenden Code im Umfang der geplanten Änderung.
2. Stelle **4–6 gezielte Klärungsfragen** auf Basis deiner Analyse.
3. Warte auf die Antworten – beginne nicht vorher mit dem Plan.
4. Erstelle einen Plan in nummerierten Phasen und bitte um Freigabe.
5. Setze nach Freigabe Schritt für Schritt um.
6. Nach jeder Phase: nenne, was abgeschlossen wurde, was als Nächstes ansteht und welche Phasen danach noch folgen.

### Plan-Modus – strikte Output-Regeln (Token sparen)
- **Kein Code, keine Code-Snippets, keine Pseudocode-Blöcke** im Plan. Auch keine Backtick-Blöcke mit Beispiel-Implementierungen.
- **Keine Flowcharts, keine Mermaid-Diagramme, keine ASCII-Diagramme.**
- **Keine ausführlichen Datei-Listings oder Datei-Inhalte.** Dateipfade dürfen genannt werden (inline mit Backticks), aber ohne den Inhalt zu zitieren.
- **Keine fertigen Migrations-, SQL- oder Config-Beispiele** – nur beschreiben, was sich ändert.
- Beschreibe Änderungen **in kurzen Stichpunkten in Prosa**: was geändert wird, wo (Pfad), warum. Maximal 1–2 Zeilen pro Punkt.
- Wenn ein Detail ohne Code nicht erklärbar ist: in 1 Satz beschreiben und auf die Umsetzungsphase verschieben.

---

## Templates

### Template `.agents/AGENTS.md` (minimal, aber alles Wichtige)

~~~markdown
# Projekt: [Name]

## Sprache
Antworte auf Deutsch.

## Was das ist
[1–2 Sätze: Was macht dieses Projekt? Wer nutzt es?]

## Wichtige Befehle
- Dev:   `[befehl]`
- Build: `[befehl]`
- Test:  `[befehl]`

## Konventionen
[Nur was nicht aus dem Code offensichtlich ist. Beispiele:
- Variablennamen Englisch, Kommentare Deutsch
- Tests liegen neben der Komponente, nicht zentral
- Keine direkten DB-Schreibzugriffe – immer über Service-Schicht]

## Memory
Lies zu Beginn jeder Session `.agents/memory/project.md` und `.agents/memory/current.md`.
Bei `update memory`: aktualisiere `current.md`, `project.md` nur bei Architektur-Änderungen.
~~~

### Template `.agents/memory/project.md` (selten Updates)

~~~markdown
# Projekt: [Name]

## Ziel
Was soll dieses Projekt erreichen? Wer ist die Zielgruppe?

## Tech-Stack
Sprachen, Frameworks, wichtige Bibliotheken und Tools.

## Architektur
Kurze Beschreibung der Struktur und der wichtigsten Konventionen.

## Entscheidungen & Constraints
Wichtige technische Festlegungen und ihre Begründung.
~~~

### Template `.agents/memory/current.md` (oft Updates)

~~~markdown
# Aktueller Stand

## Letzte Änderungen
Was wurde zuletzt umgesetzt?

## Fokus
Woran wird gerade gearbeitet?

## Nächste Schritte
Was kommt als Nächstes?

## Offene Punkte
Bekannte Probleme, Bugs, Unklarheiten.
~~~
