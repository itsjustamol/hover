import Foundation
import Combine

/// State backing the lookup popover.
final class LookupModel: ObservableObject {
    enum Phase {
        case loading
        case streaming
        case done
        case error(String)
    }

    struct Exchange: Identifiable {
        let id = UUID()
        /// nil for the initial selection lookup; the user's question for follow-ups.
        var question: String?
        var answer: String = ""
    }

    /// The raw selected text.
    @Published var query: String = ""
    /// Header title — the selection, or an AI-generated title for long selections.
    @Published var title: String = ""
    @Published var exchanges: [Exchange] = []
    @Published var phase: Phase = .loading
    /// Follow-up input field contents.
    @Published var draft: String = ""
    /// Measured height of the rendered transcript, reported by the SwiftUI view
    /// so the panel can grow to fit its content like the Dictionary popover.
    @Published var contentHeight: CGFloat = 0

    /// Conversation in Claude Messages API shape ([{role, content}]).
    var apiMessages: [[String: String]] = []
    /// Set by the app delegate; called when the user submits a follow-up.
    var onFollowUp: ((String) -> Void)?
    /// Set by the panel; called when the user clicks the close control.
    var onClose: (() -> Void)?

    var canSubmitFollowUp: Bool {
        switch phase {
        case .done, .error: return true
        default: return false
        }
    }

    func reset(query: String) {
        self.query = query
        title = query.replacingOccurrences(of: "\n", with: " ")
        exchanges = []
        apiMessages = []
        draft = ""
        contentHeight = 0
        phase = .loading
    }

    func fail(_ message: String) {
        phase = .error(message)
    }
}
