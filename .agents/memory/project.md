# Projekt: SAM

## Ziel
Voice-First-Assistent für macOS: Sprache transkribieren und je nach Modus direkt einfügen (Diktat) oder per KI bearbeiten/chatten (KI-Modus). Zielgruppe: Mac-Nutzer ohne Dev-Konto (Release via GitHub).

## Tech-Stack
- **App:** Swift 6, SwiftUI + AppKit, macOS 15+; STT (Apple Speech, WhisperKit); LLM (Claude, OpenAI, Gemini); Xcode + XcodeGen
- **Website** (`SAM Website/`): Next.js 15 App Router, Tailwind v4, `next/font` (Inter, Inter Tight, JetBrains Mono); Deployment Vercel + optional Blob für DMG

## Architektur
- **App:** Menüleisten-App, `AppState` orchestriert Hotkey → STT → Routing; KI-Chat als Sidepanel; Settings in UserDefaults + Keychain
- **Website:** Modulare Sections unter `app/components/`; cinematic Layer; Pricing mit Stripe Checkout (7-Tage-Trial, 29 € Lifetime); Lizenz-API (`/api/license/*`, `/api/stripe/webhook`)

## Entscheidungen & Constraints
- Hotkeys: fn+⌘ (Diktat), fn+⌥ (Moduswechsel); Installationsziel `/Applications/SAM.app`
- Website: Stripe-Einmalzahlung + signierter Lizenz-Key (Ed25519, Supabase); App-Gate ohne gültige Lizenz
