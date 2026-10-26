import Combine
import Foundation

final class FileTypeStore: ObservableObject {
    @Published private(set) var types: [FileType] = []
    @Published private(set) var savedTypes: [FileType] = []
    @Published var errorMessage: String?
    private let configurationURL: URL

    init(configurationURL: URL = FileTypes.configurationURL) {
        self.configurationURL = configurationURL
        do {
            types = try FileTypes.load(from: configurationURL)
            savedTypes = types
        } catch {
            errorMessage = "读取配置失败：\(error.localizedDescription)"
        }
    }

    func apply(_ candidate: [FileType]) throws {
        let validTypes = try FileTypes.validated(candidate)
        try FileTypes.save(validTypes, to: configurationURL)
        savedTypes = validTypes
        if types != validTypes { types = validTypes }
        errorMessage = nil
    }

}

final class TerminalCommandStore: ObservableObject {
    @Published private(set) var commands: [TerminalCommand] = []
    @Published var errorMessage: String?
    private let configurationURL: URL

    init(configurationURL: URL = TerminalCommands.configurationURL) {
        self.configurationURL = configurationURL
        do { commands = try TerminalCommands.load(from: configurationURL) }
        catch { errorMessage = "读取命令配置失败：\(error.localizedDescription)" }
    }

    func apply(_ candidate: [TerminalCommand]) throws {
        let validCommands = try TerminalCommands.validated(candidate)
        try TerminalCommands.save(validCommands, to: configurationURL)
        if commands != validCommands { commands = validCommands }
        errorMessage = nil
    }

}
