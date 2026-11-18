import SwiftUI

struct ContentView: View {
    @Environment(ServerStore.self) private var store
    @Environment(\.horizontalSizeClass) private var sizeClass
    @State private var pendingRemoval: ServerSession?

    var body: some View {
        @Bindable var store = store

        NavigationSplitView {
            List(selection: $store.selection) {
                ForEach(store.sessions) { session in
                    ServerRow(session: session)
                        .tag(session.id)
                        .contextMenu {
                            Button("Remove Server", systemImage: "trash", role: .destructive) {
                                pendingRemoval = session
                            }
                        }
                        .swipeActions {
                            Button("Remove", systemImage: "trash", role: .destructive) {
                                pendingRemoval = session
                            }
                        }
                }
            }
            .navigationTitle("Servers")
            .toolbar {
                ToolbarItem {
                    Button("Add Server", systemImage: "plus") { store.addServer() }
                }
            }
            #if os(macOS)
            .navigationSplitViewColumnWidth(min: 220, ideal: 260, max: 360)
            #endif
        } detail: {
            if let session = store.session(withID: store.selection) {
                ServerDetailView(session: session)
                    .id(session.id)
            } else {
                ContentUnavailableView("No Server Selected", systemImage: "network",
                                       description: Text("Add one with the + button."))
            }
        }
        .alert("Remove Server?", isPresented: Binding(
            get: { pendingRemoval != nil },
            set: { if !$0 { pendingRemoval = nil } }
        ), presenting: pendingRemoval) { session in
            Button("Remove", role: .destructive) { store.remove(session) }
            Button("Cancel", role: .cancel) {}
        } message: { session in
            Text("“\(session.name)” will be stopped and removed.")
        }
        .onAppear {
            if store.selection == nil, sizeClass == .regular {
                store.selection = store.sessions.first?.id
            }
        }
        #if os(iOS)
        // iOS suspends sockets in the background, so keep the screen on while serving.
        .onChange(of: store.anyRunning, initial: true) { _, running in
            UIApplication.shared.isIdleTimerDisabled = running
        }
        #endif
        #if os(macOS)
        .frame(minHeight: 700)
        #endif
    }
}

private struct ServerRow: View {
    let session: ServerSession

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: "circle.fill")
                .font(.system(size: 9))
                .foregroundStyle(session.state == .stopped ? Color.secondary.opacity(0.5) : .green)
            VStack(alignment: .leading, spacing: 2) {
                Text(session.name.isEmpty ? "Untitled" : session.name)
                    .lineLimit(1)
                Text("Port \(String(session.port)) · \(session.clients.count) client\(session.clients.count == 1 ? "" : "s")")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }
}
