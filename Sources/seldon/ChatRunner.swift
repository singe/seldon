import Foundation

enum ChatRunMode {
    case singleShot
    case streaming
}

struct ChatRunRequest {
    let prompt: String
    let temperature: Double?
    let mode: ChatRunMode
}

actor ChatRunner {
    private let modelClient: any ChatModeling

    init(modelClient: any ChatModeling = AppleFoundationModelClient()) {
        self.modelClient = modelClient
    }

    init(loadedTools: LoadedTools?) {
        self.modelClient = AppleFoundationModelClient(loadedTools: loadedTools)
    }

    func run(
        _ request: ChatRunRequest,
        onToken: @Sendable (String) async -> Void = { _ in },
        onToolUse: @escaping @Sendable (String) async -> Void = { _ in }
    ) async throws -> String {
        DebugLog.log("ChatRunner.run enter mode=\(request.mode) temp=\(request.temperature?.description ?? "nil") promptLen=\(request.prompt.count)")
        await ToolCancellationState.shared.reset()
        DebugLog.log("ChatRunner.run after cancel reset")
        let listenerID = await ToolUseEvents.shared.addListener(onToolUse)

        do {
            switch request.mode {
            case .singleShot:
                DebugLog.log("ChatRunner.run singleShot dispatch")
                let output = try await modelClient.send(prompt: request.prompt, temperature: request.temperature)
                DebugLog.log("ChatRunner.run singleShot return len=\(output.count)")
                await ToolUseEvents.shared.removeListener(listenerID)
                return output
            case .streaming:
                DebugLog.log("ChatRunner.run streaming dispatch")
                let output = try await modelClient.stream(
                    prompt: request.prompt,
                    temperature: request.temperature,
                    onToken: onToken
                )
                DebugLog.log("ChatRunner.run streaming return len=\(output.count)")
                await ToolUseEvents.shared.removeListener(listenerID)
                return output
            }
        } catch {
            await ToolUseEvents.shared.removeListener(listenerID)
            throw error
        }
    }
}
