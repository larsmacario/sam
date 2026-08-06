# Stripe & Lizenz-Setup (SAM)

Einmalzahlung mit 7-Tage-Trial über Stripe, signierter Lizenz-Key, Supabase als Backend.

## 1. Supabase

1. Neues Supabase-Projekt anlegen (oder bestehendes nutzen).
2. Migration ausführen: [`SAM Website/supabase/migrations/001_licenses.sql`](../SAM%20Website/supabase/migrations/001_licenses.sql)
3. `SUPABASE_URL` und `SUPABASE_SERVICE_ROLE_KEY` in Vercel setzen.

## 2. Ed25519-Schlüsselpaar

```bash
cd "SAM Website"
node scripts/generate-license-keys.mjs
```

- `LICENSE_PRIVATE_KEY` → nur Vercel (Secret)
- `NEXT_PUBLIC_LICENSE_PUBLIC_KEY` → Vercel + in [`Sam/Services/LicenseConfig.swift`](../Sam/Services/LicenseConfig.swift) (`publicKeyBase64`)

**Wichtig:** Website und App müssen denselben Public Key verwenden.

## 3. Stripe-Produkt

Im Stripe-Dashboard (Test-Modus zuerst):

1. **Produkt:** „SAM Lifetime“
2. **Preis:** 29 €, wiederkehrend monatlich (nur als Trial-Vehicle)
3. **Trial:** 7 Tage
4. Preis-ID als `STRIPE_PRICE_ID` in Vercel

Der Webhook setzt nach der ersten Abbuchung den Status auf `active` und **kündigt das Abo sofort** – es gibt keine weiteren Abbuchungen.

## 4. Vercel Environment Variables

Siehe [`SAM Website/.env.example`](../SAM%20Website/.env.example):

| Variable | Beschreibung |
|----------|--------------|
| `STRIPE_SECRET_KEY` | Stripe Secret Key |
| `STRIPE_WEBHOOK_SECRET` | Webhook-Signatur |
| `STRIPE_PRICE_ID` | Preis mit 7-Tage-Trial |
| `SUPABASE_URL` | Supabase Project URL |
| `SUPABASE_SERVICE_ROLE_KEY` | Service Role (nur Server) |
| `LICENSE_PRIVATE_KEY` | Ed25519 Private Key (32 Byte Base64) |
| `NEXT_PUBLIC_LICENSE_PUBLIC_KEY` | Ed25519 Public Key |
| `NEXT_PUBLIC_SITE_URL` | z. B. `https://deine-domain.de` |
| `RESEND_API_KEY` | Optional für E-Mail-Versand |

## 5. Stripe Webhook

Endpoint: `https://<domain>/api/stripe/webhook`

Events:

- `checkout.session.completed`
- `invoice.paid`
- `invoice.payment_failed`
- `customer.subscription.deleted`

Lokal testen:

```bash
stripe listen --forward-to localhost:3000/api/stripe/webhook
```

## 6. macOS App

- Lizenz-API: `LicenseConfig.apiBaseURL` (Standard: Production-URL, überschreibbar via Info.plist `SAMLicenseAPIBaseURL`)
- Kauf-Link: `#pricing` auf der Website
- Offline-Kulanz: 72 Stunden nach letztem erfolgreichen Online-Check

## 7. Ablauf (End-to-End)

1. Nutzer klickt „7 Tage kostenlos testen“ → Stripe Checkout (Karte hinterlegen)
2. Webhook `checkout.session.completed` → Lizenz `trialing`, Key per E-Mail + `/success`
3. Nutzer trägt Key in SAM ein → `/api/license/activate`
4. Nach 7 Tagen: Stripe bucht 29 € ab → Webhook `invoice.paid` → Status `active`, Abo gekündigt
5. Trial-Kündigung / Zahlungsfehler → Status `revoked`, App sperrt beim nächsten Online-Check

## 8. Test-Checkliste

- [ ] Checkout im Stripe-Testmodus
- [ ] Webhook liefert Key in Supabase
- [ ] Erfolgsseite zeigt Key
- [ ] App aktiviert Key offline + online
- [ ] Simulierte Kündigung im Trial → App gesperrt
- [ ] Erfolgreiche Zahlung → Status `active`, weiter nutzbar nach Abo-Ende
