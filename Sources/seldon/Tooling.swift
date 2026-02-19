import Foundation
import Yams
#if canImport(FoundationModels)
import FoundationModels
#endif

struct LoadedTools: Sendable {
    let definitions: [ExternalToolDefinition]
    let sourcePath: String
}

struct ExternalToolDefinition: Sendable {
    let name: String
    let description: String
    let parameters: [ExternalToolParameter]
    let command: String
    let args: [String]
}

struct ExternalToolParameter: Sendable {
    enum Kind: String, Sendable {
        case string
        case integer
        case number
        case boolean
    }

    let name: String
    let description: String
    let kind: Kind
    let required: Bool
}

actor ToolUseEvents {
    static let shared = ToolUseEvents()

    typealias Listener = @Sendable (String) async -> Void
    private var listeners: [UUID: Listener] = [:]

    func addListener(_ listener: @escaping Listener) -> UUID {
        let id = UUID()
        listeners[id] = listener
        return id
    }

    func removeListener(_ id: UUID) {
        listeners.removeValue(forKey: id)
    }

    func emit(toolName: String) async {
        let active = listeners.values
        for listener in active {
            await listener(toolName)
        }
    }
}

enum ToolsConfigLoader {
    static func load(from path: String) throws -> LoadedTools {
        let expanded = NSString(string: path).expandingTildeInPath
        let url = URL(fileURLWithPath: expanded)

        guard FileManager.default.fileExists(atPath: url.path) else {
            throw ToolsConfigError("Tools file not found at '\(path)'.")
        }

        let yaml: String
        do {
            yaml = try String(contentsOf: url, encoding: .utf8)
        } catch {
            throw ToolsConfigError("Unable to read tools file '\(path)': \(error.localizedDescription)")
        }

        let parsed: ToolFileConfig
        do {
            parsed = try YAMLDecoder().decode(ToolFileConfig.self, from: yaml)
        } catch {
            throw ToolsConfigError("Unable to parse tools YAML '\(path)': \(error.localizedDescription)")
        }

        let definitions = try validateAndMap(parsed.tools)
        return LoadedTools(definitions: definitions, sourcePath: url.path)
    }

    private static func validateAndMap(_ tools: [RawToolConfig]) throws -> [ExternalToolDefinition] {
        guard !tools.isEmpty else {
            throw ToolsConfigError("Tools file defines no tools. Add at least one entry under 'tools:'.")
        }

        var names = Set<String>()
        return try tools.map { raw in
            let name = raw.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let description = raw.description.trimmingCharacters(in: .whitespacesAndNewlines)
            let command = raw.command.trimmingCharacters(in: .whitespacesAndNewlines)

            guard !name.isEmpty else { throw ToolsConfigError("Each tool requires a non-empty 'name'.") }
            guard names.insert(name).inserted else { throw ToolsConfigError("Duplicate tool name '\(name)'.") }
            guard !description.isEmpty else { throw ToolsConfigError("Tool '\(name)' requires a non-empty 'description'.") }
            guard !command.isEmpty else { throw ToolsConfigError("Tool '\(name)' requires a non-empty 'command'.") }

            let parameters = try mapParameters(raw.parameters, toolName: name)
            let parameterNames = Set(parameters.map(\.name))
            try validatePlaceholders(raw.args, toolName: name, knownParameters: parameterNames)

            return ExternalToolDefinition(
                name: name,
                description: description,
                parameters: parameters,
                command: command,
                args: raw.args
            )
        }
    }

    private static func mapParameters(_ parameters: [RawToolParameter], toolName: String) throws -> [ExternalToolParameter] {
        var names = Set<String>()

        return try parameters.map { raw in
            let name = raw.name.trimmingCharacters(in: .whitespacesAndNewlines)
            let description = raw.description.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !name.isEmpty else { throw ToolsConfigError("Tool '\(toolName)' has a parameter with an empty 'name'.") }
            guard names.insert(name).inserted else { throw ToolsConfigError("Tool '\(toolName)' has duplicate parameter '\(name)'.") }
            guard !description.isEmpty else { throw ToolsConfigError("Tool '\(toolName)' parameter '\(name)' requires a non-empty 'description'.") }

            guard let kind = ExternalToolParameter.Kind(rawValue: raw.type.lowercased()) else {
                throw ToolsConfigError("Tool '\(toolName)' parameter '\(name)' has unsupported type '\(raw.type)'. Use string, integer, number, or boolean.")
            }

            return ExternalToolParameter(
                name: name,
                description: description,
                kind: kind,
                required: raw.required ?? false
            )
        }
    }

