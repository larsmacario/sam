import AppKit
import SwiftUI

/// Schwebendes NSPanel für Aufnahme-Pille und Antwort-Fenster.
@MainActor
final class OverlayWindowController: ObservableObject {
    static let shared = OverlayWindowController()

    enum PillState {
        case recording  // Aufnahme läuft
        case modeFlash  // kurzer Hinweis nach Moduswechsel
    }

    private var recordingPanel: NSPanel?
    private var answerPanel: NSPanel?
    private var chatPanel: NSPanel?
    private var flashTask: Task<Void, Never>?

    @Published var recordingTranscript = ""
    @Published var isRecordingVisible = false
    @Published var currentMode: InputMode = .ai
    @Published var pillState: PillState = .recording
    @Published var recordingStart = Date()
    @Published var answerText = ""
    @Published var isAnswerVisible = false
    @Published var isChatVisible = false

    private init() {}

    // MARK: - Aufnahme-Pille

    func showRecording(mode: InputMode) {
        flashTask?.cancel()
        currentMode = mode
        pillState = .recording
        recordingTranscript = ""
        recordingStart = Date()
        presentRecordingPanel()
    }

    func updateRecordingTranscript(_ transcript: String) {
        recordingTranscript = transcript
        refreshRecordingContent()
    }

    /// Klar sichtbares Feedback nach Moduswechsel (fn+Option); blendet selbsttätig aus.
    func flashMode(_ mode: InputMode) {
        flashTask?.cancel()
        currentMode = mode
        pillState = .modeFlash
        recordingTranscript = ""
        presentRecordingPanel()

        flashTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 1_300_000_000)
            guard !Task.isCancelled else { return }
            self?.hideRecording()
        }
    }

    func hideRecording() {
        flashTask?.cancel()
        isRecordingVisible = false
        recordingPanel?.orderOut(nil)
    }

    private func presentRecordingPanel() {
        isRecordingVisible = true
        if recordingPanel == nil {
            recordingPanel = createPanel(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 72),
                view: RecordingPillView(controller: self),
                hasShadow: false // Pille hat ihren eigenen runden SwiftUI-Schatten
            )
        } else {
            refreshRecordingContent()
        }
        positionRecordingPanel()
        recordingPanel?.orderFrontRegardless()
    }

    // MARK: - Antwort-Fenster

    func showAnswer(_ text: String) {
        answerText = text
        isAnswerVisible = true

        if answerPanel == nil {
            answerPanel = createPanel(
                contentRect: NSRect(x: 0, y: 0, width: 460, height: 340),
                view: AnswerPanelView(controller: self)
            )
            installEscapeMonitor()
        } else {
            refreshAnswerContent()
        }

        positionAnswerPanel()
        answerPanel?.orderFrontRegardless()
    }

    func hideAnswer() {
        isAnswerVisible = false
        answerPanel?.orderOut(nil)
    }

    // MARK: - Chat-Fenster

    func showChat() {
        isChatVisible = true

        if chatPanel == nil {
            let screen = NSScreen.main ?? NSScreen.screens.first!
            chatPanel = createChatPanel(
                contentRect: chatPanelFrame(for: screen),
                view: ChatPanelView()
            )
            installChatEscapeMonitor()
        }

        positionChatPanel()
        chatPanel?.makeKeyAndOrderFront(nil)
    }

    func hideChat() {
        isChatVisible = false
        chatPanel?.orderOut(nil)
    }

    private var chatEscapeMonitor: Any?

    private func installChatEscapeMonitor() {
        chatEscapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { event in
            if event.keyCode == 53 {
                Task { @MainActor in
                    AppState.shared.closeChatSession()
                }
                return nil
            }
            return event
        }
    }

    private func createChatPanel<V: View>(contentRect: NSRect, view: V) -> NSPanel {
        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false

        let hosting = NSHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: contentRect.size)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting

        return panel
    }

    private func chatPanelFrame(for screen: NSScreen) -> NSRect {
        let visible = screen.visibleFrame
        let width = SamDesign.chatPanelWidth
        let height = visible.height * SamDesign.chatPanelHeightRatio
        let inset = SamDesign.chatPanelScreenInset
        let x = visible.maxX - width - inset
        let y = visible.minY + (visible.height - height) / 2
        return NSRect(x: x, y: y, width: width, height: height)
    }

    private func positionChatPanel() {
        guard let panel = chatPanel, let screen = NSScreen.main else { return }
        let frame = chatPanelFrame(for: screen)
        panel.setFrame(frame, display: true)
        panel.contentView?.frame = panel.contentView?.bounds ?? .zero
    }

    private var escapeMonitor: Any?

    private func installEscapeMonitor() {
        escapeMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            if event.keyCode == 53 { // Escape
                Task { @MainActor in
                    self?.hideAnswer()
                }
                return nil
            }
            return event
        }
    }

    // MARK: - Panel-Infrastruktur

    private func createPanel<V: View>(contentRect: NSRect, view: V, hasShadow: Bool = true) -> NSPanel {
        let panel = NSPanel(
            contentRect: contentRect,
            styleMask: [.nonactivatingPanel, .borderless, .fullSizeContentView],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .floating
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .ignoresCycle]
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = hasShadow
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = true

        let hosting = NSHostingView(rootView: view)
        hosting.frame = contentRect
        panel.contentView = hosting

        return panel
    }

    private func refreshRecordingContent() {
        guard let panel = recordingPanel else { return }
        let hosting = NSHostingView(rootView: RecordingPillView(controller: self))
        hosting.frame = panel.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 420, height: 72)
        panel.contentView = hosting
    }

    private func refreshAnswerContent() {
        guard let panel = answerPanel else { return }
        let hosting = NSHostingView(rootView: AnswerPanelView(controller: self))
        hosting.frame = panel.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 460, height: 340)
        panel.contentView = hosting
    }

    private func positionRecordingPanel() {
        guard let panel = recordingPanel, let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let x = screenFrame.midX - panelSize.width / 2
        let y = screenFrame.minY + 48
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    private func positionAnswerPanel() {
        guard let panel = answerPanel, let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let x = screenFrame.midX - panelSize.width / 2
        let y = screenFrame.midY - panelSize.height / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }
}

