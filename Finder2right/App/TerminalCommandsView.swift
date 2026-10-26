import SwiftUI

struct TerminalCommandsView: View {
    @ObservedObject var store: TerminalCommandStore
    @Binding var selection: UUID?
    @State private var editingCommand: TerminalCommand?

    private var selectedIndex: Int? { store.commands.firstIndex { $0.id == selection } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("在 Finder 当前文件夹中，通过终端运行常用命令。")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Table(store.commands, selection: $selection) {
                TableColumn("启用") { command in
                    Toggle("启用 \(command.name)", isOn: Binding(
                        get: { store.commands.first { $0.id == command.id }?.isEnabled ?? false },
                        set: { value in
                            guard let index = store.commands.firstIndex(where: { $0.id == command.id }) else { return }
                            var commands = store.commands
                            commands[index].isEnabled = value
                            apply(commands)
                        }
                    ))
                    .toggleStyle(.checkbox).labelsHidden()
                }
                .width(40)
                TableColumn("名称") { command in
                    Label(command.name, systemImage: "terminal").lineLimit(1)
                        .onTapGesture(count: 2) { editingCommand = command }
                }
                .width(min: 190, ideal: 230)
                TableColumn("命令") { command in
                    Text(command.command).font(.system(size: 11, design: .monospaced))
                        .foregroundStyle(.secondary).lineLimit(1).help(command.command)
                        .onTapGesture(count: 2) { editingCommand = command }
                }
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .frame(minHeight: 140, maxHeight: .infinity)
            .border(Color(nsColor: .separatorColor).opacity(0.6))
            .overlay {
                if store.commands.isEmpty {
                    Text("点击下方 ＋ 添加常用终端命令。")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            ConfigurationControls(
                selectionIndex: selectedIndex, count: store.commands.count,
                delete: {
                    guard let index = selectedIndex else { return }
                    var commands = store.commands
                    commands.remove(at: index)
                    apply(commands)
                    if !store.commands.contains(where: { $0.id == selection }) { selection = nil }
                },
                move: { offset in
                    guard let index = selectedIndex, store.commands.indices.contains(index + offset) else { return }
                    var commands = store.commands
                    commands.swapAt(index, index + offset)
                    apply(commands)
                },
                edit: {
                    if let index = selectedIndex { editingCommand = store.commands[index] }
                },
                previewTitle: "终端命令",
                previewItems: store.commands.filter(\.isEnabled).map(\.name)
            ) {
                Button {
                    editingCommand = TerminalCommand(name: "", command: "")
                } label: { Image(systemName: "plus") }
                .help("添加命令").accessibilityLabel("添加命令")
            }
            Text("支持多行命令。命令会直接执行，请仅添加可信内容。")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .sheet(item: $editingCommand) { command in
            TerminalCommandEditor(command: command) { edited in
                var commands = store.commands
                if let index = commands.firstIndex(where: { $0.id == edited.id }) {
                    commands[index] = edited
                } else {
                    commands.append(edited)
                }
                try store.apply(commands)
                selection = edited.id
            }
        }
    }

    private func apply(_ commands: [TerminalCommand]) {
        do { try store.apply(commands) }
        catch { store.errorMessage = error.localizedDescription }
    }
}

private struct TerminalCommandEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var command: TerminalCommand
    let save: (TerminalCommand) throws -> Void
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("编辑终端命令").font(.system(size: 13, weight: .semibold))
            Form {
                TextField("显示名称：", text: $command.name)
                    .accessibilityLabel("命令显示名称")
                LabeledContent("命令内容：") {
                    TextEditor(text: $command.command)
                        .font(.system(size: 12, design: .monospaced))
                        .padding(4).frame(height: 112)
                        .border(Color(nsColor: .separatorColor))
                        .accessibilityLabel("终端命令内容")
                }
                Toggle("在 Finder 菜单中显示", isOn: $command.isEnabled)
            }
            .formStyle(.columns)
            Text("在 Finder 当前文件夹中执行，请仅添加可信命令。首次需允许控制 Terminal。")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle")
                    .font(.callout).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("完成") {
                    do { try save(command); dismiss() }
                    catch { errorMessage = error.localizedDescription }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(command.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || command.command.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty)
            }
        }
        .padding(24).frame(width: 440)
    }
}
