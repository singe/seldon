import Foundation

struct CLIOptions {
    let showHelp: Bool
    let interactive: Bool
    let prompt: String?
    let temperature: Double?
    let toolsPath: String?
    let parseError: String?

    static func parse(arguments: [String]) -> CLIOptions {
        var showHelp = false
        var interactive = false
        var prompt: String?
        var temperature: Double?
        var toolsPath: String?
        var parseError: String?

        var index = 0
        while index < arguments.count {
            let arg = arguments[index]

            if arg == "--help" || arg == "-h" {
                showHelp = true
                index += 1
                continue
            }
            if arg == "--cli" {
                interactive = true
                index += 1
                continue
            }
            if arg == "--prompt" {
                if index + 1 < arguments.count {
                    prompt = arguments[index + 1]
                    index += 2
                } else {
                    prompt = ""
                    index += 1
                }
                continue
            }
            if arg.hasPrefix("--prompt=") {
                prompt = String(arg.dropFirst("--prompt=".count))
                index += 1
                continue
            }
            if arg == "--temperature" {
                let raw: String?
                if index + 1 < arguments.count {
                    raw = arguments[index + 1]
                    index += 2
                } else {
                    raw = nil
                    index += 1
                }

                if let parsed = parseTemperature(raw) {
                    temperature = parsed
                } else {
                    setParseError(&parseError, "Error: --temperature requires a numeric value between 0.0 and 2.0. Run with --help for usage.")
                }
                continue
            }
            if arg.hasPrefix("--temperature=") {
                let raw = String(arg.dropFirst("--temperature=".count))
                if let parsed = parseTemperature(raw) {
                    temperature = parsed
                } else {
                    setParseError(&parseError, "Error: --temperature requires a numeric value between 0.0 and 2.0. Run with --help for usage.")
                }
                index += 1
                continue
            }
            if arg == "--tools" {
                let raw: String?
                if index + 1 < arguments.count {
                    raw = arguments[index + 1]
                    index += 2
                } else {
                    raw = nil
                    index += 1
                }

                if let raw, !raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    toolsPath = raw
                } else {
                    setParseError(&parseError, "Error: --tools requires a file path. Run with --help for usage.")
                }
                continue
            }
            if arg.hasPrefix("--tools=") {
                let raw = String(arg.dropFirst("--tools=".count))
                if raw.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
                    setParseError(&parseError, "Error: --tools requires a file path. Run with --help for usage.")
                } else {
                    toolsPath = raw
                }
                index += 1
                continue
            }

            if arg.hasPrefix("-") {
                setParseError(&parseError, "Error: unknown option '\(arg)'. Run with --help for usage.")
                index += 1
                continue
            }

            index += 1
        }

        return CLIOptions(
            showHelp: showHelp,
            interactive: interactive,
            prompt: prompt,
            temperature: temperature,
            toolsPath: toolsPath,
            parseError: parseError
        )
    }

    private static func parseTemperature(_ raw: String?) -> Double? {
        guard let raw, let value = Double(raw), (0.0...2.0).contains(value) else { return nil }
        return value
    }

    private static func setParseError(_ parseError: inout String?, _ message: String) {
        if parseError == nil {
            parseError = message
        }
    }
}
