import Foundation
#if canImport(FoundationModels)
import FoundationModels
#endif

protocol ChatModeling: Sendable {
    func send(prompt: String, temperature: Double?) async throws -> String
    func stream(prompt: String, temperature: Double?, onToken: @Sendable (String) async -> Void) async throws -> String
}

actor AppleFoundationModelClient: ChatModeling {
    func send(prompt: String, temperature: Double?) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let session = LanguageModelSession()
            let result: LanguageModelSession.Response<String>
            if let temperature {
                let options = GenerationOptions(temperature: temperature)
                result = try await session.respond(to: prompt, options: options)
            } else {
                result = try await session.respond(to: prompt)
            }
            return result.content
        }
        #endif

        throw ChatClientError.unsupported
    }

    func stream(prompt: String, temperature: Double?, onToken: @Sendable (String) async -> Void) async throws -> String {
        #if canImport(FoundationModels)
        if #available(macOS 26.0, *) {
            let session = LanguageModelSession()
            var contentSoFar = ""

            let stream: LanguageModelSession.ResponseStream<String>
            if let temperature {
                let options = GenerationOptions(temperature: temperature)
                stream = session.streamResponse(to: prompt, options: options)
            } else {
                stream = session.streamResponse(to: prompt)
            }

            for try await partial in stream {
                let current = partial.content
                let delta: String
                if current.hasPrefix(contentSoFar) {
                    delta = String(current.dropFirst(contentSoFar.count))
                } else {
                    delta = current
                }

                contentSoFar = current
                if !delta.isEmpty {
                    await onToken(delta)
                }
            }

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
