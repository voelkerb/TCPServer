import SwiftUI
import UniformTypeIdentifiers

/// Shared layout constants, same family as Brokio.
enum Layout {
    static let outerMargin: CGFloat = 16
    static let cardSpacing: CGFloat = 12
    static let cardInset: CGFloat = 16
    static let itemSpacing: CGFloat = 12
    static let cardRadius: CGFloat = 22
    static let phoneMargin: CGFloat = 12
}

/// Material card with a hairline border.
struct Card<Content: View>: View {
    @ViewBuilder var content: Content

    var body: some View {
        content
            .padding(Layout.cardInset)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.regularMaterial, in: .rect(cornerRadius: Layout.cardRadius))
            .overlay(RoundedRectangle(cornerRadius: Layout.cardRadius).strokeBorder(.white.opacity(0.08)))
    }
}

/// Same height and padding for every card title.
struct CardTitle: View {
    let text: LocalizedStringKey
    init(_ text: LocalizedStringKey) { self.text = text }

    var body: some View {
        Text(text)
            .font(.system(size: 15, weight: .semibold))
            .lineLimit(1)
            .fixedSize()
            .frame(minHeight: 34, alignment: .leading)
    }
}

/// Dot plus state text.
struct StatusBadge: View {
    let text: String
    let tint: Color

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "circle.fill").font(.system(size: 8)).foregroundStyle(tint)
            Text(text).foregroundStyle(.secondary).lineLimit(1)
        }
        .accessibilityElement(children: .combine)
    }
}

/// Icon only on compact widths (iPhone), icon and text elsewhere.
struct ToggleableLabelStyle: LabelStyle {
    let iconOnly: Bool

    func makeBody(configuration: Configuration) -> some View {
        if iconOnly {
            configuration.icon
        } else {
            Label { configuration.title } icon: { configuration.icon }
        }
    }
}

struct TextFile: FileDocument {
    static let readableContentTypes: [UTType] = [.plainText]
    var text: String

    init(text: String) { self.text = text }

    init(configuration: ReadConfiguration) throws {
        text = String(decoding: configuration.file.regularFileContents ?? Data(), as: UTF8.self)
    }

    func fileWrapper(configuration: WriteConfiguration) throws -> FileWrapper {
        FileWrapper(regularFileWithContents: Data(text.utf8))
    }
}

/// Receive card: title, switches, export and clear above the log.
struct LogCard: View {
    let title: LocalizedStringKey
    let log: ActivityLog
    @Binding var follow: Bool
    @Binding var raw: Bool
    let filename: String
    @State private var exporting = false
    @State private var document = TextFile(text: "")
    @Environment(\.horizontalSizeClass) private var sizeClass

    private var compact: Bool { sizeClass == .compact }

    var body: some View {
        Card {
            VStack(alignment: .leading, spacing: Layout.itemSpacing) {
                header
                LogView(log: log, follow: $follow, raw: raw)
                    .frame(maxHeight: .infinity)
            }
        }
        .fileExporter(isPresented: $exporting, document: document,
                      contentType: .plainText, defaultFilename: filename) { _ in }
    }

    private var header: some View {
        HStack(spacing: Layout.itemSpacing) {
            CardTitle(title)
            Spacer(minLength: 8)
            if compact {
                Toggle("Auto-scroll", isOn: $follow)
                    .toggleStyle(.switch)
                    .fixedSize()
                actionsMenu
            } else {
                ViewThatFits(in: .horizontal) {
                    fullHeader
                    iconHeader
                }
            }
        }
        .frame(minHeight: 34)
    }

    private var switches: some View {
        HStack(spacing: Layout.itemSpacing) {
            Toggle("Raw", isOn: $raw).toggleStyle(.switch).fixedSize()
                .help("Raw text instead of processed JSON")
            Toggle("Auto-scroll", isOn: $follow).toggleStyle(.switch).fixedSize()
        }
    }

    private func actions(iconOnly: Bool) -> some View {
        HStack(spacing: 8) {
            Button(action: export) {
                Label("Export", systemImage: "square.and.arrow.up")
                    .labelStyle(ToggleableLabelStyle(iconOnly: iconOnly))
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            .disabled(log.lines.isEmpty)
            .help("Export as text")
            Button(role: .destructive) { log.clear() } label: {
                Label("Clear", systemImage: "trash")
                    .labelStyle(ToggleableLabelStyle(iconOnly: iconOnly))
            }
            .buttonStyle(.glass)
            .controlSize(.large)
            .help("Clear log")
        }
        .fixedSize()
    }

    private var fullHeader: some View {
        HStack(spacing: Layout.itemSpacing) { switches; actions(iconOnly: false) }
    }

    private var iconHeader: some View {
        HStack(spacing: Layout.itemSpacing) { switches; actions(iconOnly: true) }
    }

    /// iPhone: Raw, Export and Clear live in a menu.
    private var actionsMenu: some View {
        Menu {
            Toggle("Raw", isOn: $raw)
            Button(action: export) { Label("Export", systemImage: "square.and.arrow.up") }
                .disabled(log.lines.isEmpty)
            Button(role: .destructive) { log.clear() } label: { Label("Clear", systemImage: "trash") }
        } label: {
            Image(systemName: "ellipsis")
                .frame(width: 44, height: 31)
                .glassEffect(.regular.interactive(), in: .capsule)
        }
        .menuStyle(.button)
        .buttonStyle(.plain)
        .fixedSize()
        .accessibilityLabel("Log actions")
    }

    private func export() {
        document = TextFile(text: log.exportText(raw: raw))
        exporting = true
    }
}

extension View {
    /// iOS: tapping outside a text field dismisses the keyboard.
    @ViewBuilder func dismissKeyboardOnTap() -> some View {
        #if os(iOS)
        contentShape(Rectangle())
            .onTapGesture {
                UIApplication.shared.sendAction(#selector(UIResponder.resignFirstResponder), to: nil, from: nil, for: nil)
            }
        #else
        self
        #endif
    }
}