    private static func validatePlaceholders(_ args: [String], toolName: String, knownParameters: Set<String>) throws {
        for arg in args {
            for placeholder in PlaceholderRenderer.placeholders(in: arg) {
                guard knownParameters.contains(placeholder) else {
                    throw ToolsConfigError("Tool '\(toolName)' references unknown placeholder '{{\(placeholder)}}' in args.")
                }
            }
        }
    }
}

enum PlaceholderRenderer {
    private static let pattern = #"\{\{\s*([A-Za-z0-9_\-]+)\s*\}\}"#

    static func placeholders(in text: String) -> [String] {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return [] }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        return regex.matches(in: text, options: [], range: range).compactMap { match in
            guard let capture = Range(match.range(at: 1), in: text) else { return nil }
            return String(text[capture])
        }
    }

    static func render(_ text: String, with values: [String: String]) throws -> String {
        guard let regex = try? NSRegularExpression(pattern: pattern) else { return text }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        let matches = regex.matches(in: text, options: [], range: range).reversed()

        var output = text
        for match in matches {
            guard let capture = Range(match.range(at: 1), in: text) else { continue }
            let key = String(text[capture])
            guard let value = values[key] else {
                throw ToolsConfigError("Missing value for placeholder '{{\(key)}}'.")
            }
            guard let fullRange = Range(match.range(at: 0), in: output) else { continue }
            output.replaceSubrange(fullRange, with: value)
        }
        return output
    }
}

actor ToolCancellationState {
    static let shared = ToolCancellationState()
    private var cancelRequested = false

    func reset() {
        cancelRequested = false
    }

    func requestCancel() {
        cancelRequested = true
    }

    func isCancelRequested() -> Bool {
        cancelRequested
    }
}

enum ExternalToolExecutor {
    private static let maxOutputCharacters = 32_000

