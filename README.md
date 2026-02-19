# seldon

seldon lets you interact with Apple's on-device LLM Foundation models on macOS. It's a minimal native macOS chat app built with SwiftUI as a Swift Package. It has a UI, terminal REPL and single shot command mode.

By @singe

## Build

```bash
swift build -c release
```

## Packaging

Build artifacts with `make`:

```bash
make binary        # dist/seldon-macos-<arch>
make bundle        # dist/seldon-macos-<arch>-with-tools.tar.gz
make app           # dist/Seldon-macos-<arch>.app.zip
make release-assets
```

The app bundle launcher automatically runs:

```bash
--tools <bundled tools.example.yaml>
```

GitHub releases publish:

1. `seldon-macos-<arch>` (standalone binary)
2. `seldon-macos-<arch>-with-tools.tar.gz` (binary + `tools/` + `tools.example.yaml`)
3. `Seldon-macos-<arch>.app.zip` (macOS app bundle)

## GUI Mode

```bash
seldon
```

This launches a native window (`Seldon Chat`).
<img width="628" height="474" alt="image" src="https://github.com/user-attachments/assets/eb6fae9c-f192-4d5f-8ec2-2630fc34ece4" />


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

The same `--temperature` value is also applied to GUI mode if you launch `seldon` with that flag.

## Tool Calling

Pass a tools YAML file to enable Foundation Models tool calling:

```bash
seldon --tools tools.example.yaml
seldon --cli --tools tools.example.yaml
seldon --prompt "search the web for hari seldon and describe the top result" --tools tools.example.yaml
```

Example config is included at `tools.example.yaml` with three basic tools:

- `web_search` implemented by `tools/web_search.py`
- `fetch_url` implemented by `tools/fetch_url.py`
- `calculator` implemented by `tools/calculator.py`

## Foundation Models support

- The app uses Apple's on-device Foundation Models API when available.
- In this environment, `LanguageModelSession` is available on `macOS 26.0+`.
- On older macOS versions (or SDKs without `FoundationModels`), the UI still runs and shows a clear unsupported message when you send a prompt.
