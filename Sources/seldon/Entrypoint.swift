import Foundation

@main
enum SeldonEntrypoint {
    static func main() async {
        let options = CLIOptions.parse(arguments: Array(CommandLine.arguments.dropFirst()))
        DebugLog.log("Entrypoint start args=\(CommandLine.arguments.dropFirst().joined(separator: " "))")
        if options.showHelp || options.parseError != nil {
            await CLIRunner.run(with: options)
            return
        }

        let loadedTools: LoadedTools?
        do {
            if let toolsPath = options.toolsPath {
                loadedTools = try ToolsConfigLoader.load(from: toolsPath)
                DebugLog.log("Loaded tools from \(toolsPath)")
            } else {
                loadedTools = nil
                DebugLog.log("No tools configured")
            }
        } catch {
            fputs("Error: \(error.localizedDescription)\n", stderr)
            exit(2)
        }

        let runner = ChatRunner(loadedTools: loadedTools)

        if options.interactive || options.prompt != nil {
            DebugLog.log("Launching CLI mode interactive=\(options.interactive) prompt=\(options.prompt != nil)")
            await CLIRunner.run(with: options, runner: runner)
            return
        }

        await MainActor.run {
            AppRuntime.runner = runner
            AppRuntime.defaultTemperature = options.temperature
        }
        DebugLog.log("Launching GUI mode")
        SeldonApp.main()
    }
}
