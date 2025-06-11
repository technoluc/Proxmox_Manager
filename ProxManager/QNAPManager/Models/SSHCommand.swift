import Foundation

struct SSHCommand: Identifiable, Codable, Hashable {
    let id: UUID
    var name: String
    var command: String
    var description: String
    var isFavorite: Bool
    var lastExecuted: Date?
    
    init(id: UUID = UUID(), name: String, command: String, description: String = "", isFavorite: Bool = false, lastExecuted: Date? = nil) {
        self.id = id
        self.name = name
        self.command = command
        self.description = description
        self.isFavorite = isFavorite
        self.lastExecuted = lastExecuted
    }
}

struct SSHConnection: Codable {
    var host: String
    var port: Int
    var username: String
    var password: String
    
    init(host: String, port: Int = 22, username: String, password: String) {
        self.host = host
        self.port = port
        self.username = username
        self.password = password
    }
} 