import Foundation

/// Finder 与主 App 共用的请求格式；磁盘目录和已保存配置由执行方再次校验。
struct FinderRequest: Equatable {
    enum Action: Equatable {
        case createFile(UUID)
        case openTerminal
        case runCommand(UUID)
    }

    let action: Action
    let directory: URL

    init(action: Action, directory: URL) {
        self.action = action
        self.directory = directory
    }

    init?(url: URL) {
        guard let components = URLComponents(url: url, resolvingAgainstBaseURL: false),
              components.scheme == "finder2right",
              let items = components.queryItems,
              let path = items.first(where: { $0.name == "directory" })?.value,
              path.hasPrefix("/") else { return nil }
        switch components.host {
        case "terminal":
            action = .openTerminal
        case "create":
            guard let value = items.first(where: { $0.name == "type" })?.value,
                  let id = UUID(uuidString: value) else { return nil }
            action = .createFile(id)
        case "command":
            guard let value = items.first(where: { $0.name == "command" })?.value,
                  let id = UUID(uuidString: value) else { return nil }
            action = .runCommand(id)
        default:
            return nil
        }
        directory = URL(fileURLWithPath: path, isDirectory: true)
    }

    var url: URL? {
        guard directory.isFileURL, directory.path.hasPrefix("/") else { return nil }
        var components = URLComponents()
        components.scheme = "finder2right"
        components.queryItems = [URLQueryItem(name: "directory", value: directory.path)]
        switch action {
        case .openTerminal:
            components.host = "terminal"
        case .createFile(let id):
            components.host = "create"
            components.queryItems?.append(URLQueryItem(name: "type", value: id.uuidString))
        case .runCommand(let id):
            components.host = "command"
            components.queryItems?.append(URLQueryItem(name: "command", value: id.uuidString))
        }
        return components.url
    }
}
