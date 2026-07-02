import SwiftUI
import AppKit

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

    private var inputModeSubtitle: String {
        switch settings.inputMode {
        case .dictation: return "Sprache → Text einfügen"
        case .ai: return "Aktion am Cursor oder Mehrturn-Dialog"
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            header
            SettingsTabBar(selection: $tab)
            ScrollView {
                VStack(alignment: .leading, spacing: 0) {
                    switch tab {
                    case .hauptseite: hauptseiteTab
                    case .sprache: spracheTab
                    case .ki: kiTab
                    case .namen: namenTab
                    }
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
            launchAtLoginService.refresh()
        }
        .onChange(of: tab) { _, newTab in
            if newTab == .ki { syncKiFields() }
        }
        .onChange(of: modelIDInput) { _, newValue in
            settings.setModelID(newValue, for: provider)
        }
    }

    // MARK: - Kopf / Navigation

    private var header: some View {
        VStack(spacing: 0) {
            Group {
                if tab == .hauptseite {
                    statusHeader
                } else {
                    Text(tab.title)
                        .font(.system(size: 13, weight: .semibold))
                        .foregroundStyle(.primary)
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 12)
            .padding(.bottom, 10)

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
                Text("\(settings.assistantDisplayName) 1.0")
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

    // MARK: - Start

    private var hauptseiteTab: some View {
        Group {
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
                    RowLabel(title: "Aktiver Modus", sub: inputModeSubtitle)
                    Spacer()
                    Picker("", selection: Binding(
                        get: { settings.inputMode },
                        set: { appState.setInputMode($0) }
                    )) {
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
                    appState.requestSpeechPermission()
                }
            }
        }
    }

    // MARK: - Sprache

    private var spracheTab: some View {
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
        }
    }

    // MARK: - KI

    private var kiTab: some View {
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

    // MARK: - Namen

    private var namenTab: some View {
        Group {
            SecLabel(title: "Eigennamen", systemImage: "person.text.rectangle")
            Text("Assistentenname, dein Name, Aussprache, Firmenname – die KI nutzt diese Begriffe in Antworten.")
                .font(.system(size: 12))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)
                .padding(.bottom, 10)

            if settings.properNames.isEmpty {
                VStack(alignment: .leading, spacing: 10) {
                    Text("Noch keine Einträge.")
                        .font(.system(size: 13))
                        .foregroundStyle(.secondary)
                    nameSuggestionChips
                }
                .padding(.bottom, 12)
            } else {
                SamGroup {
                    ForEach(Array(settings.properNames.enumerated()), id: \.element.id) { index, entry in
                        ProperNameRow(
                            entry: entry,
                            isLast: index == settings.properNames.count - 1,
                            onUpdate: { settings.updateProperName($0) },
                            onDelete: { settings.removeProperName(id: $0) }
                        )
                    }
                }
            }

            HStack(spacing: 10) {
                Button {
                    settings.addProperName()
                } label: {
                    Label("Eintrag hinzufügen", systemImage: "plus.circle.fill")
                        .font(.system(size: 13, weight: .medium))
                }
                .buttonStyle(.plain)
                .foregroundStyle(SamDesign.accent)

                if !settings.properNames.isEmpty {
                    nameSuggestionChips
                }
            }
            .padding(.top, 4)
        }
    }

    private var nameSuggestionChips: some View {
        FlowLayout(spacing: 6) {
            ForEach(ProperNameLabel.suggestions, id: \.self) { suggestion in
                Button(suggestion) {
                    let exists = settings.properNames.contains { ProperNameLabel.matches($0.label, suggestion) }
                    if !exists {
                        settings.addProperName(label: suggestion, value: "")
                    }
                }
                .buttonStyle(.plain)
                .font(.system(size: 11, weight: .medium))
                .foregroundStyle(SamDesign.accent)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(SamDesign.accent.opacity(0.12), in: Capsule())
            }
        }
    }

    // MARK: - Hilfszeilen

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

    // MARK: - Aktionen

    private func resetTransient() {
        syncKiFields()
        saveMessage = nil
        testMessage = nil
    }

    private func syncKiFields() {
        modelIDInput = settings.modelID(for: provider)
        apiKeyInput = ""
    }

    private func saveAPIKey() {
        let ok = settings.saveAPIKey(apiKeyInput, for: provider)
        apiKeyInput = ""
        saveMessage = ok ? "API-Key gespeichert." : "Fehler: Keychain-Speicherung fehlgeschlagen."
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

// MARK: - Eigenname-Zeile

private struct ProperNameRow: View {
    let entry: ProperNameEntry
    var isLast: Bool
    var onUpdate: (ProperNameEntry) -> Void
    var onDelete: (UUID) -> Void

    @State private var label: String = ""
    @State private var value: String = ""

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Bezeichnung")
                        .font(.system(size: 12))
                        .foregroundStyle(.secondary)
                    Spacer()
                    Button(role: .destructive) {
                        onDelete(entry.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.system(size: 11, weight: .semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.red.opacity(0.85))
                }
                TextField("z. B. Assistentenname", text: $label)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .onChange(of: label) { _, newValue in
                        var updated = entry
                        updated.label = newValue
                        onUpdate(updated)
                    }
                TextField("Wert", text: $value)
                    .textFieldStyle(.roundedBorder)
                    .font(.system(size: 13))
                    .onChange(of: value) { _, newValue in
                        var updated = entry
                        updated.value = newValue
                        onUpdate(updated)
                    }
            }
            .padding(14)

            if !isLast {
                Rectangle()
                    .fill(Color.white.opacity(SamDesign.hairlineOpacity))
                    .frame(height: 0.5)
                    .padding(.leading, 14)
            }
        }
        .onAppear {
            label = entry.label
            value = entry.value
        }
        .onChange(of: entry.label) { _, newValue in
            if label != newValue { label = newValue }
        }
        .onChange(of: entry.value) { _, newValue in
            if value != newValue { value = newValue }
        }
    }
}

/// Einfaches Zeilenumbruch-Layout für Vorschlags-Chips.
private struct FlowLayout: Layout {
    var spacing: CGFloat = 6

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = arrange(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = arrange(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private func arrange(proposal: ProposedViewSize, subviews: Subviews) -> (size: CGSize, positions: [CGPoint]) {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var x: CGFloat = 0
        var y: CGFloat = 0
        var rowHeight: CGFloat = 0
        var maxX: CGFloat = 0

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)
            if x + size.width > maxWidth, x > 0 {
                x = 0
                y += rowHeight + spacing
                rowHeight = 0
            }
            positions.append(CGPoint(x: x, y: y))
            rowHeight = max(rowHeight, size.height)
            x += size.width + spacing
            maxX = max(maxX, x - spacing)
        }

        return (CGSize(width: maxX, height: y + rowHeight), positions)
    }
}
