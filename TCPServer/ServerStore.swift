import Foundation
import Observation

/// The list of configured servers, persisted in UserDefaults.
@MainActor
@Observable
final class ServerStore {
    private static let defaultsKey = "Servers"
    private static let firstPort: UInt16 = 2000

    private(set) var sessions: [ServerSession] = []
    var selection: ServerSession.ID?

    init() {
        let saved = UserDefaults.standard.array(forKey: Self.defaultsKey) as? [[String: Any]] ?? []
        sessions = saved.compactMap(ServerSession.init(dictionary:))
        if sessions.isEmpty {
            sessions = [makeDefault()]
        }
        sessions.forEach(attach)
        #if os(macOS)
        selection = sessions.first?.id
        #endif
    }

    var anyRunning: Bool {
        sessions.contains { $0.state != .stopped }
    }

    func addServer() {
        let session = makeDefault()
        attach(session)
        sessions.append(session)
        selection = session.id
        save()
    }

    func remove(_ session: ServerSession) {
        session.stop()
        sessions.removeAll { $0 === session }
        if selection == session.id {
            selection = sessions.first?.id
        }
        save()
    }

    func session(withID id: ServerSession.ID?) -> ServerSession? {
        sessions.first { $0.id == id }
    }

    /// Another server that is running (or starting) on the same port.
    func conflictingServer(for session: ServerSession) -> ServerSession? {
        sessions.first { $0 !== session && $0.state != .stopped && $0.port == session.port }
    }

    func stopAll() {
        sessions.forEach { $0.stop() }
    }

    private func attach(_ session: ServerSession) {
        session.persist = { [weak self] in self?.save() }
    }

    private func save() {
        UserDefaults.standard.set(sessions.map(\.dictionary), forKey: Self.defaultsKey)
    }

    private func makeDefault() -> ServerSession {
        var number = 1
        var port = Self.firstPort
        while true {
            let name = "Server \(number)"
            if sessions.contains(where: { $0.name == name }) {
                number += 1
            } else if sessions.contains(where: { $0.port == port }) {
                port += 1
            } else {
                return ServerSession(name: name, port: port)
            }
        }
    }
}
