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

- **Description:** `Voice-First KI-Assistent für macOS – Open Source`
- **Website:** URL der Vercel-Landingpage (siehe [WEBSITE_DEPLOY.md](WEBSITE_DEPLOY.md))
- **Topics:** `macos`, `swift`, `swiftui`, `voice`, `dictation`, `whisper`, `claude`, `openai`, `gemini`, `menubar`, `assistant`

## GitHub Discussions

Unter **Settings → General → Features** → **Discussions** aktivieren.

Nutzer-Feedback und Support dort sammeln; Issues für Bugs behalten.

## Release

```bash
git tag v1.0.1
git push origin v1.0.1
```

Der Workflow [.github/workflows/release.yml](../.github/workflows/release.yml) baut **`SAM.dmg`**, lädt optional auf Vercel Blob hoch und veröffentlicht die DMG unter **Releases**.

Voraussetzung Blob-Upload: Secret `BLOB_READ_WRITE_TOKEN` – siehe [BLOB_SETUP.md](BLOB_SETUP.md).

## README-Links

Repository-URL: https://github.com/larsmacario/sam

Website-Deploy: [WEBSITE_DEPLOY.md](WEBSITE_DEPLOY.md)

Launch: [LAUNCH.md](LAUNCH.md)
