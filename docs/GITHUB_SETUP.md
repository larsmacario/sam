# GitHub-Repository einrichten

Checkliste nach dem ersten Push des Repositories.

## Repository erstellen

1. Neues Repository auf GitHub anlegen (öffentlich)
2. Lokal pushen:

```bash
git remote add origin git@github.com:larsmacario/sam.git
git add .
git commit -m "Initial public release"
git push -u origin main
```

## Metadaten

Unter **Settings → General** oder auf der Repo-Startseite:

- **Description:** `Voice-First KI-Assistent für macOS`
- **Website:** Link zur README oder Releases-Seite
- **Topics:** `macos`, `swift`, `swiftui`, `voice`, `dictation`, `whisper`, `claude`, `openai`, `gemini`

## Erstes Release

```bash
git tag v1.0.0
git push origin v1.0.0
```

Der Workflow [.github/workflows/release.yml](../.github/workflows/release.yml) baut `SAM.zip` und veröffentlicht sie automatisch unter **Releases**.

Prüfe nach dem Workflow-Lauf, ob das Release die ZIP-Datei enthält.

## README-Links anpassen

Repository-URL: https://github.com/larsmacario/sam
