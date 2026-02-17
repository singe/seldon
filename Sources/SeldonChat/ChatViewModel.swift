import Foundation
import Combine

@MainActor
final class ChatViewModel: ObservableObject {
    @Published var input: String = ""
    @Published var isSending = false
    @Published var messages: [ChatMessage] = [
        .init(role: .system, text: "Ready. Ask anything and I will use Apple on-device Foundation Models when available.")
    ]

    private let runner: ChatRunner
    private var currentResponseTask: Task<Void, Never>?

    init(runner: ChatRunner = ChatRunner()) {
        self.runner = runner
    }

    func send() {
        let trimmed = input.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty, !isSending else { return }

        input = ""
        isSending = true
        messages.append(.init(role: .user, text: trimmed))
        let assistantMessageID = UUID()
        messages.append(.init(id: assistantMessageID, role: .assistant, text: ""))

        let request = ChatRunRequest(prompt: trimmed, temperature: nil, mode: .streaming)

        currentResponseTask = Task {
            defer {
                isSending = false
                currentResponseTask = nil
            }

            do {
                let response = try await runner.run(request) { token in
                    await MainActor.run {
                        if let index = messages.firstIndex(where: { $0.id == assistantMessageID }) {
                            messages[index].text += token
                        }
                    }
                }

                if let index = messages.firstIndex(where: { $0.id == assistantMessageID }),
                   messages[index].text.isEmpty {
                    messages[index].text = response
                }
            } catch is CancellationError {
                if let index = messages.firstIndex(where: { $0.id == assistantMessageID }),
                   messages[index].text.isEmpty {
                    messages.remove(at: index)
                }
            } catch {
                if let index = messages.firstIndex(where: { $0.id == assistantMessageID }) {
                    messages.remove(at: index)
                }
                messages.append(.init(role: .system, text: "Error: \(error.localizedDescription)"))
            }
        }
    }

    func stop() {
        guard isSending else { return }
        currentResponseTask?.cancel()
    }
}
