# Website auf Vercel deployen

Die Marketing-Site liegt in [`website/`](../website/).

## Voraussetzungen

- Vercel-Account
- Blob Store eingerichtet → siehe [BLOB_SETUP.md](BLOB_SETUP.md)

## Projekt verknüpfen

### Option A: Vercel Dashboard

1. **Add New Project** → GitHub-Repo **larsmacario/sam** importieren
2. **Root Directory:** `website`
3. Framework: **Next.js** (automatisch erkannt)
4. Environment Variables setzen (siehe BLOB_SETUP.md)
5. **Deploy**

### Option B: Vercel CLI

```bash
cd website
npm install
npx vercel link
npx vercel env pull .env.local
npx vercel --prod
```

## Custom Domain (optional)

1. Vercel → Projekt → **Settings → Domains**
2. Domain hinzufügen (z. B. `getsam.app`)
3. DNS-CNAME auf `cname.vercel-dns.com` setzen
4. `NEXT_PUBLIC_SITE_URL` auf die finale Domain setzen und neu deployen

## GitHub-Repo verknüpfen

Unter **Settings → General → Website** die Vercel-URL eintragen.

Siehe auch [GITHUB_SETUP.md](GITHUB_SETUP.md).

## Lokale Entwicklung

```bash
cd website
cp .env.example .env.local
# BLOB_READ_WRITE_TOKEN eintragen
npm install
npm run dev
```

Öffne http://localhost:3000

## Build prüfen

```bash
cd website && npm run build
```
