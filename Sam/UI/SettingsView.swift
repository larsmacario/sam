import SwiftUI

struct SettingsView: View {
    @ObservedObject var settings = SettingsStore.shared
    @ObservedObject var appState = AppState.shared
    var launchAtLoginService: LaunchAtLoginService
    var onShowOnboarding: () -> Void
    @State private var tab: SettingsTab = .hauptseite
    @State private var apiKeyInput = ""
    @State private var modelIDInput = ""
    @State private var isTesting = false
    @State private var testMessage: String?
    @State private var testIsError = false
    @State private var saveMessage: String?

    private var provider: LLMProvider { settings.selectedProvider }

    var body: some View {
        VStack(spacing: 0) {
            header
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    if tab == .hauptseite { hauptseiteTab } else { einstellungenTab }
                }
                .padding(.horizontal, 18)
                .padding(.top, 12)
                .padding(.bottom, 6)
            }
            .frame(maxHeight: .infinity)
            footer
        }
        .frame(width: SamDesign.panelWidth, height: SamDesign.panelHeight)
        .glassPanel()
        .tint(SamDesign.accent)
        .onAppear {
            tab = .hauptseite
            launchAtLoginService.refresh()
        }
        .onChange(of: tab) { _, newTab in
            if newTab == .einstellungen { syncEinstellungenFields() }
        }
        .onChange(of: modelIDInput) { _, newValue in
            settings.setModelID(newValue, for: provider)
        }
    }

    // MARK: - Kopf / Fuß

    private var header: some View {
        VStack(spacing: 0) {
            HStack {
                if tab == .einstellungen {
                    Button {
                        withAnimation(.easeOut(duration: 0.2)) { tab = .hauptseite }
                    } label: {
                        HStack(spacing: 4) {
                            Image(systemName: "chevron.left")
                                .font(.system(size: 11, weight: .semibold))
                            Text("Zurück")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .foregroundStyle(.secondary)
                    }
                    .buttonStyle(GlassButtonStyle())
                } else {
                    Text("SAM")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button {
                    withAnimation(.easeOut(duration: 0.2)) {
                        tab = tab == .hauptseite ? .einstellungen : .hauptseite
                    }
                } label: {
                    Image(systemName: tab == .einstellungen ? "gearshape.fill" : "gearshape")
                        .font(.system(size: 13, weight: .medium))
                        .foregroundStyle(tab == .einstellungen ? SamDesign.accent : Color.secondary)
                        .frame(width: 28, height: 28)
                        .contentShape(Rectangle())
                }
                .buttonStyle(GlassButtonStyle())
                .help("Einstellungen")
            }
            .padding(.horizontal, 16)
            .padding(.top, 2)
            .padding(.bottom, 10)

            Group {
                if tab == .hauptseite {
                    statusHeader
                } else {
                    Text("Einstellungen")
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.bottom, 14)

            if let error = appState.errorMessage, tab == .hauptseite {
                Text(error)
                    .font(.system(size: 12))
                    .foregroundStyle(.red)
                    .padding(.horizontal, 16)
                    .padding(.bottom, 10)
                    .multilineTextAlignment(.center)
            }

            Rectangle()
                .fill(Color.white.opacity(SamDesign.hairlineOpacity))
                .frame(height: 0.5)
        }
        .background(Color.white.opacity(0.03))
    }

    private var statusHeader: some View {
        HStack(spacing: 6) {
            Circle()
                .fill(appState.status.statusColor)
                .frame(width: 7, height: 7)
            Text(appState.status.statusLabel)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.primary)
        }
    }

    private var footer: some View {
        HStack {
            HStack(spacing: 7) {
                Image(systemName: "waveform.circle.fill")
                Text("SAM 1.0")
            }
            .font(.system(size: 12.5))
            .foregroundStyle(.tertiary)
            Spacer()
            Button("Onboarding", action: onShowOnboarding)
            .buttonStyle(GlassButtonStyle())
            .font(.system(size: 13))
            .foregroundStyle(.secondary)
            Button("Beenden") { NSApplication.shared.terminate(nil) }
                .buttonStyle(GlassButtonStyle())
                .font(.system(size: 13.5, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .background {
            Rectangle()
                .fill(Color.white.opacity(SamDesign.hairlineOpacity))
                .frame(height: 0.5)
                .frame(maxHeight: .infinity, alignment: .top)
        }
    }

    // MARK: - Hauptseite

    private var hauptseiteTab: some View {
        Group {
            SecLabel(title: "Spracherkennung", systemImage: "waveform")
            SamGroup {
                SamRow {
                    RowLabel(title: "Engine", sub: settings.sttEngine.displayName)
                    Spacer()
                    Picker("", selection: Binding(get: { settings.sttEngine }, set: { settings.sttEngine = $0 })) {
                        ForEach(STTEngine.allCases) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                }
                if settings.sttEngine == .whisperLocal {
                    SamRow {
                        RowLabel(title: "Lokales Modell", sub: "Erster Start: Download")
                        Spacer()
                        Picker("", selection: Binding(get: { settings.whisperLocalModel }, set: { settings.whisperLocalModel = $0 })) {
                            ForEach(WhisperLocalModel.allCases) { Text($0.displayName).tag($0) }
                        }
                        .labelsHidden().pickerStyle(.menu).fixedSize()
                    }
                } else if settings.sttEngine == .whisperOnline {
                    SamRow {
                        RowLabel(title: "Online-Modell", sub: settings.isConfigured(.openai) ? "Nutzt OpenAI-Key" : "OpenAI-Key nötig")
                        Spacer()
                        Picker("", selection: Binding(get: { settings.whisperOnlineModel }, set: { settings.whisperOnlineModel = $0 })) {
                            ForEach(WhisperOnlineModel.allCases) { Text($0.displayName).tag($0) }
                        }
                        .labelsHidden().pickerStyle(.menu).fixedSize()
                    }
                }
                SamRow(last: true) {
                    RowLabel(title: "Sprache", sub: "Transkriptionssprache")
                    Spacer()
                    Picker("", selection: Binding(get: { settings.transcriptionLanguage }, set: { settings.transcriptionLanguage = $0 })) {
                        ForEach(TranscriptionLanguage.allCases) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                }
            }

            SecLabel(title: "Allgemein", systemImage: "power")
            SamGroup {
                VStack(alignment: .leading, spacing: 8) {
                    SamRow(last: true) {
                        RowLabel(title: "Beim Anmelden starten", sub: launchAtLoginService.helperText)
                        Spacer()
                        Toggle("", isOn: Binding(
                            get: { launchAtLoginService.isEnabled },
                            set: { launchAtLoginService.setEnabled($0) }
                        ))
                        .labelsHidden()
                        .toggleStyle(.switch)
                        .controlSize(.small)
                    }
                    if let error = launchAtLoginService.errorText {
                        Text(error)
                            .font(.system(size: 12))
                            .foregroundStyle(.red)
                            .padding(.horizontal, 14)
                            .padding(.bottom, 10)
                    }
                }
            }

            SecLabel(title: "Aktivierung", systemImage: "bolt.fill")
            SamGroup {
                SamRow(last: true) {
                    RowLabel(title: "Aktiver Modus", sub: settings.inputMode == .dictation ? "Sprache → Text einfügen" : "KI antwortet")
                    Spacer()
                    Picker("", selection: Binding(get: { settings.inputMode }, set: { settings.inputMode = $0 })) {
                        ForEach(InputMode.allCases) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.segmented).frame(width: 160)
                }
            }

            SecLabel(title: "Tastenkürzel", systemImage: "command")
            SamGroup {
                shortcutRow(modifier: "Cmd", title: "Aufnehmen", desc: "Push-to-talk halten")
                shortcutRow(modifier: "Option", title: "Modus wechseln", desc: "Diktat ↔ KI", last: true)
            }

            SecLabel(title: "Berechtigungen", systemImage: "checkmark.shield")
            SamGroup {
                permissionRow("Bedienungshilfen", granted: appState.accessibilityGranted) {
                    appState.requestAccessibilityPermission()
                }
                permissionRow("Mikrofon", granted: appState.microphoneGranted) {
                    appState.requestMicrophonePermission()
                }
                permissionRow("Spracherkennung", granted: appState.speechGranted, last: true) {
                    Task { _ = await SpeechTranscriber.requestPermission() }
                }
            }
        }
    }

    private func shortcutRow(modifier: String, title: String, desc: String, last: Bool = false) -> some View {
        SamRow(last: last) {
            HStack(spacing: 7) {
                Keycap(text: "fn")
                Text("+").font(.system(size: 13)).foregroundStyle(.tertiary)
                Keycap(text: modifier)
            }
            Spacer()
            HStack(spacing: 8) {
                Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(.primary)
                Text(desc).font(.system(size: 12.5)).foregroundStyle(.secondary)
            }
        }
    }

    private func permissionRow(_ title: String, granted: Bool, last: Bool = false, action: @escaping () -> Void) -> some View {
        SamRow(last: last) {
            Text(title).font(.system(size: 14, weight: .medium)).foregroundStyle(.primary)
            Spacer()
            Image(systemName: granted ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(granted ? SamDesign.success : SamDesign.warning)
            if !granted {
                Button("Erlauben", action: action)
                    .buttonStyle(.plain)
                    .font(.system(size: 12.5))
                    .foregroundStyle(SamDesign.accent)
            }
        }
    }

    // MARK: - Einstellungen

    private var einstellungenTab: some View {
        Group {
            SecLabel(title: "KI-Anbieter", systemImage: "sparkles")
            SamGroup {
                SamRow {
                    RowLabel(title: "Anbieter", sub: "Modell für KI-Chat")
                    Spacer()
                    Picker("", selection: Binding(get: { settings.selectedProvider }, set: {
                        settings.selectedProvider = $0; resetTransient()
                    })) {
                        ForEach(LLMProvider.allCases) { Text($0.displayName).tag($0) }
                    }
                    .labelsHidden().pickerStyle(.menu).fixedSize()
                }
                VStack(alignment: .leading, spacing: 9) {
                    HStack {
                        Text("Modell")
                            .font(.system(size: 14, weight: .medium))
                            .foregroundStyle(.primary)
                        Spacer()
                        Text("Exakte Modell-ID")
                            .font(.system(size: 12))
                            .foregroundStyle(.secondary)
                    }
                    TextField(provider.defaultModel.id, text: $modelIDInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 13, design: .monospaced))

                    HStack(spacing: 6) {
                        Text("Vorschläge:").font(.system(size: 11)).foregroundStyle(.tertiary)
                        ForEach(provider.models) { model in
                            Button(model.id) { modelIDInput = model.id }
                                .buttonStyle(.plain)
                                .font(.system(size: 11, design: .monospaced))
                                .foregroundStyle(SamDesign.accent)
                                .padding(.horizontal, 8).padding(.vertical, 3)
                                .background(SamDesign.accent.opacity(0.12), in: Capsule())
                        }
                    }
                }
                .padding(14)
            }

            SecLabel(title: "API-Schlüssel", systemImage: "key.fill")
            SamGroup {
                VStack(alignment: .leading, spacing: 9) {
                    Text("\(provider.displayName) API-Schlüssel")
                        .font(.system(size: 14, weight: .medium))
                        .foregroundStyle(.primary)
                    SecureField("API-Key eingeben", text: $apiKeyInput)
                        .textFieldStyle(.roundedBorder)
                        .font(.system(size: 12.5, design: .monospaced))

                    HStack(spacing: 12) {
                        Button("Speichern") { saveAPIKey() }
                            .disabled(apiKeyInput.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
                        if settings.isConfigured(provider) {
                            Button("Löschen", role: .destructive) { deleteAPIKey() }
                        }
                        Link("Key erstellen ↗", destination: URL(string: provider.consoleURL)!)
                            .font(.system(size: 12))
                    }
                    .controlSize(.small)
                    if let saveMessage {
                        Text(saveMessage).font(.system(size: 12)).foregroundStyle(saveMessage.contains("Fehler") ? .red : SamDesign.success)
                    }
                }
                .padding(14)

                SamRow(last: true) {
                    HStack(spacing: 7) {
                        Circle().fill(settings.isConfigured(provider) ? SamDesign.success : SamDesign.warning).frame(width: 7, height: 7)
                        Text(settings.isConfigured(provider) ? "Verbunden" : "Schlüssel erforderlich")
                            .font(.system(size: 12.5)).foregroundStyle(.secondary)
                    }
                    Spacer()
                    if isTesting { ProgressView().controlSize(.small) }
                    Button("Schlüssel testen") { Task { await testConnection() } }
                        .buttonStyle(.plain)
                        .font(.system(size: 13))
                        .foregroundStyle(SamDesign.accent)
                        .disabled(!settings.isConfigured(provider) || isTesting)
                }
            }
            if let testMessage {
                Text(testMessage)
                    .font(.system(size: 12))
                    .foregroundStyle(testIsError ? .red : SamDesign.success)
                    .padding(.horizontal, 2).padding(.bottom, 14)
            }
        }
    }

    // MARK: - Aktionen

    private func resetTransient() {
        syncEinstellungenFields()
        saveMessage = nil
        testMessage = nil
    }

    private func syncEinstellungenFields() {
        modelIDInput = settings.modelID(for: provider)
        apiKeyInput = ""
    }

    private func saveAPIKey() {
        settings.saveAPIKey(apiKeyInput, for: provider)
        apiKeyInput = ""
        saveMessage = "API-Key gespeichert."
    }

    private func deleteAPIKey() {
        settings.deleteAPIKey(for: provider)
        saveMessage = "API-Key gelöscht."
    }

    private func testConnection() async {
        isTesting = true
        testMessage = nil
        defer { isTesting = false }
        let client = LLMClientFactory.make(for: provider)
        do {
            testMessage = try await client.testConnection(modelID: settings.modelID(for: provider))
            testIsError = false
        } catch {
            testMessage = error.localizedDescription
            testIsError = true
        }
    }
}
