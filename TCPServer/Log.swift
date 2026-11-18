import Network
import Observation
import SwiftUI

enum LogKind {
    case info, received, sent, error
}

struct LogLine: Identifiable {
    let id = UUID()
    let date = Date()
    let text: String
    let kind: LogKind
    /// Peer (received) or recipient summary (sent). Nil for plain events.
    let source: String?
    let json: JSONValue?

    var isMessage: Bool { kind == .received || kind == .sent }

    init(text: String, kind: LogKind, source: String? = nil) {
        self.text = text
        self.kind = kind
        self.source = source
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if source != nil, let first = trimmed.first, first == "{" || first == "[",
           let object = try? JSONSerialization.jsonObject(with: Data(trimmed.utf8)) {
            json = JSONValue(object)
        } else {
            json = nil
        }
    }
}

indirect enum JSONValue {
    case object([String: JSONValue])
    case array([JSONValue])
    case string(String)
    case number(Double)
    case bool(Bool)
    case null

    init?(_ any: Any) {
        switch any {
        case let dictionary as [String: Any]:
            var result: [String: JSONValue] = [:]
            for (key, value) in dictionary { result[key] = JSONValue(value) ?? .null }
            self = .object(result)
        case let array as [Any]:
            self = .array(array.map { JSONValue($0) ?? .null })
        case let string as String:
            self = .string(string)
        case let number as NSNumber:
            if CFGetTypeID(number) == CFBooleanGetTypeID() {
                self = .bool(number.boolValue)
            } else {
                self = .number(number.doubleValue)
            }
        case is NSNull:
            self = .null
        default:
            return nil
        }
    }

    /// Child entries of a container, objects sorted by key.
    var children: [(key: String, value: JSONValue)]? {
        switch self {
        case .object(let dictionary):
            return dictionary.keys.sorted().map { ($0, dictionary[$0] ?? .null) }
        case .array(let array):
            return array.enumerated().map { ("[\($0.offset)]", $0.element) }
        default:
            return nil
        }
    }

    var isArray: Bool {
        if case .array = self { return true }
        return false
    }

    /// Path such as `sensor.values[2]`, used as expansion id.
    func childPath(_ path: String, _ key: String) -> String {
        path.isEmpty ? key : (isArray ? path + key : path + "." + key)
    }

    func collectContainerPaths(path: String, into result: inout Set<String>) {
        guard let children else { return }
        result.insert(path)
        for child in children {
            child.value.collectContainerPaths(path: childPath(path, child.key), into: &result)
        }
    }

    var summary: String {
        switch self {
        case .object(let dictionary): return "{\(dictionary.count)}"
        case .array(let array): return "[\(array.count)]"
        case .string(let string): return "\"\(string)\""
        case .number(let number):
            return number == number.rounded() && abs(number) < 1e15 ? String(Int64(number)) : String(number)
        case .bool(let bool): return bool ? "true" : "false"
        case .null: return "null"
        }
    }
}

/// Timestamped activity lines shown in the detail view. Capped so long sessions stay fast.
@MainActor
@Observable
final class ActivityLog {
    private(set) var lines: [LogLine] = []
    @ObservationIgnored private let limit = 5000

    func append(_ text: String, _ kind: LogKind, source: String? = nil) {
        lines.append(LogLine(text: text, kind: kind, source: source))
        if lines.count > limit {
            lines.removeFirst(lines.count - limit * 8 / 10)
        }
    }

    func clear() {
        lines.removeAll()
    }

    /// Raw: message payloads only. Processed: timestamps, direction, peer and events.
    func exportText(raw: Bool) -> String {
        let stamp = Date.ISO8601FormatStyle(dateSeparator: .dash, dateTimeSeparator: .space,
                                            timeSeparator: .colon, timeZone: .current)
        if raw {
            return lines.filter(\.isMessage).map(\.text).joined(separator: "\n") + "\n"
        }
        return lines.map { line in
            let time = line.date.formatted(stamp)
            guard line.isMessage, let source = line.source else { return "\(time)  \(line.text)" }
            return "\(time)  \(line.kind == .sent ? "->" : "<-") \(source)  \(line.text)"
        }.joined(separator: "\n") + "\n"
    }
}

extension NWError {
    var message: String {
        switch self {
        case .posix(let code): return String(cString: strerror(code.rawValue))
        case .dns(let code): return "DNS error \(code)"
        case .tls(let status): return "TLS error \(status)"
        @unknown default: return "\(self)"
        }
    }
}

enum TextDecoding {
    /// UTF-8 first, Latin-1 as a lossless fallback so odd devices still show something.
    static func line(from data: Data) -> String {
        let text = String(data: data, encoding: .utf8) ?? String(data: data, encoding: .isoLatin1) ?? ""
        return text.trimmingCharacters(in: .newlines)
    }
}

struct AlertInfo: Identifiable {
    let id = UUID()
    let title: String
    let text: String
}

extension View {
    func alert(_ info: Binding<AlertInfo?>) -> some View {
        alert(info.wrappedValue?.title ?? "", isPresented: Binding(
            get: { info.wrappedValue != nil },
            set: { if !$0 { info.wrappedValue = nil } }
        )) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(info.wrappedValue?.text ?? "")
        }
    }
}
