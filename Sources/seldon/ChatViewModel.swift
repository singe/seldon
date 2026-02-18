import Foundation
import Combine

final class ChatViewModel: ObservableObject {
    @Published var input: String = ""
    @Published var isSending = false
    @Published var messages: [ChatMessage] = [
        .init(role: .system, text: "Ready. Ask anything and I will use Apple on-device Foundation Models when available.")
    ]

    private let runner: ChatRunner
    private let defaultTemperature: Double?
    private var currentResponseTask: Task<Void, Never>?

    init(runner: ChatRunner = ChatRunner(), defaultTemperature: Double? = nil) {
        self.runner = runner
        self.defaultTemperature = defaultTemperature
    }

    func send() {
        guard let trimmed = ChatTextUtilities.normalizePrompt(input), !isSending else { return }

        input = ""
        isSending = true
        messages.append(.init(role: .user, text: trimmed))
        let assistantMessageID = UUID()
        messages.append(.init(id: assistantMessageID, role: .assistant, text: ""))
        DebugLog.log("GUI send() started promptLen=\(trimmed.count) messageID=\(assistantMessageID.uuidString)")

        let request = ChatRunRequest(prompt: trimmed, temperature: defaultTemperature, mode: .streaming)
        let runner = self.runner
        DebugLog.log("GUI creating detached response task")

        currentResponseTask = Task.detached(priority: .userInitiated) { [weak self] in
            guard let self else {
                DebugLog.log("GUI detached task aborted: self deallocated before start")
                return
            }
            let vm = self

            do {
                DebugLog.log("GUI detached task entered")
                await ToolCancellationState.shared.reset()
                DebugLog.log("GUI detached task after ToolCancellationState.reset")

                let response = try await runner.run(request) { token in
                    DebugLog.verbose("GUI onToken received tokenLen=\(token.count)")
                    guard !token.isEmpty else { return }
                    if let index = vm.messages.firstIndex(where: { $0.id == assistantMessageID }) {
                        var updated = vm.messages
                        updated[index].text += token
                        vm.messages = updated
                        DebugLog.verbose("GUI onToken appended totalLen=\(vm.messages[index].text.count)")
                    } else {
                        DebugLog.log("GUI token target missing id=\(assistantMessageID.uuidString)")
                    }
                }

                DebugLog.log("GUI detached task completed responseLen=\(response.count)")
                if let index = vm.messages.firstIndex(where: { $0.id == assistantMessageID }), vm.messages[index].text.isEmpty {
                    var updated = vm.messages
                    updated[index].text = response
                    vm.messages = updated
                    DebugLog.log("GUI fallback applied responseLen=\(response.count)")
                }
                vm.finishSendTask()
            } catch is CancellationError {
                DebugLog.log("GUI detached task cancelled")
                if let index = vm.messages.firstIndex(where: { $0.id == assistantMessageID }), vm.messages[index].text.isEmpty {
                    vm.messages.remove(at: index)
                }
                vm.finishSendTask()
            } catch {
                DebugLog.log("GUI detached task error type=\(String(describing: type(of: error))) message=\(error.localizedDescription)")
                if let index = vm.messages.firstIndex(where: { $0.id == assistantMessageID }) {
                    vm.messages.remove(at: index)
                }
                vm.messages.append(.init(role: .system, text: "Error: \(error.localizedDescription)"))
                vm.finishSendTask()
            }
        }
    }

    func stop() {
        guard isSending else { return }
        DebugLog.log("GUI stop() requested currentResponseTaskNil=\(currentResponseTask == nil)")
        Task {
            await ToolCancellationState.shared.requestCancel()
        }
        currentResponseTask?.cancel()
    }

    private func finishSendTask() {
        DebugLog.log("GUI finishSendTask: setting isSending=false")
        isSending = false
        currentResponseTask = nil
    }
}

extension ChatViewModel: @unchecked Sendable {}
