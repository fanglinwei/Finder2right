import AppKit

let delegate = AppDelegate()
let directory = URL(fileURLWithPath: "/tmp/工具栏 空格 ' \"", isDirectory: true)
let type = FileType(name: "TXT 文件", fileExtension: "txt")
var disabledType = FileType(name: "隐藏类型", fileExtension: "hidden")
disabledType.isEnabled = false
let command = TerminalCommand(name: "测试命令", command: "pwd")
var disabledCommand = TerminalCommand(name: "隐藏命令", command: "false")
disabledCommand.isEnabled = false
let menu = delegate.toolbarMenu(directory: directory, types: [type, disabledType], commands: [command, disabledCommand])
assert(menu.items.map(\.title) == ["打开目录终端", "终端命令", "", "新建TXT 文件…"])
func request(_ item: NSMenuItem) -> FinderRequest {
    guard let url = item.representedObject as? URL, let request = FinderRequest(url: url) else {
        fatalError("Menu item must contain a valid request")
    }
    assert(item.target === delegate)
    assert(item.action != nil)
    assert(request.directory == directory)
    return request
}
assert(request(menu.items[0]).action == .openTerminal)
assert(request(menu.items[3]).action == .createFile(type.id))
guard let commands = menu.items[1].submenu else { fatalError("Missing commands submenu") }
assert(commands.items.count == 1)
assert(request(commands.items[0]).action == .runCommand(command.id))
let empty = delegate.toolbarMenu(directory: directory, types: [], commands: [])
assert(empty.items.count == 3)
assert(empty.items[1].submenu?.items.first?.isEnabled == false)
print("PASS: launcher menu actions preserve directory and IDs; disabled entries excluded; empty configuration handled")

let launcherDirectory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString, isDirectory: true)
try FileManager.default.createDirectory(at: launcherDirectory, withIntermediateDirectories: true)
defer { try? FileManager.default.removeItem(at: launcherDirectory) }
let launcherURL = launcherDirectory.appendingPathComponent("Finder2right.app/Contents/Helpers/Finder2right Launcher.app", isDirectory: true)
try FileManager.default.createDirectory(at: launcherURL, withIntermediateDirectories: true)
let icon = LauncherDragImageView(frame: NSRect(x: 0, y: 0, width: 56, height: 56))
icon.launcherURL = launcherURL
guard let item = icon.draggingItem(), let writer = item.item as? NSPasteboardWriting else {
    fatalError("Launcher drag must provide a native pasteboard writer")
}
let pasteboard = NSPasteboard.withUniqueName()
defer { pasteboard.releaseGlobally() }
assert(pasteboard.writeObjects([writer]))
guard let draggedURL = NSURL(from: pasteboard) as URL? else { fatalError("Launcher drag must contain a file URL") }
assert(draggedURL == launcherURL, "Drag must preserve the embedded launcher path instead of copying it into a cache")
assert(pasteboard.types?.contains(.fileURL) == true)
icon.launcherURL = launcherDirectory.appendingPathComponent("missing.app")
assert(icon.draggingItem() == nil)
icon.launcherURL = URL(string: "https://example.com/launcher.app")
assert(icon.draggingItem() == nil)
print("PASS: native launcher drag preserves original embedded App URL; missing and non-file URLs cannot be dragged")
