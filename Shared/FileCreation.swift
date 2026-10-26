import Foundation

/// Validates destinations and creates empty files without replacing existing data.
enum FileCreation {
    static func directory(from url: URL) throws -> URL {
        guard url.isFileURL, url.path.hasPrefix("/"),
              try url.resourceValues(forKeys: [.isDirectoryKey]).isDirectory == true else {
            throw NSError(domain: "Finder2right", code: 1, userInfo: [
                NSLocalizedDescriptionKey: "请选择有效的本地文件夹。"
            ])
        }
        return url
    }

    static func create(at url: URL) throws {
        _ = try directory(from: url.deletingLastPathComponent())
        try Data().write(to: url, options: .withoutOverwriting)
    }
}
