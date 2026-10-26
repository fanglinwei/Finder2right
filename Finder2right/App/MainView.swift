import FinderSync
import SwiftUI

struct MainView: View {
    @ObservedObject var store: FileTypeStore
    @StateObject private var commands = TerminalCommandStore()
    @State private var section = 0
    @State private var typeSelection: UUID?
    @State private var commandSelection: UUID?

    private var errorMessage: String? {
        section == 0 ? store.errorMessage : (section == 1 ? commands.errorMessage : nil)
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if section == 0 {
                FileTypesView(store: store, selection: $typeSelection)
            } else if section == 1 {
                TerminalCommandsView(store: commands, selection: $commandSelection)
            } else {
                LauncherSettingsView()
            }
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle")
                    .font(.callout).foregroundStyle(.red)
                    .fixedSize(horizontal: false, vertical: true)
                    .textSelection(.enabled)
            }
            Divider()
            HStack {
                Button("Finder 扩展设置…") {
                    FIFinderSyncController.showExtensionManagementInterface()
                }
                .controlSize(.small)
                Spacer()
                if section != 2 {
                    Text("\(section == 0 ? store.savedTypes.filter(\.isEnabled).count : commands.commands.filter(\.isEnabled).count) 项已启用")
                        .font(.system(size: 11)).foregroundStyle(.secondary)
                }
            }
        }
        .padding(20)
        .frame(width: 720, height: 414)
        .background(Color(nsColor: .windowBackgroundColor))
        .toolbar {
            ToolbarItem(placement: .principal) {
                Picker("配置页面", selection: $section) {
                    Text("文件类型").tag(0)
                    Text("终端命令").tag(1)
                    Text("启动器").tag(2)
                }
                .pickerStyle(.segmented)
                .frame(width: 320)
            }
        }
        .onAppear {
            typeSelection = store.types.first?.id
            commandSelection = commands.commands.first?.id
        }
    }
}

struct ConfigurationControls<Add: View>: View {
    let selectionIndex: Int?
    let count: Int
    let delete: () -> Void
    let move: (Int) -> Void
    let edit: () -> Void
    let previewTitle: String
    let previewItems: [String]
    @ViewBuilder var add: Add
    @State private var isPreviewShown = false

    var body: some View {
        HStack(spacing: 8) {
            ControlGroup {
                add
                Button(action: delete) { Image(systemName: "minus") }
                    .disabled(selectionIndex == nil)
                    .help("移除").accessibilityLabel("移除")
            }
            .fixedSize()
            ControlGroup {
                Button { move(-1) } label: { Image(systemName: "arrow.up") }
                    .disabled(selectionIndex == nil || selectionIndex == 0)
                    .help("上移").accessibilityLabel("上移")
                Button { move(1) } label: { Image(systemName: "arrow.down") }
                    .disabled(selectionIndex == nil || selectionIndex == count - 1)
                    .help("下移").accessibilityLabel("下移")
            }
            .fixedSize()
            Spacer()
            Button("菜单预览") { isPreviewShown.toggle() }
                .popover(isPresented: $isPreviewShown, arrowEdge: .bottom) {
                    VStack(alignment: .leading, spacing: 0) {
                        Text(previewTitle).font(.system(size: 12, weight: .semibold)).padding(10)
                        Divider().padding(.bottom, 4)
                        ScrollView {
                            VStack(alignment: .leading, spacing: 0) {
                                ForEach(Array(previewItems.enumerated()), id: \.offset) { _, title in
                                    Text(title).font(.system(size: 13))
                                        .padding(.vertical, 5).padding(.horizontal, 10)
                                }
                                if previewItems.isEmpty {
                                    Text("未启用条目").foregroundStyle(.secondary).padding(10)
                                }
                            }
                            .frame(maxWidth: .infinity, alignment: .leading)
                        }
                        .frame(maxHeight: min(CGFloat(max(previewItems.count, 1)) * 28 + 12, 280))
                    }
                    .padding(6).frame(width: 280, alignment: .leading)
                }
            Button("编辑…", action: edit).disabled(selectionIndex == nil)
        }
        .controlSize(.small)
    }
}