// MARK: - SwiftUI Views

/// Dynamic-Island-Pille (dunkles Vibrancy-Glas) mit Live-Waveform + Modus-Indikator.
struct RecordingPillView: View {
    @ObservedObject var controller: OverlayWindowController

    private var mode: InputMode { controller.currentMode }
    private var color: Color { mode.accentColor }

    var body: some View {
        ZStack {
            HStack(spacing: 13) {
                iconBadge
                if controller.pillState == .recording {
                    recordingContent
                } else {
                    modeFlashContent
                }
            }
            .padding(.leading, 14)
            .padding(.trailing, 18)
            .frame(height: 52)
            .background(pillBackground)
            .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5))
            .shadow(color: .black.opacity(0.40), radius: 20, x: 0, y: 12)
            .fixedSize()
        }
        .frame(width: 420, height: 72)
    }

    private var iconBadge: some View {
        ZStack {
            Circle().fill(color)
            Image(systemName: mode.pillSymbol)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.white)
        }
        .frame(width: 30, height: 30)
        .shadow(color: color.opacity(0.5), radius: 6, x: 0, y: 2)
    }

    private var recordingContent: some View {
        HStack(spacing: 12) {
            WaveformView(color: color)
                .frame(width: 132)

            VStack(alignment: .leading, spacing: 1) {
                Text(mode.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                if controller.recordingTranscript.isEmpty {
                    PillTimerText(start: controller.recordingStart)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.55))
                        .monospacedDigit()
                } else {
                    Text(controller.recordingTranscript)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
            .frame(width: 82, alignment: .leading)
        }
    }

    private var modeFlashContent: some View {
        VStack(alignment: .leading, spacing: 1) {
            Text("Modus")
                .font(.system(size: 11.5))
                .foregroundStyle(.white.opacity(0.55))
            Text(mode.displayName)
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(.white)
        }
        .padding(.trailing, 4)
    }

    private var pillBackground: some View {
        ZStack {
            Capsule().fill(.ultraThinMaterial)
            Capsule().fill(Color(red: 0.086, green: 0.086, blue: 0.094).opacity(0.55))
        }
        .environment(\.colorScheme, .dark)
    }
}

