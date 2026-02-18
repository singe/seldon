import Foundation

@main
enum SeldonEntrypoint {
    static func main() async {
        let options = CLIOptions.parse(arguments: Array(CommandLine.arguments.dropFirst()))
        if options.showHelp || options.parseError != nil || options.interactive || options.prompt != nil {
            await CLIRunner.run(with: options)
            return
        }

        SeldonApp.main()
    }
}
