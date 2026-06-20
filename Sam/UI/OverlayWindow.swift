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
    @Published var isMeetingModeVisible = false
    @Published var meetingTranscript = ""
    @Published var meetingStatus: MeetingSessionStatus = .idle
    @Published var meetingStart = Date()
    @Published var meetingSummaryRecord: MeetingRecord?
    @Published var isMeetingSummaryVisible = false
    @Published var meetingHotkeyPressed = false

    private var meetingPanel: NSPanel?
    private var meetingSummaryPanel: NSPanel?
    private var meetingStartPanel: NSPanel?
    private var meetingStartHandler: ((String?) -> Void)?

    private var insertUndoToastPanel: NSPanel?
    private var insertUndoToastTask: Task<Void, Never>?
    @Published var isInsertUndoToastVisible = false

    private init() {}

    // MARK: - Meeting-Modus (Idle + Recording)

    /// Dauerhafte Idle-Pille im Meeting-Modus (fn+⌘ zum Starten).
    func showMeetingModeIdle() {
        meetingTranscript = ""
        meetingStatus = .idle
        meetingHotkeyPressed = false
        isMeetingModeVisible = true
        presentMeetingPanel()
    }

    /// Aufnahme läuft – Timer, Waveform, Transkript.
    func showMeetingRecording() {
        meetingTranscript = ""
        meetingStatus = .recording
        meetingStart = Date()
        meetingHotkeyPressed = false
        isMeetingModeVisible = true
        presentMeetingPanel()
    }

    func revertMeetingToIdle() {
        meetingTranscript = ""
        meetingStatus = .idle
        meetingHotkeyPressed = false
        if isMeetingModeVisible {
            refreshMeetingContent()
        }
    }

    func hideMeetingMode() {
        isMeetingModeVisible = false
        meetingHotkeyPressed = false
        meetingPanel?.orderOut(nil)
    }

    func setMeetingHotkeyPressed(_ pressed: Bool) {
        meetingHotkeyPressed = pressed
        refreshMeetingContent()
    }

    func updateMeetingTranscript(_ text: String) {
        meetingTranscript = text
        refreshMeetingContent()
    }

    func updateMeetingStatus(_ status: MeetingSessionStatus) {
        meetingStatus = status
        refreshMeetingContent()
    }

    func showMeetingStartSheet(onStart: @escaping (String?) -> Void, onCancel: @escaping () -> Void) {
        meetingStartHandler = onStart
        hideMeetingStartSheet()

        let view = MeetingStartSheetView(
            onStart: { [weak self] title in
                self?.hideMeetingStartSheet()
                onStart(title)
            },
            onCancel: { [weak self] in
                self?.hideMeetingStartSheet()
                onCancel()
            }
        )

        let panel = createKeyPanel(
            contentRect: NSRect(x: 0, y: 0, width: 400, height: 280),
            view: view
        )
        meetingStartPanel = panel
        positionMeetingStartPanel(panel)
        NSApp.activate(ignoringOtherApps: true)
        panel.makeKeyAndOrderFront(nil)
    }

    func hideMeetingStartSheet() {
        meetingStartPanel?.orderOut(nil)
        meetingStartPanel = nil
        meetingStartHandler = nil
    }

    private func positionMeetingStartPanel(_ panel: NSPanel) {
        guard let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let x = screenFrame.midX - panelSize.width / 2
        let y = screenFrame.midY - panelSize.height / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

    func showMeetingSummary(record: MeetingRecord) {
        meetingSummaryRecord = record
        isMeetingSummaryVisible = true

        if meetingSummaryPanel == nil {
            meetingSummaryPanel = createPanel(
                contentRect: NSRect(x: 0, y: 0, width: 480, height: 420),
                view: MeetingSummaryPanelView(controller: self)
            )
        } else {
            refreshMeetingSummaryContent()
        }

        positionMeetingSummaryPanel()
        meetingSummaryPanel?.orderFrontRegardless()
    }

    func hideMeetingSummary() {
        isMeetingSummaryVisible = false
        meetingSummaryPanel?.orderOut(nil)
    }

    private func presentMeetingPanel() {
        if meetingPanel == nil {
            meetingPanel = createPanel(
                contentRect: NSRect(x: 0, y: 0, width: 420, height: 72),
                view: MeetingPillView(controller: self),
                hasShadow: false
            )
        } else {
            refreshMeetingContent()
        }
        positionRecordingPanel(meetingPanel)
        meetingPanel?.orderFrontRegardless()
    }

    private func refreshMeetingContent() {
        guard let panel = meetingPanel else { return }
        let hosting = NSHostingView(rootView: MeetingPillView(controller: self))
        hosting.frame = panel.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 420, height: 72)
        panel.contentView = hosting
    }

    private func refreshMeetingSummaryContent() {
        guard let panel = meetingSummaryPanel else { return }
        let hosting = NSHostingView(rootView: MeetingSummaryPanelView(controller: self))
        hosting.frame = panel.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 480, height: 420)
        panel.contentView = hosting
    }

    private func positionMeetingSummaryPanel() {
        guard let panel = meetingSummaryPanel, let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let x = screenFrame.midX - panelSize.width / 2
        let y = screenFrame.midY - panelSize.height / 2
        panel.setFrameOrigin(NSPoint(x: x, y: y))
    }

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
        positionRecordingPanel(recordingPanel)
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

    // MARK: - KI-Einfügen Toast (Rückgängig)

    /// Kurzes Feedback nach KI-Einfügen; Klick auf „Rückgängig" simuliert Cmd+Z in der Ziel-App.
    func showInsertUndoToast(onUndo: @escaping () -> Void) {
        insertUndoToastTask?.cancel()
        isInsertUndoToastVisible = true

        if insertUndoToastPanel == nil {
            insertUndoToastPanel = createPanel(
                contentRect: NSRect(x: 0, y: 0, width: 260, height: 52),
                view: InsertUndoToastView(onUndo: { [weak self] in
                    onUndo()
                    self?.hideInsertUndoToast()
                }),
                hasShadow: false
            )
            insertUndoToastPanel?.acceptsMouseMovedEvents = true
        } else {
            refreshInsertUndoToastContent(onUndo: onUndo)
        }

        positionInsertUndoToastPanel()
        insertUndoToastPanel?.orderFrontRegardless()

        insertUndoToastTask = Task { [weak self] in
            try? await Task.sleep(nanoseconds: 5_000_000_000)
            guard !Task.isCancelled else { return }
            self?.hideInsertUndoToast()
        }
    }

    func hideInsertUndoToast() {
        insertUndoToastTask?.cancel()
        isInsertUndoToastVisible = false
        insertUndoToastPanel?.orderOut(nil)
    }

    private func refreshInsertUndoToastContent(onUndo: @escaping () -> Void) {
        guard let panel = insertUndoToastPanel else { return }
        let hosting = NSHostingView(rootView: InsertUndoToastView(onUndo: { [weak self] in
            onUndo()
            self?.hideInsertUndoToast()
        }))
        hosting.frame = panel.contentView?.bounds ?? NSRect(x: 0, y: 0, width: 260, height: 52)
        panel.contentView = hosting
    }

    private func positionInsertUndoToastPanel() {
        guard let panel = insertUndoToastPanel, let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelSize = panel.frame.size
        let x = screenFrame.midX - panelSize.width / 2
        let y = screenFrame.minY + 108
        panel.setFrameOrigin(NSPoint(x: x, y: y))
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
        chatPanel?.orderFrontRegardless()
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
            styleMask: [.borderless, .fullSizeContentView, .nonactivatingPanel],
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
        panel.becomesKeyOnlyIfNeeded = true

        let hosting = PassThroughHostingView(rootView: view)
        hosting.frame = NSRect(origin: .zero, size: contentRect.size)
        hosting.autoresizingMask = [.width, .height]
        panel.contentView = hosting

        return panel
    }

    private func chatPanelFrame(for screen: NSScreen) -> NSRect {
        screen.visibleFrame
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

    private func createKeyPanel<V: View>(contentRect: NSRect, view: V, hasShadow: Bool = true) -> NSPanel {
        let panel = KeyPanel(
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
        panel.hasShadow = hasShadow
        panel.hidesOnDeactivate = false
        panel.becomesKeyOnlyIfNeeded = false

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

    private func positionRecordingPanel(_ panel: NSPanel? = nil) {
        let target = panel ?? recordingPanel
        guard let target, let screen = NSScreen.main else { return }
        let screenFrame = screen.visibleFrame
        let panelSize = target.frame.size
        let x = screenFrame.midX - panelSize.width / 2
        let y = screenFrame.minY + 48
        target.setFrameOrigin(NSPoint(x: x, y: y))
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

/// Toast nach KI-Einfügen: „Eingefügt · Rückgängig" (nicht-aktivierend, klickbar).
struct InsertUndoToastView: View {
    let onUndo: () -> Void

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(SamDesign.success)

            Text("Eingefügt")
                .font(.system(size: 13, weight: .medium))
                .foregroundStyle(.white)

            Text("·")
                .foregroundStyle(.white.opacity(0.35))

            Button(action: onUndo) {
                Text("Rückgängig")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SamDesign.chatColor)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 16)
        .frame(height: 44)
        .background(
            ZStack {
                Capsule().fill(.ultraThinMaterial)
                Capsule().fill(Color(red: 0.086, green: 0.086, blue: 0.094).opacity(0.72))
            }
            .environment(\.colorScheme, .dark)
        )
        .overlay(Capsule().strokeBorder(Color.white.opacity(0.14), lineWidth: 0.5))
        .shadow(color: .black.opacity(0.35), radius: 16, x: 0, y: 8)
        .frame(width: 260, height: 52)
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
                LinkifiedText(text: controller.answerText)
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
        GeometryReader { geo in
            HStack(spacing: 0) {
                Color.clear
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .allowsHitTesting(false)

                chatCard
                    .frame(width: SamDesign.chatPanelWidth)
                    .frame(height: geo.size.height * SamDesign.chatPanelHeightRatio)
                    .frame(maxHeight: .infinity, alignment: .center)
                    .padding(.trailing, SamDesign.chatPanelScreenInset)
            }
        }
        .onAppear { isInputFocused = true }
    }

    private var chatCard: some View {
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
                LinkifiedText(
                    text: message.content,
                    baseColor: isUser ? .white : .primary,
                    linkColor: isUser ? .white : SamDesign.accent
                )
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

/// Volle Bildschirmbreite mit Klick-Durchreichung links vom Chat-Panel.
/// Panel das Tastatureingabe akzeptiert (z. B. TextField im Start-Dialog).
private final class KeyPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

private final class PassThroughHostingView<Content: View>: NSHostingView<Content> {
    private var interactiveTrailingWidth: CGFloat {
        SamDesign.chatPanelWidth + SamDesign.chatPanelScreenInset
    }

    override func hitTest(_ point: NSPoint) -> NSView? {
        if point.x < bounds.width - interactiveTrailingWidth {
            return nil
        }
        return super.hitTest(point)
    }
}

/// Meeting-Pille: gleiches Layout wie `RecordingPillView` (Modus-Flash + Aufnahme).
struct MeetingPillView: View {
    @ObservedObject var controller: OverlayWindowController

    private let mode = InputMode.meeting
    private var color: Color { mode.accentColor }
    private var isIdle: Bool { controller.meetingStatus == .idle }

    private var statusSubtitle: String {
        switch controller.meetingStatus {
        case .transcribing: return "Transkribiere…"
        case .summarizing: return "Fasse zusammen…"
        case .recovering: return "Stelle wieder her…"
        case .recording, .idle: return ""
        }
    }

    var body: some View {
        ZStack {
            HStack(spacing: 13) {
                iconBadge
                if controller.meetingStatus == .recording {
                    recordingContent
                } else {
                    statusContent
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

    private var recordingContent: some View {
        HStack(spacing: 12) {
            WaveformView(color: color)
                .frame(width: 132)

            VStack(alignment: .leading, spacing: 1) {
                Text(mode.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                if controller.meetingTranscript.isEmpty {
                    PillTimerText(start: controller.meetingStart)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.55))
                        .monospacedDigit()
                } else {
                    Text(controller.meetingTranscript)
                        .font(.system(size: 11.5))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                }
            }
            .frame(width: 82, alignment: .leading)
        }
    }

    private var statusContent: some View {
        VStack(alignment: .leading, spacing: 1) {
            if isIdle {
                Text("Modus")
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.55))
                Text(mode.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
            } else {
                Text(mode.displayName)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(.white)
                Text(statusSubtitle)
                    .font(.system(size: 11.5))
                    .foregroundStyle(.white.opacity(0.55))
                    .lineLimit(1)
            }
        }
        .padding(.trailing, 4)
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

    private var pillBackground: some View {
        ZStack {
            Capsule().fill(.ultraThinMaterial)
            Capsule().fill(Color(red: 0.086, green: 0.086, blue: 0.094).opacity(0.55))
        }
        .environment(\.colorScheme, .dark)
    }
}

/// Zusammenfassung nach Meeting-Ende.
struct MeetingSummaryPanelView: View {
    @ObservedObject var controller: OverlayWindowController
    @State private var copied = false

    private var record: MeetingRecord? { controller.meetingSummaryRecord }

    var body: some View {
        VStack(spacing: 0) {
            HStack(spacing: 8) {
                Image(systemName: "person.3.fill")
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(SamDesign.meetingColor)
                Text(record?.title ?? "Meeting")
                    .font(.system(size: 15, weight: .semibold))
                    .lineLimit(1)
                Spacer()
                Button { controller.hideMeetingSummary() } label: {
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

            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    if let summary = record?.summary, !summary.overview.isEmpty {
                        summarySection(title: "Zusammenfassung", items: [summary.overview])
                        if !summary.topics.isEmpty {
                            summarySection(title: "Themen", items: summary.topics)
                        }
                        if !summary.decisions.isEmpty {
                            summarySection(title: "Entscheidungen", items: summary.decisions)
                        }
                        if !summary.actionItems.isEmpty {
                            VStack(alignment: .leading, spacing: 6) {
                                Text("Action Items")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                ForEach(summary.actionItems) { item in
                                    Text("• \(item.task)\(assigneeSuffix(item))")
                                        .font(.system(size: 13))
                                }
                            }
                        }
                        if !summary.openQuestions.isEmpty {
                            summarySection(title: "Offene Fragen", items: summary.openQuestions)
                        }
                    } else if let transcript = record?.fullTranscript, !transcript.isEmpty {
                        Text(transcript)
                            .font(.system(size: 13))
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        Text("Kein Transkript vorhanden.")
                            .foregroundStyle(.secondary)
                    }
                }
                .padding(16)
            }

            Rectangle().fill(Color.primary.opacity(0.08)).frame(height: 0.5)

            HStack {
                Spacer()
                Button {
                    let text = exportText()
                    NSPasteboard.general.clearContents()
                    NSPasteboard.general.setString(text, forType: .string)
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
        .frame(width: 480, height: 420)
        .background(VisualEffectBackground())
        .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .strokeBorder(Color.white.opacity(0.15), lineWidth: 0.5)
        )
        .onChange(of: controller.meetingSummaryRecord?.id) { _, _ in copied = false }
    }

    private func summarySection(title: String, items: [String]) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Text(title)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            ForEach(items, id: \.self) { item in
                Text("• \(item)")
                    .font(.system(size: 13))
            }
        }
    }

    private func assigneeSuffix(_ item: MeetingActionItem) -> String {
        var parts: [String] = []
        if let assignee = item.assignee, !assignee.isEmpty { parts.append(assignee) }
        if let due = item.dueDate, !due.isEmpty { parts.append("bis \(due)") }
        guard !parts.isEmpty else { return "" }
        return " (\(parts.joined(separator: ", ")))"
    }

    private func exportText() -> String {
        guard let record else { return "" }
        var lines = [record.title, ""]
        if let summary = record.summary {
            lines.append(summary.overview)
            lines.append("")
            if !summary.actionItems.isEmpty {
                lines.append("Action Items:")
                for item in summary.actionItems {
                    lines.append("- \(item.task)")
                }
            }
        } else {
            lines.append(record.fullTranscript)
        }
        return lines.joined(separator: "\n")
    }
}