/// Animierte „Listening"-Waveform – seismografisch wandernde Hülle plus Jitter.
struct WaveformView: View {
    let color: Color
    var barCount: Int = 26
    var maxHeight: CGFloat = 24

    var body: some View {
        TimelineView(.animation) { timeline in
            let t = timeline.date.timeIntervalSinceReferenceDate
            HStack(spacing: 3) {
                ForEach(0..<barCount, id: \.self) { i in
                    let level = barLevel(t: t, i: Double(i))
                    Capsule(style: .continuous)
                        .fill(color)
                        .frame(width: 3, height: max(3, maxHeight * level))
                        .opacity(0.55 + level * 0.45)
                }
            }
            .frame(height: maxHeight)
        }
    }

    private func barLevel(t: Double, i: Double) -> CGFloat {
        let env = 0.45 + 0.4 * sin(t * 1.8 + i * 0.5)
        let jitter = 0.5 + 0.5 * abs(sin(t * 5.0 + i * 1.3))
        return CGFloat(max(0.14, min(1.0, env * jitter)))
    }
}

/// Laufender Aufnahme-Timer (mm:ss).
struct PillTimerText: View {
    let start: Date

    var body: some View {
        TimelineView(.periodic(from: start, by: 1)) { context in
            let elapsed = max(0, Int(context.date.timeIntervalSince(start)))
            Text(String(format: "%d:%02d", elapsed / 60, elapsed % 60))
        }
    }
}

/// Antwort-Fenster im Glas-Design (Vibrancy), konsistent mit Pille & Settings-Popover.
struct AnswerPanelView: View {
    @ObservedObject var controller: OverlayWindowController
    @ObservedObject private var settings = SettingsStore.shared
    @State private var copied = false

    var body: some View {
        VStack(spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SamDesign.chatColor)
                Text(settings.assistantDisplayName)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Button { controller.hideAnswer() } label: {
                    Image(systemName: "xmark")
                        .font(.system(size: 10, weight: .bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 22, height: 22)
                        .background(Color.primary.opacity(0.08), in: Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 0.5)

            // Antworttext
            ScrollView {
                Text(controller.answerText)
                    .font(.system(size: 14))
                    .lineSpacing(2)
                    .textSelection(.enabled)
                    .foregroundStyle(.primary)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .padding(16)
            }

            Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 0.5)

            // Footer
            HStack {
                Spacer()
                Button {
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(controller.answerText, forType: .string)
                    copied = true
                } label: {
                    HStack(spacing: 5) {
                        Image(systemName: copied ? "checkmark" : "doc.on.doc")
                        Text(copied ? "Kopiert" : "Kopieren")
                    }
                    .font(.system(size: 13, weight: .medium))
                    .foregroundStyle(SamDesign.accent)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 11)
        }
        .frame(width: 460, height: 340)
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .onChange(of: controller.answerText) { _, _ in copied = false }
    }
}

/// Mehrturn-Chat-Fenster im Chat-Modus.
struct ChatPanelView: View {
    @ObservedObject private var chat = ChatSessionController.shared
    @ObservedObject private var appState = AppState.shared
    @ObservedObject private var settings = SettingsStore.shared
    @State private var draft = ""
    @FocusState private var isInputFocused: Bool