    static func execute(tool: ExternalToolDefinition, arguments: [String: String], timeout: TimeInterval = 20) async throws -> String {
        let renderedArgs = try tool.args.map { try PlaceholderRenderer.render($0, with: arguments) }
        let cwd = URL(fileURLWithPath: FileManager.default.currentDirectoryPath)
        DebugLog.log("tool execute start name=\(tool.name) cmd=\(tool.command) args=\(renderedArgs.joined(separator: " "))")

        let process = Process()
        process.currentDirectoryURL = cwd

        if tool.command.contains("/") {
            process.executableURL = URL(fileURLWithPath: tool.command, relativeTo: cwd).standardizedFileURL
            process.arguments = renderedArgs
        } else {
            process.executableURL = URL(fileURLWithPath: "/usr/bin/env")
            process.arguments = [tool.command] + renderedArgs
        }

        let stdout = Pipe()
        let stderr = Pipe()
        process.standardOutput = stdout
        process.standardError = stderr

        do {
            try process.run()
        } catch {
            throw ToolsConfigError("Failed to run tool '\(tool.name)': \(error.localizedDescription)")
        }

        let started = Date()
        while process.isRunning {
            let cancelRequested = await ToolCancellationState.shared.isCancelRequested()
            if Task.isCancelled || cancelRequested {
                process.terminate()
                DebugLog.log("tool execute cancelled name=\(tool.name)")
                throw CancellationError()
            }
            if Date().timeIntervalSince(started) > timeout {
                process.terminate()
                DebugLog.log("tool execute timeout name=\(tool.name)")
                throw ToolsConfigError("Tool '\(tool.name)' timed out after \(Int(timeout))s.")
            }
            try await Task.sleep(nanoseconds: 100_000_000)
        }

        let output = String(decoding: stdout.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)
        let errorOutput = String(decoding: stderr.fileHandleForReading.readDataToEndOfFile(), as: UTF8.self)

        if process.terminationStatus != 0 {
            let reason = errorOutput.isEmpty ? "Exited with status \(process.terminationStatus)." : errorOutput.trimmingCharacters(in: .whitespacesAndNewlines)
            DebugLog.log("tool execute failed name=\(tool.name) status=\(process.terminationStatus) stderrLen=\(errorOutput.count)")
            throw ToolsConfigError("Tool '\(tool.name)' failed: \(reason)")
        }

        let combined = output.trimmingCharacters(in: .whitespacesAndNewlines)
        DebugLog.log("tool execute complete name=\(tool.name) stdoutLen=\(combined.count)")
        if !combined.isEmpty {
            return truncate(combined)
        }
        return truncate(errorOutput.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    private static func truncate(_ text: String) -> String {
        guard text.count > maxOutputCharacters else { return text }
        return String(text.prefix(maxOutputCharacters)) + "\n\n[tool output truncated]"
    }
}

struct ToolFileConfig: Decodable {
    let tools: [RawToolConfig]

    init(from decoder: any Decoder) throws {
        let container = try decoder.container(keyedBy: CodingKeys.self)
        if container.contains(.tools) {
            tools = try container.decode([RawToolConfig].self, forKey: .tools)
            return
        }
        tools = [try RawToolConfig(from: decoder)]
    }

    private enum CodingKeys: String, CodingKey {
        case tools
    }
}

struct RawToolConfig: Decodable {
    let name: String
    let description: String
    let parameters: [RawToolParameter]
    let command: String
    let args: [String]
}

struct RawToolParameter: Decodable {
    let name: String
    let type: String
    let description: String
    let required: Bool?
}

struct ToolsConfigError: LocalizedError {
    let message: String

    init(_ message: String) {
        self.message = message
    }

    var errorDescription: String? { message }
}

#if canImport(FoundationModels)
@available(macOS 26.0, *)
struct ExternalCommandTool: Tool {
    typealias Arguments = GeneratedContent
    typealias Output = String

    let definition: ExternalToolDefinition

    var name: String { definition.name }
    var description: String { definition.description }

    var parameters: GenerationSchema {
        let properties = definition.parameters.map { parameter -> GenerationSchema.Property in
            switch (parameter.kind, parameter.required) {
            case (.string, true):
                return GenerationSchema.Property(name: parameter.name, description: parameter.description, type: String.self)
            case (.string, false):
                return GenerationSchema.Property(name: parameter.name, description: parameter.description, type: String?.self)
            case (.integer, true):
                return GenerationSchema.Property(name: parameter.name, description: parameter.description, type: Int.self)
            case (.integer, false):
                return GenerationSchema.Property(name: parameter.name, description: parameter.description, type: Int?.self)
            case (.number, true):
                return GenerationSchema.Property(name: parameter.name, description: parameter.description, type: Double.self)
            case (.number, false):
                return GenerationSchema.Property(name: parameter.name, description: parameter.description, type: Double?.self)
            case (.boolean, true):
                return GenerationSchema.Property(name: parameter.name, description: parameter.description, type: Bool.self)
            case (.boolean, false):
                return GenerationSchema.Property(name: parameter.name, description: parameter.description, type: Bool?.self)
            }
        }
        return GenerationSchema(type: GeneratedContent.self, description: definition.description, properties: properties)
    }

    func call(arguments: GeneratedContent) async throws -> String {
        var values: [String: String] = [:]

        for parameter in definition.parameters {
            switch (parameter.kind, parameter.required) {
            case (.string, true):
                let value = try arguments.value(String.self, forProperty: parameter.name)
                values[parameter.name] = value
            case (.string, false):
                if let value = try arguments.value(String?.self, forProperty: parameter.name) {
                    values[parameter.name] = value
                }
            case (.integer, true):
                let value = try arguments.value(Int.self, forProperty: parameter.name)
                values[parameter.name] = String(value)
            case (.integer, false):
                if let value = try arguments.value(Int?.self, forProperty: parameter.name) {
                    values[parameter.name] = String(value)
                }
            case (.number, true):
                let value = try arguments.value(Double.self, forProperty: parameter.name)
                values[parameter.name] = String(value)
            case (.number, false):
                if let value = try arguments.value(Double?.self, forProperty: parameter.name) {
                    values[parameter.name] = String(value)
                }
            case (.boolean, true):
                let value = try arguments.value(Bool.self, forProperty: parameter.name)
                values[parameter.name] = String(value)
            case (.boolean, false):
                if let value = try arguments.value(Bool?.self, forProperty: parameter.name) {
                    values[parameter.name] = String(value)
                }
            }
        }

        do {
            await ToolUseEvents.shared.emit(toolName: definition.name)
            DebugLog.log("tool call start name=\(definition.name) argKeys=\(values.keys.sorted().joined(separator: ","))")
            let response = try await ExternalToolExecutor.execute(tool: definition, arguments: values)
            DebugLog.log("tool call complete name=\(definition.name) responseLen=\(response.count)")
            return response
        } catch is CancellationError {
            DebugLog.log("tool call cancelled name=\(definition.name)")
            throw CancellationError()
        } catch {
            // Return tool failure details as content so the model can recover
            // (for example, by trying a different URL) instead of aborting generation.
            DebugLog.log("tool call error name=\(definition.name) error=\(error.localizedDescription)")
            return "Tool '\(definition.name)' failed: \(error.localizedDescription)"
        }
    }
}

@available(macOS 26.0, *)
enum FoundationToolFactory {
    static func makeTools(from loaded: LoadedTools?) -> [any Tool] {
        guard let loaded else { return [] }
        return loaded.definitions.map { ExternalCommandTool(definition: $0) }
    }
}
#endif
