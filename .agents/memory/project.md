# Projekt: SAM

## Ziel
Persönliche Voice-KI für macOS (ähnlich Wispr Flow). fn-Taste halten, sprechen, loslassen → lokale Transkription → Claude → Antwort wird je nach Aufgabe ins aktive Feld eingefügt oder im schwebenden Fenster gezeigt. Zielnutzer: Einzelnutzer, persönlicher Gebrauch.

## Tech-Stack
- Swift / SwiftUI (native macOS, `MenuBarExtra`)
- Apple Speech (`SFSpeechRecognizer`, on-device) für STT
- `AVAudioEngine` für Audioaufnahme
- Anthropic Messages API (Claude) – API-Key in v1
- `CGEventTap` für globalen Hotkey (fn+cmd aufnehmen, fn+option Modus wechseln)
- STT: Apple `SFSpeechRecognizer` (Default), WhisperKit (lokal), OpenAI-API (online)
- WhisperKit v1.0.0 als SPM-Dependency (`argmaxinc/WhisperKit`, Produkt `WhisperKit`)
- Multi-LLM: Claude, OpenAI, Gemini hinter `LLMProviding`
- Accessibility API für Kontext + Text-Einfügen
- Keychain für API-Key-Speicherung (pro Provider)

## Architektur
- Menüleisten-App, always-on-top `NSPanel` (Pille während Aufnahme + Antwort-Fenster)
- Komponenten: HotkeyManager, AudioRecorder, SpeechTranscriber, ClaudeClient, ContextProvider, OutputRouter, OverlayWindow, SettingsStore, MenuBarApp
- Intent-Routing über Claude Tool-Use: `insert_text()` (einfügen) vs. `show_answer()` (Fenster)
- Auth hinter Protokoll gekapselt → OAuth später ohne Umbau ergänzbar

## Entscheidungen & Constraints
- Push-to-talk: fn-Taste halten (Fallback rechte cmd / konfigurierbar). fn global abzufangen ist das Hauptrisiko – früher technischer Spike geplant.
- v1 nur API-Key (offiziell, stabil); OAuth/Subscription später mit ToS-Vorbehalt (nicht offiziell für Drittanbieter erlaubt).
- Einfügen via Clipboard + simuliertes Cmd+V, alter Clipboard-Inhalt wird danach wiederhergestellt.
- Berechtigungen beim Erststart: Mikrofon, Accessibility (Hotkey + Einfügen), Spracherkennung.
