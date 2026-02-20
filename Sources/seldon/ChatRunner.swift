import Foundation

enum ChatRunMode {
    case singleShot
    case streaming
}

struct ChatRunRequest {
    let prompt: String
    let temperature: Double?
    let mode: ChatRunMode
    let toolsEnabled: Bool

    init(prompt: String, temperature: Double?, mode: ChatRunMode, toolsEnabled: Bool = true) {
        self.prompt = prompt
        self.temperature = temperature
        self.mode = mode
        self.toolsEnabled = toolsEnabled
    }
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
        DebugLog.log("ChatRunner.run enter mode=\(request.mode) toolsEnabled=\(request.toolsEnabled) temp=\(request.temperature?.description ?? "nil") promptLen=\(request.prompt.count)")
        await ToolCancellationState.shared.reset()
        DebugLog.log("ChatRunner.run after cancel reset")
        let listenerID = await ToolUseEvents.shared.addListener(onToolUse)

        do {
            switch request.mode {
            case .singleShot:
                DebugLog.log("ChatRunner.run singleShot dispatch")
                let output = try await modelClient.send(
                    prompt: request.prompt,
                    temperature: request.temperature,
                    toolsEnabled: request.toolsEnabled
                )
                DebugLog.log("ChatRunner.run singleShot return len=\(output.count)")
                await ToolUseEvents.shared.removeListener(listenerID)
                return output
            case .streaming:
                DebugLog.log("ChatRunner.run streaming dispatch")
                let output = try await modelClient.stream(
                    prompt: request.prompt,
                    temperature: request.temperature,
                    toolsEnabled: request.toolsEnabled,
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
