import Foundation

struct CLIOptions {
    let showHelp: Bool
    let interactive: Bool
    let prompt: String?
    let temperature: Double?
    let parseError: String?

    static func parse(arguments: [String]) -> CLIOptions {
        var showHelp = false
        var interactive = false
        var prompt: String?
        var temperature: Double?
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
                    parseError = "Error: --temperature requires a numeric value between 0.0 and 2.0."
                }
                continue
            }
            if arg.hasPrefix("--temperature=") {
                let raw = String(arg.dropFirst("--temperature=".count))
                if let parsed = parseTemperature(raw) {
                    temperature = parsed
                } else {
                    parseError = "Error: --temperature requires a numeric value between 0.0 and 2.0."
                }
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
            parseError: parseError
        )
    }

    private static func parseTemperature(_ raw: String?) -> Double? {
        guard let raw, let value = Double(raw), (0.0...2.0).contains(value) else { return nil }
        return value
    }
}
