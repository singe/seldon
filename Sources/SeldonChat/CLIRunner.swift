import Foundation

enum CLIRunner {
    private static let usage = """
    Usage:
      SeldonChat                  Launch GUI
      SeldonChat --cli            Start interactive CLI (streaming)
      SeldonChat --prompt TEXT    Run one headless prompt (non-streaming)

    Options:
      --temperature VALUE         Sampling temperature (0.0 to 2.0) for CLI modes
      --help, -h                  Show this help
    """

    private actor CLIStreamRenderState {
        private var rawResponse = ""
        private var latestRenderedResponse = ""
        private var printedRenderedResponse = ""

        func consume(token: String) -> String {
            rawResponse += token
            let nextRendered = CLIRunner.renderMarkdownForCLI(rawResponse)
            guard nextRendered != latestRenderedResponse else { return "" }
            latestRenderedResponse = nextRendered

            if nextRendered.hasPrefix(printedRenderedResponse) {
                let delta = String(nextRendered.dropFirst(printedRenderedResponse.count))
                guard let stableEnd = CLIRunner.lastStableBoundary(in: delta) else { return "" }
                let stableDelta = String(delta[..<stableEnd])
                printedRenderedResponse += stableDelta
                return stableDelta
            }

            // If parsing revises earlier text, avoid destructive terminal rewrites.
            return ""
        }

        func finalize() -> String {
            guard latestRenderedResponse != printedRenderedResponse else { return "" }

            if latestRenderedResponse.hasPrefix(printedRenderedResponse) {
                let delta = String(latestRenderedResponse.dropFirst(printedRenderedResponse.count))
                printedRenderedResponse = latestRenderedResponse
                return delta
            }

            printedRenderedResponse = latestRenderedResponse
            return "\n" + latestRenderedResponse
        }
    }

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
        let trimmed = prompt.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
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
        print("SeldonChat CLI (type 'exit' or press Ctrl-D to quit)")
        while true {
            print("seldon> ", terminator: "")
            fflush(stdout)

            guard let line = readLine() else {
                print("")
                break
            }

            let prompt = line.trimmingCharacters(in: .whitespacesAndNewlines)
            if prompt.isEmpty { continue }
            if prompt == "exit" || prompt == "quit" { break }

            do {
                let renderState = CLIStreamRenderState()
                let request = ChatRunRequest(prompt: prompt, temperature: temperature, mode: .streaming)

                _ = try await runner.run(request) { token in
                    let delta = await renderState.consume(token: token)
                    guard !delta.isEmpty else { return }
                    print(delta, terminator: "")
                    fflush(stdout)
                }

                let finalDelta = await renderState.finalize()
                if !finalDelta.isEmpty {
                    print(finalDelta, terminator: "")
                    fflush(stdout)
                }
                print("")
            } catch {
                fputs("Error: \(error.localizedDescription)\n", stderr)
            }
        }
    }

    private static func renderMarkdownForCLI(_ text: String) -> String {
        let options = AttributedString.MarkdownParsingOptions(
            interpretedSyntax: .inlineOnlyPreservingWhitespace,
            failurePolicy: .returnPartiallyParsedIfPossible
        )

        if let attributed = try? AttributedString(markdown: text, options: options) {
            return String(attributed.characters)
        }
        return text
    }

    private static func lastStableBoundary(in text: String) -> String.Index? {
        var boundary: String.Index?
        var idx = text.startIndex
        while idx < text.endIndex {
            let char = text[idx]
            if char.isWhitespace {
                boundary = text.index(after: idx)
            }
            idx = text.index(after: idx)
        }
        return boundary
    }
}
