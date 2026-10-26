import Foundation

struct TerminalCommand: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var command: String
    var isEnabled = true
}

enum TerminalCommands {
    static var configurationURL: URL {
        FileTypes.configurationURL.deletingLastPathComponent().appendingPathComponent("commands.json")
    }

    static func validated(_ commands: [TerminalCommand]) throws -> [TerminalCommand] {
        var identifiers = Set<UUID>()
        return try commands.map { command in
            var command = command
            command.name = command.name.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !command.name.isEmpty,
                  command.name.rangeOfCharacter(from: .controlCharacters) == nil,
                  !command.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  !command.command.contains("\0"),
                  identifiers.insert(command.id).inserted else {
                throw NSError(domain: "Finder2right", code: 5, userInfo: [
                    NSLocalizedDescriptionKey: "命令名称和内容不能为空，名称不能含控制字符，命令不能含空字符，标识不能重复。"
                ])
            }
            return command
        }
    }

    static func load(from url: URL = configurationURL) throws -> [TerminalCommand] {
        do {
            return try validated(JSONDecoder().decode([TerminalCommand].self, from: Data(contentsOf: url)))
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            return []
        }
    }

    static func save(_ commands: [TerminalCommand], to url: URL = configurationURL) throws {
        let data = try JSONEncoder().encode(validated(commands))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    static func script(command: String, directory: URL) -> String {
        let path = directory.path.replacingOccurrences(of: "'", with: "'\\''")
        return "cd -- '\(path)' && {\n\(command)\n}"
    }

    static func appleScript(command: String, directory: URL) -> String {
        let script = script(command: command, directory: directory)
            .replacingOccurrences(of: "\\", with: "\\\\")
            .replacingOccurrences(of: "\"", with: "\\\"")
            .replacingOccurrences(of: "\r", with: "\\r")
            .replacingOccurrences(of: "\n", with: "\\n")
        return "tell application id \"com.apple.Terminal\"\nactivate\ndo script \"\(script)\"\nend tell"
    }
}
