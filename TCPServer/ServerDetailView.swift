import SwiftUI

struct ServerDetailView: View {
    @Environment(ServerStore.self) private var store
    @Bindable var session: ServerSession
    @State private var portText: String
    @State private var message = ""
    @State private var follow = true
    @AppStorage("showRawLog") private var showRaw = false
    @State private var alert: AlertInfo?
    @FocusState private var messageFocused: Bool

    init(session: ServerSession) {
        self.session = session
        _portText = State(initialValue: String(session.port))
    }

    private var statusText: String {
        switch session.state {
        case .stopped: return "Stopped"
        case .starting: return "Starting…"
        case .listening: return "Listening"
        }
    }

    private var idle: Bool { session.state == .stopped }
    private var statusTint: Color {
        switch session.state {
        case .stopped: Color(white: 0.5).opacity(0.6)
        case .starting: .orange
        case .listening: .green
        }
    }

    #if os(iOS)
    @Environment(\.horizontalSizeClass) private var sizeClass
    #endif

    private var receiveCard: some View {
        LogCard(title: "Receive", log: session.log, follow: $follow, raw: $showRaw,
                filename: "\(session.name) log")
            .frame(minHeight: 260, maxHeight: .infinity)
            .layoutPriority(-1)
    }

    @ViewBuilder private var content: some View {
        #if os(iOS)
        if sizeClass == .compact {
            TabView {
                Tab("Connection", systemImage: "network") {
                    VStack(spacing: Layout.cardSpacing) {
                        connectionCard
                        Spacer(minLength: 0)
                    }
                    .padding(Layout.phoneMargin)
                }
                Tab("Activity", systemImage: "list.bullet.rectangle") {
                    VStack(spacing: Layout.cardSpacing) {
                        sendCard.fixedSize(horizontal: false, vertical: true)
                        receiveCard
                    }
                    .padding(Layout.phoneMargin)
                }
            }
        } else {
            stacked
        }
        #else
        stacked
        #endif
    }

    private var stacked: some View {
        VStack(spacing: Layout.cardSpacing) {
            connectionCard.fixedSize(horizontal: false, vertical: true)
            sendCard.fixedSize(horizontal: false, vertical: true)
            receiveCard
        }
        .padding(Layout.outerMargin)
    }

    var body: some View {
        content
        .dismissKeyboardOnTap()
        #if os(macOS)
        .frame(minWidth: 520, maxWidth: .infinity, minHeight: 700, maxHeight: .infinity)
        #else
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        #endif
        .scrollDismissesKeyboard(.interactively)
        .navigationTitle(session.name)
        #if os(iOS)
        .navigationBarTitleDisplayMode(.inline)
        #endif
        .alert($alert)
    }

    private var connectionCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                HStack {
                    CardTitle("Connection")
                    Spacer(minLength: 8)
                    StatusBadge(text: statusText, tint: statusTint)
                }
                .frame(minHeight: 34)
                TextField("Server name", text: $session.name)
                    .textFieldStyle(.roundedBorder)
                    .controlSize(.large)
                ViewThatFits(in: .horizontal) {
                    HStack(spacing: Layout.itemSpacing) { portFields; Spacer(minLength: 0); toggleButton }
                    VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                        HStack(spacing: Layout.itemSpacing) { portFields }
                        HStack { Spacer(minLength: 0); toggleButton }
                    }
                }
                addressRow
            }
        }
    }

    @ViewBuilder private var portFields: some View {
        Text("Port").foregroundStyle(.secondary)
        TextField("2000", text: $portText)
            .textFieldStyle(.roundedBorder)
            .controlSize(.large)
            .multilineTextAlignment(.center)
            .frame(width: 88)
            .disabled(!idle)
            #if os(iOS)
            .keyboardType(.numberPad)
            #endif
            .onChange(of: portText) { _, text in
                if let value = UInt16(text), value > 0 { session.port = value }
            }
    }

    /// Own row so Start/Stop never shifts; copy button like Brokkr.
    @ViewBuilder private var addressRow: some View {
        if session.state == .listening, let address = LocalAddress.ipv4() {
            let text = "\(address):\(String(session.port))"
            HStack(spacing: 8) {
                Text(text)
                    .font(.system(.footnote, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
                    .lineLimit(1)
                    .truncationMode(.middle)
                Button("Copy Address", systemImage: "doc.on.doc") { copy(text) }
                    .labelStyle(.iconOnly)
                    .buttonStyle(.borderless)
                    .help("Copy address")
            }
        }
    }

    private func copy(_ text: String) {
        #if os(macOS)
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
        #else
        UIPasteboard.general.string = text
        #endif
    }

    private var toggleButton: some View {
        Button(action: toggle) {
            Label(idle ? "Start" : "Stop", systemImage: idle ? "bolt.fill" : "bolt.slash.fill")
                .frame(minWidth: 100)
        }
        .buttonStyle(.glassProminent)
        .tint(idle ? Color.accentColor : .red)
        .controlSize(.large)
        .fixedSize()
    }

    private var sendCard: some View {
        Card {
            VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                HStack {
                    CardTitle("Send")
                    Spacer(minLength: 8)
                    Text("\(session.clients.count) client\(session.clients.count == 1 ? "" : "s")")
                        .foregroundStyle(.secondary)
                }
                .frame(minHeight: 34)
                HStack(spacing: Layout.itemSpacing) {
                    TextField("Message to all connected clients", text: $message)
                        .textFieldStyle(.roundedBorder)
                        .controlSize(.large)
                        .focused($messageFocused)
                        .onSubmit(send)
                    Button(action: send) {
                        Label("Send", systemImage: "paperplane.fill").frame(minWidth: 60)
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .fixedSize()
                    .disabled(message.isEmpty || session.state != .listening)
                }
            }
        }
    }

    private func toggle() {
        if session.state != .stopped {
            session.stop()
            return
        }
        guard let value = UInt16(portText), value > 0 else {
            alert = AlertInfo(title: "Invalid Port", text: "Enter a port number between 1 and 65535.")
            return
        }
        session.port = value
        if let other = store.conflictingServer(for: session) {
            alert = AlertInfo(title: "Port in Use",
                              text: "“\(other.name)” is already listening on port \(value).")
            return
        }
        session.start()
    }

    private func send() {
        guard !message.isEmpty, session.state == .listening else { return }
        session.send(message)
        message = ""
        messageFocused = true
    }
}
