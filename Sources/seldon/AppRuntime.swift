import Foundation

@MainActor
enum AppRuntime {
    static var runner = ChatRunner()
    static var defaultTemperature: Double?
    static var defaultSystemPrompt: String?
    static var toolsAvailable = false
}
