import Foundation

@MainActor
enum AppRuntime {
    static var runner = ChatRunner()
    static var defaultTemperature: Double?
    static var toolsAvailable = false
}
