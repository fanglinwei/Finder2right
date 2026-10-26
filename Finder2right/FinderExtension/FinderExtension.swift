import AppKit
import FinderSync

@objc(FinderExtension)
final class FinderExtension: FIFinderSync {
    private var menuTypes: [FileType] = []
    private var menuCommands: [TerminalCommand] = []
    override init() {
        super.init()
        // shortcut: observe local volumes broadly; add folder selection if narrower coverage is needed.
        FIFinderSyncController.default().directoryURLs = [URL(fileURLWithPath: "/", isDirectory: true)]
    }

    override var toolbarItemName: String { "新建文件" }

    override var toolbarItemToolTip: String { "新建文件或在终端中打开当前文件夹" }

    override var toolbarItemImage: NSImage {
        let appURL = Bundle.main.bundleURL.deletingLastPathComponent().deletingLastPathComponent().deletingLastPathComponent()
        let appIcon = NSWorkspace.shared.icon(forFile: appURL.path)
        let image = NSImage(size: NSSize(width: 18, height: 18))
        // Render a small bitmap so Finder does not receive the full-size app icon representations.
        image.lockFocus()
        appIcon.draw(in: NSRect(origin: .zero, size: image.size))
        image.unlockFocus()
        image.accessibilityDescription = toolbarItemName
        return image
    }

    override func menu(for menuKind: FIMenuKind) -> NSMenu? {
        let controller = FIFinderSyncController.default()
        let directory: URL
        switch menuKind {
        case .contextualMenuForContainer, .toolbarItemMenu:
            guard let target = controller.targetedURL() else { return nil }
            directory = target
        case .contextualMenuForItems:
            guard let items = controller.selectedItemURLs(), items.count == 1,
                  let selected = items.first else { return nil }
            directory = selected
        default:
            return nil
        }
        guard directory.isFileURL,
              (try? directory.resourceValues(forKeys: [.isDirectoryKey]).isDirectory) == true else { return nil }
        let menu = NSMenu()
        if menuKind == .toolbarItemMenu {
            menu.addItem(NSMenuItem(title: "打开目录终端", action: #selector(openTerminal(_:)), keyEquivalent: ""))
            let commandItem = NSMenuItem(title: "终端命令", action: nil, keyEquivalent: "")
            let commandsMenu = NSMenu(title: "终端命令")
            commandItem.submenu = commandsMenu
            menu.addItem(commandItem)
            do {
                menuCommands = try TerminalCommands.load().filter(\.isEnabled)
                for (tag, command) in menuCommands.enumerated() {
                    let item = NSMenuItem(title: command.name, action: #selector(runTerminalCommand(_:)), keyEquivalent: "")
                    item.tag = tag
                    commandsMenu.addItem(item)
                }
                if menuCommands.isEmpty {
                    commandsMenu.addItem(NSMenuItem(title: "请在 Finder2right 主窗口配置命令", action: nil, keyEquivalent: ""))
                }
            } catch {
                menuCommands = []
                commandsMenu.addItem(NSMenuItem(title: "命令配置读取失败，请打开 Finder2right 检查", action: nil, keyEquivalent: ""))
            }
            menu.addItem(.separator())
        }
        do {
            menuTypes = try FileTypes.load().filter(\.isEnabled)
        } catch {
            menuTypes = []
            let item = NSMenuItem(title: "配置读取失败，请打开 Finder2right 检查", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            return menu
        }
        if menuTypes.isEmpty {
            guard menuKind == .toolbarItemMenu else { return nil }
            let item = NSMenuItem(title: "未启用文件类型", action: nil, keyEquivalent: "")
            item.isEnabled = false
            menu.addItem(item)
            return menu
        }
        let submenu: NSMenu
        if menuKind == .toolbarItemMenu {
            submenu = menu
        } else {
            let newFileItem = NSMenuItem(title: "新建文件", action: nil, keyEquivalent: "")
            submenu = NSMenu(title: "新建文件")
            newFileItem.submenu = submenu
            menu.addItem(newFileItem)
        }
        for (tag, type) in menuTypes.enumerated() {
            let item = NSMenuItem(title: "新建" + type.name + "…", action: #selector(createFile(_:)), keyEquivalent: "")
            // Finder copies only supported menu properties; representedObject is not preserved.
            item.tag = tag
            submenu.addItem(item)
        }
        return menu
    }

    @objc private func openTerminal(_ sender: NSMenuItem) {
        guard let directory = FIFinderSyncController.default().targetedURL() else { return }
        guard let url = FinderRequest(action: .openTerminal, directory: directory).url else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func runTerminalCommand(_ sender: NSMenuItem) {
        guard menuCommands.indices.contains(sender.tag),
              let directory = FIFinderSyncController.default().targetedURL() else { return }
        guard let url = FinderRequest(action: .runCommand(menuCommands[sender.tag].id), directory: directory).url else { return }
        NSWorkspace.shared.open(url)
    }

    @objc private func createFile(_ sender: NSMenuItem) {
        guard menuTypes.indices.contains(sender.tag),
              let directory = FIFinderSyncController.default().targetedURL() else { return }
        guard let url = FinderRequest(action: .createFile(menuTypes[sender.tag].id), directory: directory).url else { return }
        NSWorkspace.shared.open(url)
    }
}
