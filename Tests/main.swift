import Foundation

let directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: directory) }
for name in ["中文 空格.txt", "notes.md"] {
    let url = directory.appendingPathComponent(name)
    try FileCreation.create(at: url)
    let data = try Data(contentsOf: url)
    assert(data.isEmpty)
    try Data("keep me".utf8).write(to: url)
    do {
        try FileCreation.create(at: url)
        fatalError("Existing files must not be replaced")
    } catch {}
    let contents = try String(contentsOf: url, encoding: .utf8)
    assert(contents == "keep me")
}
do {
    _ = try FileCreation.directory(from: directory.appendingPathComponent("notes.md"))
    fatalError("A file cannot be used as a directory")
} catch {}
print("PASS: TXT, Markdown, Unicode names, existing data protection, invalid directory")

let configuration = directory.appendingPathComponent("configuration/types.json")
let defaults = try FileTypes.load(from: configuration)
assert(defaults == FileTypes.defaults)
let custom = FileType(name: "  压缩文件  ", fileExtension: ".tar.gz", isEnabled: false)
let normalized = try FileTypes.validated([custom])
assert(normalized[0].name == "压缩文件" && normalized[0].fileExtension == "tar.gz")
try FileTypes.save(normalized, to: configuration)
let reloaded = try FileTypes.load(from: configuration)
assert(reloaded == normalized && !reloaded[0].isEnabled)
try FileTypes.save([], to: configuration)
let empty = try FileTypes.load(from: configuration)
assert(empty.isEmpty)
for invalidExtension in ["", ".", "a..b", "txt/evil", "a\\b", "a:b", "a b", "a\nb", "a\u{00}b"] {
    do {
        _ = try FileTypes.validated([FileType(name: "Invalid", fileExtension: invalidExtension)])
        fatalError("Invalid extension accepted: \(invalidExtension)")
    } catch {}
}
do {
    _ = try FileTypes.validated([FileType(name: "One", fileExtension: "TXT"), FileType(name: "Two", fileExtension: ".txt")])
    fatalError("Case-insensitive duplicate accepted")
} catch {}
do {
    _ = try FileTypes.validated([FileType(name: " \n", fileExtension: "json")])
    fatalError("Empty name accepted")
} catch {}
try Data("broken JSON".utf8).write(to: configuration)
do {
    _ = try FileTypes.load(from: configuration)
    fatalError("Corrupt configuration silently reset")
} catch {}
print("PASS: normalization, compound extensions, disabled/empty persistence, duplicates, invalid input, corrupt configuration")

let presets = FileTypes.presetGroups.flatMap(\.types)
let validatedPresets = try FileTypes.validated(presets)
assert(validatedPresets == presets)
assert(FileTypes.presetGroups.allSatisfy { !$0.name.isEmpty && !$0.types.isEmpty })
assert(Set(presets.map(\.fileExtension)).isSuperset(of: ["txt", "md", "json", "html", "py", "swift"]))
print("PASS: grouped presets are valid, unique, and cover common development types")

let commandsURL = directory.appendingPathComponent("configuration/commands.json")
let initialCommands = try TerminalCommands.load(from: commandsURL)
assert(initialCommands.isEmpty)
let command = TerminalCommand(name: "  查看状态  ", command: "git status\nprintf '完成\\n'", isEnabled: false)
let normalizedCommands = try TerminalCommands.validated([command])
assert(normalizedCommands[0].name == "查看状态" && normalizedCommands[0].command == command.command)
try TerminalCommands.save(normalizedCommands, to: commandsURL)
let savedCommands = try TerminalCommands.load(from: commandsURL)
assert(savedCommands == normalizedCommands)
for invalid in [
    TerminalCommand(name: " ", command: "pwd"),
    TerminalCommand(name: "名称\n", command: " "),
    TerminalCommand(name: "名称\n换行", command: "pwd"),
    TerminalCommand(name: "空字符", command: "pwd\0")
] {
    do {
        _ = try TerminalCommands.validated([invalid])
        fatalError("Invalid command accepted")
    } catch {}
}
do {
    _ = try TerminalCommands.validated([command, command])
    fatalError("Duplicate command identifier accepted")
} catch {}
try TerminalCommands.save([], to: commandsURL)
let emptyCommands = try TerminalCommands.load(from: commandsURL)
assert(emptyCommands.isEmpty)
try Data("broken JSON".utf8).write(to: commandsURL)
do {
    _ = try TerminalCommands.load(from: commandsURL)
    fatalError("Corrupt commands silently reset")
} catch {}

