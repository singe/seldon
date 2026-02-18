# seldon

seldon lets you interact with Apple's on-device LLM Foundation models on macOS. It's a minimal native macOS chat app built with SwiftUI as a Swift Package. It has a UI, terminal REPL and single shot command mode.

By @singe

## Build

```bash
swift build -c release
```

## GUI Mode

```bash
seldon
```

This launches a native window (`Seldon Chat`).

## CLI Mode

Interactive terminal mode:

```bash
seldon --cli
```

`--cli` streams the model output as it is generated.

Single-shot headless mode (for scripts):

```bash
seldon --prompt "What is psychohistory?"
```

`--prompt` prints a single final response (no streaming), then exits.

Optional sampling temperature for CLI modes (`0.0` to `2.0`):

```bash
seldon --cli --temperature 0.2
seldon --prompt "Summarize this log file" --temperature=0.7
```

## Foundation Models support

- The app uses Apple's on-device Foundation Models API when available.
- In this environment, `LanguageModelSession` is available on `macOS 26.0+`.
- On older macOS versions (or SDKs without `FoundationModels`), the UI still runs and shows a clear unsupported message when you send a prompt.
