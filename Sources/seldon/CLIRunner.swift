import Foundation

enum CLIRunner {
    private static let usage = """
    Usage:
      seldon                  Launch GUI
      seldon --cli            Start interactive CLI (streaming)
      seldon --prompt TEXT    Run one headless prompt (non-streaming)

    Options:
      --temperature VALUE         Sampling temperature (0.0 to 2.0) for CLI/GUI/prompt
      --tools PATH                Load tool definitions from a YAML file
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
            await runSingle(prompt: prompt, temperature: options.temperature, runner: runner)
            return
        }

        guard options.interactive else { return }
        await runInteractive(temperature: options.temperature, runner: runner)
    }

    private static func runSingle(prompt: String, temperature: Double?, runner: ChatRunner) async {
        guard let trimmed = ChatTextUtilities.normalizePrompt(prompt) else {
            fputs("Error: --prompt requires a non-empty value.\n", stderr)
            exit(2)
        }

        do {
            let request = ChatRunRequest(prompt: trimmed, temperature: temperature, mode: .singleShot)
            let response = try await runner.run(request)
            print(response)
        } catch {
            fputs("Error: \(error.localizedDescription)\n", stderr)
            exit(1)
        }
    }

    private static func runInteractive(temperature: Double?, runner: ChatRunner) async {
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
                let request = ChatRunRequest(prompt: prompt, temperature: temperature, mode: .streaming)

                _ = try await runner.run(request) { token in
                    print(token, terminator: "")
                    fflush(stdout)
                }
                print("")
            } catch {
                fputs("Error: \(error.localizedDescription)\n", stderr)
            }
        }
    }
}
