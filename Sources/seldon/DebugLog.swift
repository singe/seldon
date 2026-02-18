import Foundation

enum DebugLog {
    static let enabled: Bool = {
        let value = ProcessInfo.processInfo.environment["SELDON_DEBUG"]?.lowercased()
        return value == "1" || value == "true" || value == "yes"
    }()
    static let verboseEnabled: Bool = {
        let value = ProcessInfo.processInfo.environment["SELDON_DEBUG_VERBOSE"]?.lowercased()
        return value == "1" || value == "true" || value == "yes"
    }()

    static func log(_ message: @autoclosure () -> String) {
        guard enabled else { return }
        let timestamp = String(format: "%.3f", Date().timeIntervalSince1970)
        let thread = Thread.isMainThread ? "main" : "bg"
        fputs("[seldon][\(timestamp)][\(thread)] \(message())\n", stderr)
        fflush(stderr)
    }

    static func verbose(_ message: @autoclosure () -> String) {
        guard verboseEnabled else { return }
        log(message())
    }
}
