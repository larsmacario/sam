# Vercel Blob einrichten

SAM-Downloads liegen auf **Vercel Blob**. Die Website liefert `/download` aus; CI lädt nach jedem Release die DMG hoch.

## 1. Blob Store anlegen

1. [Vercel Dashboard](https://vercel.com/dashboard) → dein **Website-Projekt** (Root: `website/`)
2. **Storage** → **Create Database / Store** → **Blob**
3. Store mit dem Website-Projekt verknüpfen
4. Unter **Settings → Environment Variables** erscheint automatisch **`BLOB_READ_WRITE_TOKEN`**

## 2. GitHub Secret (für Releases)

1. GitHub → Repository **sam** → **Settings → Secrets and variables → Actions**
2. **New repository secret:**
   - Name: `BLOB_READ_WRITE_TOKEN`
   - Wert: dasselbe Token aus dem Vercel Blob Store

Ohne dieses Secret baut CI weiterhin `SAM.dmg`, lädt sie aber **nicht** auf Blob hoch.

## 3. Website-Env auf Vercel

Im Vercel-Projekt (Website):

| Variable | Wert |
|---|---|
| `BLOB_READ_WRITE_TOKEN` | Token aus Blob Store |
| `NEXT_PUBLIC_SITE_URL` | Öffentliche URL (z. B. `https://deine-domain.app`) |

Lokal: `website/.env.local` aus `website/.env.example` kopieren.

## 4. Manifest

Nach jedem Release liegen auf Blob:

- `releases/SAM.dmg` – aktuelle App
- `releases/latest.json` – Metadaten:

```json
{
  "version": "1.0.1",
  "releasedAt": "2026-07-20T…",
  "downloadPath": "releases/SAM.dmg",
  "url": "https://….public.blob.vercel-storage.com/releases/SAM.dmg"
}
```

Die Website liest `latest.json` für Versions-Badge und `/download`.

## 5. Manueller Test-Upload

```bash
cd website && npm install
export BLOB_READ_WRITE_TOKEN="…"
node scripts/upload-release-to-blob.mjs /pfad/zu/SAM.dmg 1.0.1
```

## Referenzen

- [Vercel Blob Docs](https://vercel.com/docs/storage/vercel-blob)
- Upload-Skript: [`website/scripts/upload-release-to-blob.mjs`](../website/scripts/upload-release-to-blob.mjs)