let specialDirectory = directory.appendingPathComponent("中文 空格 ' \" $HOME `pwd` ; &", isDirectory: true)
try FileManager.default.createDirectory(at: specialDirectory, withIntermediateDirectories: true)
let script = TerminalCommands.script(command: "printf '%s' \"$PWD\" > result.txt\nprintf 'second line' >> result.txt", directory: specialDirectory)
let process = Process()
process.executableURL = URL(fileURLWithPath: "/bin/zsh")
process.arguments = ["-f", "-c", script]
try process.run()
process.waitUntilExit()
assert(process.terminationStatus == 0)
let result = try String(contentsOf: specialDirectory.appendingPathComponent("result.txt"), encoding: .utf8)
assert(result == specialDirectory.path + "second line")
let missingDirectory = directory.appendingPathComponent("missing", isDirectory: true)
let blockedProcess = Process()
blockedProcess.executableURL = URL(fileURLWithPath: "/bin/zsh")
blockedProcess.arguments = ["-f", "-c", TerminalCommands.script(command: "touch should-not-exist", directory: missingDirectory)]
blockedProcess.currentDirectoryURL = directory
blockedProcess.standardError = FileHandle.nullDevice
try blockedProcess.run()
blockedProcess.waitUntilExit()
assert(blockedProcess.terminationStatus != 0)
assert(!FileManager.default.fileExists(atPath: directory.appendingPathComponent("should-not-exist").path))

let source = TerminalCommands.appleScript(command: "printf '%s' \"quoted\\value\"\nprintf 'next' # comment", directory: specialDirectory)
guard let appleScript = NSAppleScript(source: source) else { fatalError("Invalid AppleScript source") }
var compilationError: NSDictionary?
assert(appleScript.compileAndReturnError(&compilationError), "AppleScript compilation failed: \(String(describing: compilationError))")
print("PASS: command validation, persistence, corrupt configuration, quoted working directory, multiline execution, invalid directory blocks commands, AppleScript compilation")

let requestID = UUID()
for path in ["/", directory.path, specialDirectory.path + " #?%&=+\n子目录"] {
    let target = URL(fileURLWithPath: path, isDirectory: true)
    for action: FinderRequest.Action in [.openTerminal, .createFile(requestID), .runCommand(requestID)] {
        let request = FinderRequest(action: action, directory: target)
        guard let url = request.url else { fatalError("Request URL could not be encoded") }
        assert(FinderRequest(url: url) == request, "Request did not survive URL round trip: \(url)")
    }
}
// Existing Finder links remain valid across an App/extension update.
for (host, field, action) in [
    ("create", "type", FinderRequest.Action.createFile(requestID)),
    ("command", "command", FinderRequest.Action.runCommand(requestID))
] {
    guard let url = URL(string: "finder2right://\(host)?directory=%2Ftmp&\(field)=\(requestID.uuidString)") else {
        fatalError("Invalid legacy test URL")
    }
    assert(FinderRequest(url: url) == FinderRequest(action: action, directory: URL(fileURLWithPath: "/tmp", isDirectory: true)))
}
for value in [
    "https://terminal?directory=/tmp",
    "finder2right://unknown?directory=/tmp",
    "finder2right://terminal",
    "finder2right://terminal?directory",
    "finder2right://terminal?directory=",
    "finder2right://terminal?directory=relative",
    "finder2right://create?directory=/tmp",
    "finder2right://create?directory=/tmp&type=invalid",
    "finder2right://command?directory=/tmp&command=invalid",
    "finder2right://command?directory=/tmp&type=\(requestID.uuidString)",
    "finder2right://create?directory=/tmp&command=\(requestID.uuidString)"
] {
    guard let url = URL(string: value) else { fatalError("Invalid rejection test URL") }
    assert(FinderRequest(url: url) == nil, "Invalid request accepted: \(value)")
}
guard let remoteDirectory = URL(string: "https://example.com/folder") else { fatalError("Invalid remote URL") }
assert(FinderRequest(action: .openTerminal, directory: remoteDirectory).url == nil)
print("PASS: Finder request round trips, special paths, legacy links, invalid request rejection")