    var body: some View {
        VStack(spacing: 0) {
            chatHeader
            Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 0.5)

            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 12) {
                        ForEach(chat.messages) { message in
                            ChatBubbleView(message: message)
                                .id(message.id)
                        }
                        if chat.isProcessing {
                            ChatLoadingBubble()
                                .id("loading")
                        }
                        Color.clear
                            .frame(height: 1)
                            .id("chatBottom")
                    }
                    .padding(16)
                }
                .onAppear {
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: chat.messages.count) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: chat.messages.last?.id) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
                .onChange(of: chat.isProcessing) { _, _ in
                    scrollToBottom(proxy: proxy)
                }
            }
            .frame(maxHeight: .infinity)

            Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 0.5)
            chatFooter
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(VisualEffectBackground())
        .clipShape(SamDesign.chatPanelShape)
        .overlay {
            SamDesign.chatPanelShape
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
        }
        .shadow(color: .black.opacity(0.28), radius: 24, x: -8, y: 0)
        .onAppear { isInputFocused = true }
    }

    private var chatHeader: some View {
        HStack(spacing: 8) {
            Image(systemName: "bubble.left.and.bubble.right.fill")
                .font(.system(size: 13, weight: .semibold))
                .foregroundStyle(SamDesign.dialogColor)
            Text("\(settings.assistantDisplayName) Chat")
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(.primary)
            Spacer()
            Button {
                appState.closeChatSession()
            } label: {
                Text("Neuer Chat")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
            Button {
                appState.closeChatSession()
            } label: {
                Image(systemName: "xmark")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 22, height: 22)
                    .background(Color.primary.opacity(0.08), in: Circle())
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var chatFooter: some View {
        VStack(spacing: 8) {
            HStack(spacing: 8) {
                TextField("Nachricht schreiben…", text: $draft, axis: .vertical)
                    .textFieldStyle(.plain)
                    .lineLimit(1...4)
                    .focused($isInputFocused)
                    .glassInsetField()
                    .onSubmit { sendDraft() }

                Button(action: sendDraft) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.system(size: 24))
                        .foregroundStyle(canSend ? SamDesign.dialogColor : .secondary.opacity(0.4))
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }

            HStack(spacing: 5) {
                Image(systemName: "mic.fill")
                    .font(.system(size: 10))
                Text("fn + ⌘ zum Sprechen")
                    .font(.system(size: 11))
            }
            .foregroundStyle(.tertiary)
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
    }

    private var canSend: Bool {
        !draft.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty && !chat.isProcessing
    }

    private func sendDraft() {
        let text = draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty, !chat.isProcessing else { return }
        draft = ""
        Task {
            await appState.sendChatText(text)
        }
    }

    private func scrollToBottom(proxy: ScrollViewProxy) {
        DispatchQueue.main.async {
            withAnimation(.easeOut(duration: 0.2)) {
                proxy.scrollTo("chatBottom", anchor: .bottom)
            }
        }
    }
}

private struct ChatBubbleView: View {
    let message: SamChatMessage
    @State private var copied = false

    private var isUser: Bool { message.role == .user }

    var body: some View {
        HStack(alignment: .top) {
            if isUser { Spacer(minLength: 48) }

            VStack(alignment: isUser ? .trailing : .leading, spacing: 6) {
                Text(message.content)
                    .font(.system(size: 14))
                    .lineSpacing(2)
                    .textSelection(.enabled)
                    .foregroundStyle(isUser ? .white : .primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 10)
                    .background {
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(isUser ? SamDesign.dialogColor.opacity(0.85) : Color.primary.opacity(0.06))
                    }

                if !isUser {
                    HStack(spacing: 12) {
                        Button {
                            NSPasteboard.general.clearContents()
                            NSPasteboard.general.setString(message.content, forType: .string)
                            copied = true
                        } label: {
                            Label(copied ? "Kopiert" : "Kopieren", systemImage: copied ? "checkmark" : "doc.on.doc")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(SamDesign.accent)

                        Button {
                            Task {
                                try? await OutputRouter.shared.pasteText(message.content)
                            }
                        } label: {
                            Label("Einfügen", systemImage: "text.cursor")
                                .font(.system(size: 11, weight: .medium))
                        }
                        .buttonStyle(.plain)
                        .foregroundStyle(SamDesign.accent)
                    }
                }
            }

            if !isUser { Spacer(minLength: 48) }
        }
    }
}

private struct ChatLoadingBubble: View {
    var body: some View {
        HStack {
            HStack(spacing: 4) {
                ForEach(0..<3, id: \.self) { i in
                    Circle()
                        .fill(Color.secondary.opacity(0.5))
                        .frame(width: 6, height: 6)
                        .offset(y: loadingOffset(for: i))
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 14, style: .continuous))
            Spacer(minLength: 48)
        }
    }

    private func loadingOffset(for index: Int) -> CGFloat {
        let phase = Date.timeIntervalSinceReferenceDate * 3 + Double(index) * 0.4
        return CGFloat(sin(phase)) * 3
    }
}
