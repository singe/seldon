import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

protocol ChatModeling: Sendable {
    func send(prompt: String, temperature: Double?) async throws -> String
    func stream(prompt: String, temperature: Double?, onToken: @Sendable (String) async -> Void) async throws -> String
}

actor AppleFoundationModelClient: ChatModeling {
    private let loadedTools: LoadedTools?

    init(loadedTools: LoadedTools? = nil) {
        self.loadedTools = loadedTools
    }

    func send(prompt: String, temperature: Double?) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let tools = FoundationToolFactory.makeTools(from: loadedTools)
            DebugLog.log("send() start tools=\(tools.count) temp=\(temperature?.description ?? "nil") promptLen=\(prompt.count)")
            let session = LanguageModelSession(tools: tools)
            let result: LanguageModelSession.Response<String>
            if let temperature {
                let options = GenerationOptions(temperature: temperature)
                result = try await session.respond(to: prompt, options: options)
            } else {
                result = try await session.respond(to: prompt)
            }
            DebugLog.log("send() complete contentLen=\(result.content.count)")
            return result.content
        }
        #endif

        throw ChatClientError.unsupported
    }

    func stream(prompt: String, temperature: Double?, onToken: @Sendable (String) async -> Void) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let tools = FoundationToolFactory.makeTools(from: loadedTools)
            DebugLog.log("stream() start tools=\(tools.count) temp=\(temperature?.description ?? "nil") promptLen=\(prompt.count)")
            let session = LanguageModelSession(tools: tools)
            var contentSoFar = ""
            var ignoredInitialNull = false
            var snapshotCount = 0
            var tokenCount = 0

            let stream: LanguageModelSession.ResponseStream<String>
            if let temperature {
                let options = GenerationOptions(temperature: temperature)
                stream = session.streamResponse(to: prompt, options: options)
            } else {
                stream = session.streamResponse(to: prompt)
            }

            for try await partial in stream {
                let current = partial.content
                snapshotCount += 1
                if snapshotCount == 1 || snapshotCount % 20 == 0 {
                    DebugLog.verbose("stream() snapshot #\(snapshotCount) currentLen=\(current.count)")
                }

                // During tool-calling the model can emit a transient literal "null"
                // before rewriting the response. Ignore that provisional token.
                if contentSoFar.isEmpty && current == "null" && !ignoredInitialNull {
                    ignoredInitialNull = true
                    continue
                }

                let delta: String
                if current.hasPrefix(contentSoFar) {
                    delta = String(current.dropFirst(contentSoFar.count))
                } else {
                    delta = current
                }

                contentSoFar = current
                if !delta.isEmpty {
                    tokenCount += 1
                    if tokenCount == 1 || tokenCount % 20 == 0 {
                        DebugLog.verbose("stream() token #\(tokenCount) deltaLen=\(delta.count) totalLen=\(contentSoFar.count)")
                    }
                    await onToken(delta)
                }
            }

            DebugLog.log("stream() complete snapshots=\(snapshotCount) tokens=\(tokenCount) finalLen=\(contentSoFar.count)")
            return contentSoFar
        }
        #endif

        throw ChatClientError.unsupported
    }
}

enum ChatClientError: LocalizedError {
    case unsupported

    var errorDescription: String? {
        "Apple Foundation Models are unavailable in this SDK or on this macOS version."
    }
}
