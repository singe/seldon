import Foundation

@main
enum SeldonChatEntrypoint {
    static func main() async {
        let options = CLIOptions.parse(arguments: Array(CommandLine.arguments.dropFirst()))
        if options.showHelp || options.parseError != nil || options.interactive || options.prompt != nil {
            await CLIRunner.run(with: options)
            return
        }

        SeldonChatApp.main()
    }
}
