import SwiftUI
import AppKit
import MarkdownUI

struct ContentView: View {
    @StateObject private var viewModel = ChatViewModel()
    @FocusState private var inputIsFocused: Bool

    var body: some View {
        VStack(spacing: 12) {
            ScrollViewReader { proxy in
                ScrollView {
                    LazyVStack(alignment: .leading, spacing: 8) {
                        ForEach(viewModel.messages) { message in
                            row(for: message)
                                .id(message.id)
                        }
                    }
                    .padding(12)
                }
                .onChange(of: viewModel.messages.count) {
                    if let last = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
                .onChange(of: viewModel.messages.last?.text ?? "") {
                    if let last = viewModel.messages.last {
                        withAnimation {
                            proxy.scrollTo(last.id, anchor: .bottom)
                        }
                    }
                }
            }

            HStack(spacing: 8) {
                TextField("Type a prompt...", text: $viewModel.input, axis: .vertical)
                    .textFieldStyle(.roundedBorder)
                    .lineLimit(1...4)
                    .focused($inputIsFocused)
                    .onSubmit {
                        viewModel.send()
                    }

                Button(viewModel.isSending ? "Stop" : "Send") {
                    if viewModel.isSending {
                        viewModel.stop()
                    } else {
                        viewModel.send()
                    }
                }
                .disabled(!viewModel.isSending && ChatTextUtilities.normalizePrompt(viewModel.input) == nil)
            }
            .padding(12)
        }
        .frame(minWidth: 560, minHeight: 700)
        .onAppear {
            DispatchQueue.main.async {
                inputIsFocused = true
            }
        }
    }

    private func row(for message: ChatMessage) -> some View {
        let style: (color: Color, label: String) = switch message.role {
        case .user:
            (.blue.opacity(0.12), "You")
        case .assistant:
            (.green.opacity(0.12), "Assistant")
        case .system:
            (.gray.opacity(0.15), "System")
        }

        return ZStack(alignment: .topTrailing) {
            VStack(alignment: .leading, spacing: 4) {
                Text(style.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                messageText(for: message.text)
                    .textSelection(.enabled)
                    .frame(maxWidth: .infinity, alignment: .leading)
            }
            .padding(10)
            .background(RoundedRectangle(cornerRadius: 8).fill(style.color))

            Button {
                copyToClipboard(message.text)
            } label: {
                Image(systemName: "doc.on.doc")
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.secondary)
                    .padding(6)
                    .background(.thinMaterial, in: RoundedRectangle(cornerRadius: 6))
            }
            .buttonStyle(.plain)
            .padding(6)
        }
    }

    private func messageText(for text: String) -> some View {
        Markdown(text)
    }

    private func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
