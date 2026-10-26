import Foundation
import Darwin

struct FileType: Codable, Identifiable, Equatable {
    var id: UUID = UUID()
    var name: String
    var fileExtension: String
    var isEnabled = true
}

enum FileTypes {
    static let defaults = [
        FileType(id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 1)), name: "TXT 文件", fileExtension: "txt"),
        FileType(id: UUID(uuid: (0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 0, 2)), name: "Markdown 文件", fileExtension: "md")
    ]

    static let presetGroups: [(name: String, types: [FileType])] = [
        ("数据与配置", [
            FileType(name: "JSON 文件", fileExtension: "json"),
            FileType(name: "YAML 配置", fileExtension: "yaml"),
            FileType(name: "TOML 配置", fileExtension: "toml"),
            FileType(name: "XML 文件", fileExtension: "xml"),
            FileType(name: "SQL 脚本", fileExtension: "sql"),
            FileType(name: "CSV 数据", fileExtension: "csv")
        ]),
        ("网页开发", [
            FileType(name: "HTML 页面", fileExtension: "html"),
            FileType(name: "CSS 样式", fileExtension: "css"),
            FileType(name: "JavaScript 源码", fileExtension: "js"),
            FileType(name: "TypeScript 源码", fileExtension: "ts"),
            FileType(name: "React JSX 组件", fileExtension: "jsx"),
            FileType(name: "React TSX 组件", fileExtension: "tsx"),
            FileType(name: "Vue 组件", fileExtension: "vue")
        ]),
        ("脚本与自动化", [
            FileType(name: "Python 脚本", fileExtension: "py"),
            FileType(name: "Shell 脚本", fileExtension: "sh"),
            FileType(name: "Zsh 脚本", fileExtension: "zsh"),
            FileType(name: "PowerShell 脚本", fileExtension: "ps1")
        ]),
        ("应用与后端源码", [
            FileType(name: "Swift 源码", fileExtension: "swift"),
            FileType(name: "Kotlin 源码", fileExtension: "kt"),
            FileType(name: "Java 源码", fileExtension: "java"),
            FileType(name: "Go 源码", fileExtension: "go"),
            FileType(name: "Rust 源码", fileExtension: "rs"),
            FileType(name: "C 源码", fileExtension: "c"),
            FileType(name: "C++ 源码", fileExtension: "cpp"),
            FileType(name: "C# 源码", fileExtension: "cs")
        ]),
        ("文档与记录", [
            FileType(name: "TXT 文件", fileExtension: "txt"),
            FileType(name: "Markdown 文件", fileExtension: "md"),
            FileType(name: "reStructuredText 文档", fileExtension: "rst"),
            FileType(name: "日志文件", fileExtension: "log")
        ])
    ]

    static var configurationURL: URL {
        // shortcut: local signing uses a narrow read-only sandbox exception; use App Groups for distribution.
        let home = getpwuid(getuid()).map { String(cString: $0.pointee.pw_dir) } ?? NSHomeDirectory()
        return URL(fileURLWithPath: home, isDirectory: true)
            .appendingPathComponent("Library/Application Support/Finder2right/types.json")
    }

    static func validated(_ types: [FileType]) throws -> [FileType] {
        var extensions = Set<String>()
        var identifiers = Set<UUID>()
        return try types.map { type in
            var type = type
            type.name = type.name.trimmingCharacters(in: .whitespacesAndNewlines)
            type.fileExtension = String(type.fileExtension.drop(while: { $0 == "." }))
            guard !type.name.isEmpty else { throw invalid("显示名称不能为空。") }
            let suffix = type.fileExtension
            let forbidden = CharacterSet.whitespacesAndNewlines.union(.controlCharacters)
                .union(CharacterSet(charactersIn: "/\\:"))
            guard !suffix.isEmpty, suffix.rangeOfCharacter(from: forbidden) == nil,
                  !suffix.split(separator: ".", omittingEmptySubsequences: false).contains(where: { $0.isEmpty }) else {
                throw invalid("扩展名不能为空，且不能包含路径、空白、控制字符或空段。")
            }
            guard extensions.insert(suffix.lowercased()).inserted else {
                throw invalid("扩展名 \(suffix) 已存在（不区分大小写）。")
            }
            guard identifiers.insert(type.id).inserted else { throw invalid("文件类型标识重复。") }
            return type
        }
    }

    static func load(from url: URL = configurationURL) throws -> [FileType] {
        do {
            let data = try Data(contentsOf: url)
            return try validated(JSONDecoder().decode([FileType].self, from: data))
        } catch let error as NSError where error.domain == NSCocoaErrorDomain && error.code == NSFileReadNoSuchFileError {
            return defaults
        }
    }

    static func save(_ types: [FileType], to url: URL = configurationURL) throws {
        let data = try JSONEncoder().encode(validated(types))
        try FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try data.write(to: url, options: .atomic)
    }

    private static func invalid(_ message: String) -> NSError {
        NSError(domain: "Finder2right", code: 2, userInfo: [NSLocalizedDescriptionKey: message])
    }
}
