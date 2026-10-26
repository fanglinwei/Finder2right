import SwiftUI

struct LauncherSettingsView: View {
    @State private var settings = LauncherSettings()
    @State private var savedSettings = LauncherSettings()
    @State private var errorMessage: String?

    private var launcherURL: URL {
        Bundle.main.bundleURL.appendingPathComponent("Contents/Helpers/Finder2right Launcher.app")
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 16) {
                LauncherDragIcon(launcherURL: launcherURL)
                    .frame(width: 56, height: 56)
                    .help("按住 ⌘ 将此图标拖到 Finder 工具栏")
                    .accessibilityLabel("工具栏启动器，可拖到 Finder 工具栏")
                VStack(alignment: .leading, spacing: 4) {
                    Text("添加到 Finder 工具栏").font(.headline)
                    Text("按住 ⌘ Command，将左侧图标直接拖到 Finder 工具栏。")
                        .font(.callout).foregroundStyle(.secondary)
                    Button("在 Finder 中显示启动器…") {
                        NSWorkspace.shared.activateFileViewerSelecting([launcherURL])
                    }
                    .controlSize(.small)
                }
            }
            Divider()
            Picker("点击启动器时：", selection: $settings.action) {
                ForEach(LauncherSettings.Action.allCases, id: \.self) { action in
                    Text(action.title).tag(action)
                }
            }
            .pickerStyle(.radioGroup)
            if settings.action == .customCommand {
                TextEditor(text: $settings.command)
                    .font(.system(size: 12, design: .monospaced))
                    .padding(4).frame(height: 70)
                    .border(Color(nsColor: .separatorColor))
                    .accessibilityLabel("启动器自定义终端命令")
                Text("在 Finder 当前文件夹中执行，支持多行命令。请仅填写可信命令；首次需允许控制 Terminal。")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
            }
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle")
                    .font(.callout).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            Spacer(minLength: 0)
            HStack {
                Text(settings == savedSettings ? "配置已保存，下次点击启动器生效" : "更改后请保存配置")
                    .font(.system(size: 11)).foregroundStyle(.secondary)
                Spacer()
                Button("保存配置") {
                    do {
                        try LauncherSettings.save(settings)
                        savedSettings = settings
                        errorMessage = nil
                    } catch { errorMessage = error.localizedDescription }
                }
                .disabled(settings == savedSettings)
            }
        }
        .onAppear {
            do {
                settings = try LauncherSettings.load()
                savedSettings = settings
            } catch { errorMessage = "读取启动器配置失败：\(error.localizedDescription)" }
        }
    }
}

private struct LauncherDragIcon: NSViewRepresentable {
    let launcherURL: URL

    func makeNSView(context: Context) -> LauncherDragImageView {
        let view = LauncherDragImageView()
        view.imageScaling = .scaleProportionallyUpOrDown
        view.setAccessibilityLabel("工具栏启动器，可拖到 Finder 工具栏")
        return view
    }

    func updateNSView(_ view: LauncherDragImageView, context: Context) {
        view.launcherURL = launcherURL
        view.image = NSWorkspace.shared.icon(forFile: launcherURL.path)
    }
}

final class LauncherDragImageView: NSImageView, NSDraggingSource {
    var launcherURL: URL?

    override func mouseDown(with event: NSEvent) {}

    override func mouseDragged(with event: NSEvent) {
        guard let item = draggingItem() else { return }
        beginDraggingSession(with: [item], event: event, source: self)
    }

    func draggingItem() -> NSDraggingItem? {
        guard let launcherURL, launcherURL.isFileURL,
              FileManager.default.fileExists(atPath: launcherURL.path) else { return nil }
        // Write the original file URL; SwiftUI item providers materialize a detached App in their drag cache.
        let item = NSDraggingItem(pasteboardWriter: launcherURL as NSURL)
        item.setDraggingFrame(bounds, contents: image)
        return item
    }

    func draggingSession(_ session: NSDraggingSession, sourceOperationMaskFor context: NSDraggingContext) -> NSDragOperation {
        .link
    }

    func ignoreModifierKeys(for session: NSDraggingSession) -> Bool { true }
}
