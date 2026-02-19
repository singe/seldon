import Foundation

actor SelfTestFakeModel: ChatModeling {
    func send(prompt: String, temperature: Double?) async throws -> String {
        "single-shot"
    }

    func stream(prompt: String, temperature: Double?, onToken: @Sendable (String) async -> Void) async throws -> String {
        await ToolUseEvents.shared.emit(toolName: "calculator")
        await onToken("The answer is ")
        await onToken("42")
        return "The answer is 42"
    }
}

enum SelfTestHarness {
    static func runGUIFlow() async -> Int32 {
        let runner = ChatRunner(modelClient: SelfTestFakeModel())
        let viewModel = ChatViewModel(runner: runner, defaultTemperature: nil)

        await MainActor.run {
            viewModel.input = "what is 6*7"
            viewModel.send()
        }

        let timedOut = await waitUntil(timeout: 3.0) {
            await MainActor.run { !viewModel.isSending }
        }

        if timedOut {
            fputs("SELFTEST_FAIL: timed out waiting for send() completion\n", stderr)
            return 1
        }

        let assistant = await MainActor.run {
            viewModel.messages.last { message in
                if case .assistant = message.role { return true }
                return false
            }
        }

        guard let assistant else {
            fputs("SELFTEST_FAIL: missing assistant message\n", stderr)
            return 1
        }

        guard assistant.text == "The answer is 42" else {
            fputs("SELFTEST_FAIL: assistant text mismatch: \(assistant.text)\n", stderr)
            return 1
        }

        guard assistant.toolNotices.contains("Tool running: calculator") else {
            fputs("SELFTEST_FAIL: missing tool running notice\n", stderr)
            return 1
        }

        print("SELFTEST_OK")
        return 0
    }

    private static func waitUntil(timeout: TimeInterval, condition: @escaping () async -> Bool) async -> Bool {
        let deadline = Date().addingTimeInterval(timeout)
        while Date() < deadline {
            if await condition() {
                return false
            }
            try? await Task.sleep(nanoseconds: 20_000_000)
            await Task.yield()
        }
        return true
    }
}
