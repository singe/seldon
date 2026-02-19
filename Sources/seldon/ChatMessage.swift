import Foundation

struct ChatMessage: Identifiable {
    enum Role {
        case user
        case assistant
        case system
    }

    let id: UUID
    let role: Role
    var text: String
    var toolNotices: [String]

    init(id: UUID = UUID(), role: Role, text: String, toolNotices: [String] = []) {
        self.id = id
        self.role = role
        self.text = text
        self.toolNotices = toolNotices
    }
}