let storeURL = directory.appendingPathComponent("store/types.json")
let typeStore = FileTypeStore(configurationURL: storeURL)
assert(typeStore.savedTypes == FileTypes.defaults)
try typeStore.apply([FileType(name: "  JSON 文件  ", fileExtension: ".json")])
let committedTypes = typeStore.types
assert(committedTypes[0].name == "JSON 文件" && committedTypes[0].fileExtension == "json")
assert(typeStore.savedTypes == committedTypes && typeStore.errorMessage == nil)
var invalidDraft = committedTypes[0]
invalidDraft.fileExtension = "bad/path"
for candidate in [[invalidDraft], committedTypes + [FileType(name: "重复 JSON", fileExtension: "JSON")]] {
    do {
        try typeStore.apply(candidate)
        fatalError("Invalid editor draft must not be committed")
    } catch {}
    assert(typeStore.types == committedTypes && typeStore.savedTypes == committedTypes)
    let persistedTypes = try FileTypes.load(from: storeURL)
    assert(persistedTypes == committedTypes)
}
let failedStore = FileTypeStore(configurationURL: directory.appendingPathComponent("notes.md/types.json"))
assert(failedStore.errorMessage != nil)
do {
    try failedStore.apply(committedTypes)
    fatalError("A failed write must not publish the new list")
} catch {}
assert(failedStore.types.isEmpty && failedStore.savedTypes.isEmpty)
try typeStore.apply([])
assert(typeStore.types.isEmpty && typeStore.savedTypes.isEmpty)
let persistedEmptyTypes = try FileTypes.load(from: storeURL)
assert(persistedEmptyTypes.isEmpty)

let commandStoreURL = directory.appendingPathComponent("store/commands.json")
let commandStore = TerminalCommandStore(configurationURL: commandStoreURL)
let multilineCommand = TerminalCommand(name: "  状态  ", command: "git status\nprintf done")
try commandStore.apply([multilineCommand])
let committedCommands = commandStore.commands
assert(committedCommands[0].name == "状态" && committedCommands[0].command == multilineCommand.command)
for invalidContent in [" ", "pwd\0"] {
    var commandDraft = committedCommands[0]
    commandDraft.command = invalidContent
    do {
        try commandStore.apply([commandDraft])
        fatalError("Invalid command draft must not be committed")
    } catch {}
    assert(commandStore.commands == committedCommands)
    let persistedCommands = try TerminalCommands.load(from: commandStoreURL)
    assert(persistedCommands == committedCommands)
}
let commandWriteFailure = TerminalCommandStore(configurationURL: directory.appendingPathComponent("notes.md/commands.json"))
do {
    try commandWriteFailure.apply(committedCommands)
    fatalError("Failed command writes must leave memory unchanged")
} catch {}
assert(commandWriteFailure.commands.isEmpty)
print("PASS: transactional editor commits, normalization, duplicate rejection, empty list, multiline commands, validation/write failure preserves memory and disk")
