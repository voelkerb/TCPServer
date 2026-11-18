import Foundation
import Network
import Observation

enum ServerState {
    case stopped, starting, listening
}

final class ClientConnection {
    let id = UUID()
    let peer: String
    let connection: NWConnection
    var buffer = Data()

    init(peer: String, connection: NWConnection) {
        self.peer = peer
        self.connection = connection
    }
}

/// One TCP listener with its clients and activity log.
@MainActor
@Observable
final class ServerSession: Identifiable {
    let id = UUID()
    var name: String { didSet { persist?() } }
    var port: UInt16 { didSet { persist?() } }
    private(set) var state: ServerState = .stopped
    private(set) var clients: [ClientConnection] = []
    let log = ActivityLog()

    @ObservationIgnored var persist: (() -> Void)?
    @ObservationIgnored private var listener: NWListener?

    init(name: String, port: UInt16) {
        self.name = name
        self.port = port
    }

    convenience init?(dictionary: [String: Any]) {
        guard let name = dictionary["name"] as? String,
              let port = dictionary["port"] as? Int,
              let value = UInt16(exactly: port) else { return nil }
        self.init(name: name, port: value)
    }

    var dictionary: [String: Any] {
        ["name": name, "port": Int(port)]
    }

    // MARK: Lifecycle

    func start() {
        guard state == .stopped, let nwPort = NWEndpoint.Port(rawValue: port) else { return }

        let parameters = NWParameters.tcp
        parameters.allowLocalEndpointReuse = true
        let listener: NWListener
        do {
            listener = try NWListener(using: parameters, on: nwPort)
        } catch {
            log.append("Could not listen on port \(port): \(error.localizedDescription)", .error)
            return
        }

        self.listener = listener
        state = .starting
        listener.stateUpdateHandler = { [weak self, weak listener] newState in
            MainActor.assumeIsolated {
                guard let self, let listener, self.listener === listener else { return }
                self.listenerStateChanged(newState)
            }
        }
        listener.newConnectionHandler = { [weak self, weak listener] connection in
            MainActor.assumeIsolated {
                guard let self, let listener, self.listener === listener else {
                    connection.cancel()
                    return
                }
                self.accept(connection)
            }
        }
        listener.start(queue: .main)
    }

    func stop() {
        guard state != .stopped else { return }
        teardown()
        log.append("Server stopped", .info)
    }

    private func teardown() {
        listener?.stateUpdateHandler = nil
        listener?.newConnectionHandler = nil
        listener?.cancel()
        listener = nil
        for client in clients {
            client.connection.stateUpdateHandler = nil
            client.connection.cancel()
        }
        clients.removeAll()
        state = .stopped
    }

    private func listenerStateChanged(_ newState: NWListener.State) {
        switch newState {
        case .ready:
            state = .listening
            log.append("Listening on port \(port)", .info)
        case .failed(let error), .waiting(let error):
            log.append("Could not listen on port \(port): \(error.message)", .error)
            teardown()
        default:
            break
        }
    }

    // MARK: Clients

    private func accept(_ connection: NWConnection) {
        let client = ClientConnection(peer: Self.describe(connection.endpoint), connection: connection)
        clients.append(client)
        log.append("Client connected: \(client.peer)", .info)

        connection.stateUpdateHandler = { [weak self, weak client] newState in
            MainActor.assumeIsolated {
                guard let self, let client else { return }
                switch newState {
                case .failed, .cancelled: self.drop(client)
                default: break
                }
            }
        }
        connection.start(queue: .main)
        receive(from: client)
    }

    private func receive(from client: ClientConnection) {
        client.connection.receive(minimumIncompleteLength: 1, maximumLength: 65_536) { [weak self, weak client] data, _, isComplete, error in
            MainActor.assumeIsolated {
                guard let self, let client, self.clients.contains(where: { $0 === client }) else { return }
                if let data, !data.isEmpty {
                    self.consume(data, from: client)
                }
                if isComplete || error != nil {
                    client.connection.cancel()
                    self.drop(client)
                } else {
                    self.receive(from: client)
                }
            }
        }
    }

    private func consume(_ data: Data, from client: ClientConnection) {
        client.buffer.append(data)
        while let newline = client.buffer.firstIndex(of: 0x0A) {
            let line = client.buffer[client.buffer.startIndex..<newline]
            client.buffer.removeSubrange(client.buffer.startIndex...newline)
            log.append(TextDecoding.line(from: Data(line)), .received, source: client.peer)
        }
    }

    private func drop(_ client: ClientConnection) {
        guard let index = clients.firstIndex(where: { $0 === client }) else { return }
        clients.remove(at: index)
        client.connection.stateUpdateHandler = nil
        if !client.buffer.isEmpty {
            log.append(TextDecoding.line(from: client.buffer), .received, source: client.peer)
        }
        log.append("Client disconnected: \(client.peer)", .info)
    }

    // MARK: Sending

    @discardableResult
    func send(_ line: String) -> Int {
        guard !clients.isEmpty else {
            log.append("No clients connected, message not sent", .error)
            return 0
        }
        let data = Data((line + "\n").utf8)
        for client in clients {
            client.connection.send(content: data, completion: .contentProcessed { _ in })
        }
        log.append(line, .sent, source: "To \(clients.count) client\(clients.count == 1 ? "" : "s")")
        return clients.count
    }

    private static func describe(_ endpoint: NWEndpoint) -> String {
        guard case .hostPort(let host, let port) = endpoint else { return "\(endpoint)" }
        var address = "\(host)"
        if let scope = address.firstIndex(of: "%") {
            address = String(address[..<scope])
        }
        return "\(address):\(port.rawValue)"
    }
}
