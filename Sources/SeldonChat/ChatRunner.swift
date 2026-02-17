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

    func run(
        _ request: ChatRunRequest,
        onToken: @Sendable (String) async -> Void = { _ in }
    ) async throws -> String {
        switch request.mode {
        case .singleShot:
            return try await modelClient.send(prompt: request.prompt, temperature: request.temperature)
        case .streaming:
            return try await modelClient.stream(
                prompt: request.prompt,
                temperature: request.temperature,
                onToken: onToken
            )
        }
    }
}
