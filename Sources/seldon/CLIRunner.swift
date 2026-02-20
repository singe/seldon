import Foundation

enum CLIRunner {
    private actor ToolUsageState {
        private var tools: [String] = []
        private var printedAnyTokens = false

        func markPrintedToken() {
            printedAnyTokens = true
        }

        func noteTool(_ name: String) -> (isNew: Bool, printedAnyTokens: Bool) {
            let isNew = !tools.contains(name)
            if isNew {
                tools.append(name)
            }
            return (isNew, printedAnyTokens)
        }
    }

    private static let usage = """
    Usage:
      seldon                  Launch GUI
      seldon --cli            Start interactive CLI (streaming)
      seldon --prompt TEXT    Run one headless prompt (non-streaming)

    Options:
      --temperature VALUE         Sampling temperature (0.0 to 2.0) for CLI/GUI/prompt
      --tools PATH                Load tool definitions from a YAML file
      --system TEXT               Set system instructions for model behavior
      --help, -h                  Show this help
    """

    static func run(with options: CLIOptions, runner: ChatRunner = ChatRunner()) async {
        if options.showHelp {
            print(usage)
            return
        }

        if let parseError = options.parseError {
            fputs(parseError + "\n", stderr)
            exit(2)
        }

        if let prompt = options.prompt {
            await runSingle(
                prompt: prompt,
                temperature: options.temperature,
                systemPrompt: options.systemPrompt,
                runner: runner
            )
            return
        }

        guard options.interactive else { return }
        await runInteractive(
            temperature: options.temperature,
            systemPrompt: options.systemPrompt,
            runner: runner
        )
    }

    private static func runSingle(prompt: String, temperature: Double?, systemPrompt: String?, runner: ChatRunner) async {
        guard let trimmed = ChatTextUtilities.normalizePrompt(prompt) else {
            fputs("Error: --prompt requires a non-empty value.\n", stderr)
            exit(2)
        }

        do {
            let normalizedSystemPrompt = systemPrompt.flatMap(ChatTextUtilities.normalizePrompt)
            let request = ChatRunRequest(
                prompt: trimmed,
                temperature: temperature,
                mode: .singleShot,
                systemPrompt: normalizedSystemPrompt
            )
            let toolState = ToolUsageState()
            let response = try await runner.run(request, onToolUse: { toolName in
                let status = await toolState.noteTool(toolName)
                guard status.isNew else { return }
                print("[tool] \(toolName)")
                fflush(stdout)
            })
            print(response)
        } catch {
            fputs("Error: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func runInteractive(temperature: Double?, systemPrompt: String?, runner: ChatRunner) async {
        print("seldon CLI (type 'exit' or press Ctrl-D to quit)")
        while true {
            print("seldon> ", terminator: "")
            fflush(stdout)

            guard let line = readLine() else {
                print("")
                break
            }

            guard let prompt = ChatTextUtilities.normalizePrompt(line) else { continue }
            if prompt == "exit" || prompt == "quit" { break }

            do {
                let normalizedSystemPrompt = systemPrompt.flatMap(ChatTextUtilities.normalizePrompt)
                let request = ChatRunRequest(
                    prompt: prompt,
                    temperature: temperature,
                    mode: .streaming,
                    systemPrompt: normalizedSystemPrompt
                )
                let toolState = ToolUsageState()

                _ = try await runner.run(request) { token in
                    await toolState.markPrintedToken()
                    print(token, terminator: "")
                    fflush(stdout)
                } onToolUse: { toolName in
                    let status = await toolState.noteTool(toolName)
                    guard status.isNew else { return }
                    if status.printedAnyTokens {
                        print("")
                    }
                    print("[tool] \(toolName)")
                    fflush(stdout)
                }
                print("")
            } catch {
                fputs("Error: \(error.localizedDescription)\n", stderr)
            }
        }
    }
}
