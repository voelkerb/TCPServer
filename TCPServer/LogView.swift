import SwiftUI

#if canImport(UIKit)
import UIKit
private typealias PlatformColor = UIColor
private typealias PlatformFont = UIFont
#else
import AppKit
private typealias PlatformColor = NSColor
private typealias PlatformFont = NSFont
#endif

/// Activity log. Processed mode shows rows with an expandable JSON tree; raw mode shows plain text.
struct LogView: View {
    let log: ActivityLog
    @Binding var follow: Bool
    let raw: Bool

    /// Rendering is capped for speed.
    private static let renderLimit = 1000

    var body: some View {
        Group {
            if raw {
                RawLogView(lines: log.lines.suffix(Self.renderLimit), follow: $follow)
            } else {
                richList
            }
        }
        .background(.background.opacity(0.45), in: .rect(cornerRadius: 12))
    }

    private var richList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 6) {
                    ForEach(log.lines.suffix(Self.renderLimit)) { line in
                        LogRow(line: line).id(line.id)
                    }
                }
                .padding(12)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            }
            .defaultScrollAnchor(.bottom)
            .onChange(of: log.lines.last?.id) { _, lastID in
                if follow, let lastID { proxy.scrollTo(lastID, anchor: .bottom) }
            }
        }
    }
}

private struct LogRow: View {
    let line: LogLine
    @State private var expanded: Set<String> = [""]
    @State private var isOpen = false

    private var color: Color {
        switch line.kind {
        case .received: return .primary
        case .sent: return .accentColor
        case .error: return .red
        case .info: return .secondary
        }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 2) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(line.date, format: .dateTime.hour().minute().second())
                    .foregroundStyle(.tertiary)
                    .monospacedDigit()
                if line.isMessage, let source = line.source {
                    Image(systemName: line.kind == .sent ? "arrow.up.right" : "arrow.down.left")
                        .font(.caption2)
                        .foregroundStyle(color)
                        .accessibilityLabel(line.kind == .sent ? "Sent" : "Received")
                    Text(source).fontWeight(.semibold).foregroundStyle(color)
                    if line.json != nil {
                        Text("JSON")
                            .font(.system(size: 10))
                            .padding(.horizontal, 5)
                            .background(.quaternary, in: .capsule)
                        Button { isOpen.toggle() } label: {
                            Image(systemName: isOpen ? "chevron.down" : "chevron.right").frame(width: 14)
                        }
                        .buttonStyle(.plain)
                        .accessibilityLabel(isOpen ? "Collapse JSON" : "Expand JSON")
                    }
                } else {
                    Text(line.text).foregroundStyle(color)
                }
            }
            if line.isMessage {
                if let json = line.json, isOpen {
                    jsonTree(json)
                } else {
                    Text(line.text)
                        .lineLimit(line.json == nil ? 20 : 1)
                        .padding(.leading, 4)
                }
            }
        }
        .font(.system(size: 12, design: .monospaced))
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private func jsonTree(_ json: JSONValue) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            if json.children?.contains(where: { $0.value.children != nil }) == true {
                HStack(spacing: 12) {
                    Button("Expand All") {
                        var paths = Set<String>()
                        json.collectContainerPaths(path: "", into: &paths)
                        expanded = paths
                    }
                    Button("Collapse All") { expanded = [""] }
                }
                .buttonStyle(.plain)
                .font(.caption)
            }
            if let children = json.children {
                ForEach(children.prefix(500), id: \.key) { child in
                    JSONNodeView(key: child.key, value: child.value,
                                 path: json.childPath("", child.key), expanded: $expanded)
                }
                if children.count > 500 {
                    Text("… \(children.count - 500) more").foregroundStyle(.secondary)
                }
            } else {
                JSONNodeView(key: nil, value: json, path: "", expanded: $expanded)
            }
        }
        .padding(.leading, 4)
    }
}

private struct JSONNodeView: View {
    let key: String?
    let value: JSONValue
    let path: String
    @Binding var expanded: Set<String>

    private static let childLimit = 500

    var body: some View {
        if let children = value.children {
            DisclosureGroup(isExpanded: Binding(
                get: { expanded.contains(path) },
                set: { if $0 { expanded.insert(path) } else { expanded.remove(path) } })
            ) {
                VStack(alignment: .leading, spacing: 2) {
                    ForEach(children.prefix(Self.childLimit), id: \.key) { child in
                        JSONNodeView(key: child.key, value: child.value,
                                     path: value.childPath(path, child.key), expanded: $expanded)
                    }
                    if children.count > Self.childLimit {
                        Text("… \(children.count - Self.childLimit) more").foregroundStyle(.secondary)
                    }
                }
            } label: {
                HStack(spacing: 6) {
                    if let key { Text(key).fontWeight(.semibold) }
                    Text(value.summary).foregroundStyle(.secondary)
                }
            }
        } else {
            HStack(alignment: .firstTextBaseline, spacing: 6) {
                if let key { Text("\(key):").fontWeight(.semibold) }
                Text(value.summary).foregroundStyle(color)
            }
        }
    }

    private var color: Color {
        switch value {
        case .string: .green
        case .number: .blue
        case .bool: .orange
        default: .secondary
        }
    }
}

// MARK: - Raw text

