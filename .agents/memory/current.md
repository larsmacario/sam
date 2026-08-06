# Aktueller Stand

## Letzte Änderungen
- **Hero Headline:** Zeile 1 `Sprich.` · Zeile 2 statisches `SAM` + blauer Typewriter-Loop (`tippt` / `übersetzt` / `antwortet`), kein Pill-Hintergrund, kein `_`
- **Hero Copy:** Subline ohne „7 Tage kostenlos testen…“; Checkout-Hinweis unter CTAs entfernt
- **Stripe + Lizenz-System:** 7-Tage-Trial + 29 € Einmalzahlung; Checkout, Webhook, Ed25519-Keys, Supabase, App-Paywall
- **Design:** Midnight-Look unverändert; shadcn-Init bewusst zurückgedreht (nur Hero-Effekt, kein Design-Reset)

## Fokus
- Website deployen + Hero visuell final abnehmen
- Stripe/Supabase/Vercel Env (siehe `.env.example`, `docs/STRIPE_LICENSE_SETUP.md`)
- Ed25519-Keys in Vercel + `LicenseConfig.swift` synchron

## Nächste Schritte
1. Vercel Env setzen, Stripe Test-Checkout E2E
2. `NEXT_PUBLIC_SITE_URL` + optional `SAMLicenseAPIBaseURL` für Production
3. Optional: Footer an Midnight-Pattern angleichen
4. Demo-Video für Website aufnehmen

## Offene Punkte
- Resend optional – ohne Key nur Erfolgsseite
- Apple-Notarisierung optional ($99/Jahr)
- Footer noch nicht im gleichen Feinschliff wie Sections 01–08
