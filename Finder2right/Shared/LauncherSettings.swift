import Foundation

struct LauncherSettings: Codable, Equatable {
    enum Action: String, Codable, CaseIterable {
        case menu
        case openTerminal
        case customCommand

        var title: String {
            switch self {
            case .menu: return "展开菜单（默认）"
            case .openTerminal: return "打开当前目录终端"
            case .customCommand: return "执行自定义终端命令"
            }
        }
    }

    var action: Action = .menu
    var command = ""

    static var configurationURL: URL {
        FileTypes.configurationURL.deletingLastPathComponent().appendingPathComponent("launcher.json")
    }

    func validated() throws -> LauncherSettings {
        guard !command.contains("\0"),
              action != .customCommand || !command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw NSError(domain: "Finder2right", code: 12, userInfo: [
                NSLocalizedDescriptionKey: "自定义终端命令不能为空，且不能包含空字符。"
            ])
        }
        return self
    }

    static func load(from url: URL = configurationURL) throws -> LauncherSettings {
        do {
            return try JSONDecoder().decode(LauncherSettings.self, from: Data(contentsOf: url)).validated()
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            return LauncherSettings()
        }
    }

    static func save(_ settings: LauncherSettings, to url: URL = configurationURL) throws {
        let data = try JSONEncoder().encode(settings.validated())
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }
}