/// Whole log as one selectable native text block, which lays out lazily and handles long logs.
private enum RawLogText {
    static func make(_ lines: ArraySlice<LogLine>) -> NSAttributedString {
        let font = PlatformFont.monospacedSystemFont(ofSize: 12, weight: .regular)
        #if canImport(UIKit)
        let primary = PlatformColor.label, secondary = PlatformColor.secondaryLabel
        let accent = PlatformColor.tintColor
        #else
        let primary = PlatformColor.labelColor, secondary = PlatformColor.secondaryLabelColor
        let accent = PlatformColor.controlAccentColor
        #endif
        let out = NSMutableAttributedString()
        func add(_ text: String, _ color: PlatformColor) {
            out.append(NSAttributedString(string: text, attributes: [.font: font, .foregroundColor: color]))
        }
        for (index, line) in lines.enumerated() {
            if index > 0 { add("\n", primary) }
            add(line.date.formatted(.dateTime.hour().minute().second()) + "  ", secondary)
            guard line.isMessage, let source = line.source else {
                add(line.text, line.kind == .error ? .systemRed : secondary)
                continue
            }
            add((line.kind == .sent ? "↑ " : "↓ ") + source, line.kind == .sent ? accent : primary)
            if line.json != nil { add("  [JSON]", secondary) }
            add("\n    " + line.text.replacingOccurrences(of: "\n", with: "\n    "), primary)
        }
        return out
    }
}

#if canImport(UIKit)

private struct RawLogView: UIViewRepresentable {
    let lines: ArraySlice<LogLine>
    @Binding var follow: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeUIView(context: Context) -> UITextView {
        let view = UITextView(usingTextLayoutManager: false)
        view.isEditable = false
        view.isSelectable = true
        view.backgroundColor = .clear
        view.alwaysBounceVertical = true
        view.textContainerInset = UIEdgeInsets(top: 10, left: 6, bottom: 10, right: 6)
        view.delegate = context.coordinator
        return view
    }

    func updateUIView(_ view: UITextView, context: Context) {
        let coordinator = context.coordinator
        coordinator.follow = $follow
        let signature = Coordinator.Signature(count: lines.count, last: lines.last?.id)
        let changed = coordinator.signature != signature
        if changed {
            coordinator.signature = signature
            view.attributedText = RawLogText.make(lines)
        }
        if follow, changed || coordinator.wasFollowing == false { scrollToEnd(view) }
        coordinator.wasFollowing = follow
    }

    private func scrollToEnd(_ view: UITextView) {
        let length = view.textStorage.length
        guard length > 0 else { return }
        let tail = NSRange(location: max(0, length - 4000), length: min(length, 4000))
        view.layoutManager.ensureLayout(forCharacterRange: tail)
        view.layoutIfNeeded()
        let bottom = view.contentSize.height - view.bounds.height + view.adjustedContentInset.bottom
        view.setContentOffset(CGPoint(x: 0, y: max(-view.adjustedContentInset.top, bottom)), animated: false)
    }

    final class Coordinator: NSObject, UITextViewDelegate {
        struct Signature: Equatable { let count: Int; let last: LogLine.ID? }
        var signature: Signature?
        var follow: Binding<Bool>?
        var wasFollowing: Bool?

        func scrollViewDidScroll(_ scrollView: UIScrollView) {
            guard scrollView.isDragging || scrollView.isDecelerating else { return }
            let atBottom = scrollView.contentOffset.y + scrollView.bounds.height >= scrollView.contentSize.height - 24
            if follow?.wrappedValue != atBottom { follow?.wrappedValue = atBottom }
        }
    }
}

#else

private struct RawLogView: NSViewRepresentable {
    let lines: ArraySlice<LogLine>
    @Binding var follow: Bool

    func makeCoordinator() -> Coordinator { Coordinator() }

    func makeNSView(context: Context) -> NSScrollView {
        let scroll = NSTextView.scrollableTextView()
        guard let view = scroll.documentView as? NSTextView else { return scroll }
        view.isEditable = false
        view.isSelectable = true
        view.drawsBackground = false
        view.textContainerInset = NSSize(width: 6, height: 10)
        scroll.drawsBackground = false
        context.coordinator.observe(scroll)
        return scroll
    }

    func updateNSView(_ scroll: NSScrollView, context: Context) {
        let coordinator = context.coordinator
        coordinator.follow = $follow
        guard let view = scroll.documentView as? NSTextView else { return }
        let signature = Coordinator.Signature(count: lines.count, last: lines.last?.id)
        let changed = coordinator.signature != signature
        if changed {
            coordinator.signature = signature
            view.textStorage?.setAttributedString(RawLogText.make(lines))
        }
        if follow, changed || coordinator.wasFollowing == false { view.scrollToEndOfDocument(nil) }
        coordinator.wasFollowing = follow
    }

    final class Coordinator {
        struct Signature: Equatable { let count: Int; let last: LogLine.ID? }
        var signature: Signature?
        var follow: Binding<Bool>?
        var wasFollowing: Bool?
        private var observer: NSObjectProtocol?

        func observe(_ scroll: NSScrollView) {
            observer = NotificationCenter.default.addObserver(
                forName: NSScrollView.didLiveScrollNotification, object: scroll, queue: .main) { [weak self, weak scroll] _ in
                guard let scroll, let document = scroll.documentView else { return }
                let atBottom = scroll.contentView.bounds.maxY >= document.bounds.maxY - 24
                MainActor.assumeIsolated {
                    if self?.follow?.wrappedValue != atBottom { self?.follow?.wrappedValue = atBottom }
                }
            }
        }

        deinit { if let observer { NotificationCenter.default.removeObserver(observer) } }
    }
}

#endif
