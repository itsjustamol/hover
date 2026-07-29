import SwiftUI
import AppKit

/// The popover content — native SwiftUI in the macOS 26 Liquid Glass style:
/// a glass sheet with the header + streamed transcript, and a separate
/// floating glass capsule for follow-up questions, grouped in a
/// GlassEffectContainer so the shapes blend the way system UI does.
struct LookupView: View {
    @ObservedObject var model: LookupModel

    var body: some View {
        chrome
            .frame(width: LookupPanel.panelWidth, alignment: .topLeading)
    }

    @ViewBuilder
    private var chrome: some View {
        if #available(macOS 26.0, *) {
            GlassEffectContainer(spacing: 10) {
                VStack(spacing: 10) {
                    mainCard
                        .glassEffect(.regular, in: .rect(cornerRadius: 18))
                    followUpBar
                        .glassEffect(.regular.interactive(), in: .capsule)
                }
            }
        } else {
            // Pre-Tahoe fallback: single card with the classic popover blur.
            VStack(alignment: .leading, spacing: 0) {
                mainCard
                Divider().padding(.horizontal, 14)
                followUpBar
            }
            .background(VisualEffectBackground())
            .clipShape(RoundedRectangle(cornerRadius: 12, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 12, style: .continuous)
                    .strokeBorder(Color.primary.opacity(0.12), lineWidth: 0.5)
            )
        }
    }

    private var mainCard: some View {
        VStack(alignment: .leading, spacing: 0) {
            header
                .padding(.horizontal, 16)
                .padding(.top, 12)
                .padding(.bottom, 8)

            Divider()
                .opacity(0.5)
                .padding(.horizontal, 16)

            ScrollViewReader { proxy in
                ScrollView(.vertical, showsIndicators: false) {
                    VStack(alignment: .leading, spacing: 0) {
                        transcript
                        Color.clear.frame(height: 1).id("bottom")
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .frame(maxWidth: .infinity, alignment: .topLeading)
                    .background(
                        GeometryReader { geo in
                            Color.clear.preference(key: ContentHeightKey.self, value: geo.size.height)
                        }
                    )
                }
                .onPreferenceChange(ContentHeightKey.self) { model.contentHeight = $0 }
                .onChange(of: model.exchanges.last?.answer.count ?? 0) { _, _ in
                    proxy.scrollTo("bottom", anchor: .bottom)
                }
            }
        }
    }

    private var header: some View {
        HStack(spacing: 7) {
            Image(systemName: "text.magnifyingglass")
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(.secondary)
            Text(model.title)
                .font(.headline)
                .lineLimit(1)
                .truncationMode(.tail)
            Spacer(minLength: 0)
            if isBusy {
                ProgressView()
                    .controlSize(.small)
            }
        }
    }

    private var isBusy: Bool {
        switch model.phase {
        case .loading, .streaming: return true
        default: return false
        }
    }

    @ViewBuilder
    private var transcript: some View {
        VStack(alignment: .leading, spacing: 10) {
            ForEach(model.exchanges) { exchange in
                if let question = exchange.question {
                    Text(question)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .textSelection(.enabled)
                }
                if exchange.answer.isEmpty {
                    if isBusy && exchange.id == model.exchanges.last?.id {
                        Text("Thinking…")
                            .font(.body)
                            .foregroundStyle(.tertiary)
                    }
                } else {
                    Text(exchange.answer)
                        .font(.body)
                        .lineSpacing(2)
                        .foregroundStyle(.primary)
                        .textSelection(.enabled)
                }
            }
            if case .error(let message) = model.phase {
                Text(message)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .textSelection(.enabled)
            }
        }
    }

    private var followUpBar: some View {
        HStack(spacing: 8) {
            Image(systemName: "sparkles")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            TextField("Ask a follow-up…", text: $model.draft)
                .textFieldStyle(.plain)
                .font(.body)
                .onSubmit(submitFollowUp)
                .disabled(!model.canSubmitFollowUp)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
    }

    private func submitFollowUp() {
        let question = model.draft.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !question.isEmpty, model.canSubmitFollowUp else { return }
        model.draft = ""
        model.onFollowUp?(question)
    }
}

private struct ContentHeightKey: PreferenceKey {
    static var defaultValue: CGFloat = 0
    static func reduce(value: inout CGFloat, nextValue: () -> CGFloat) {
        value = max(value, nextValue())
    }
}

/// Pre-Tahoe fallback: behind-window blur, same material as system popovers.
private struct VisualEffectBackground: NSViewRepresentable {
    func makeNSView(context: NSViewRepresentableContext<VisualEffectBackground>) -> NSVisualEffectView {
        let view = NSVisualEffectView()
        view.material = .popover
        view.blendingMode = .behindWindow
        view.state = .active
        return view
    }

    func updateNSView(_ nsView: NSVisualEffectView, context: NSViewRepresentableContext<VisualEffectBackground>) {}
}
