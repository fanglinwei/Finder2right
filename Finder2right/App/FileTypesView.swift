import SwiftUI

struct FileTypesView: View {
    @ObservedObject var store: FileTypeStore
    @Binding var selection: UUID?
    @State private var editingType: FileType?

    private var selectedIndex: Int? { store.types.firstIndex { $0.id == selection } }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("选择在 Finder 新建菜单中显示的文件类型。")
                .font(.system(size: 12)).foregroundStyle(.secondary)
            Table(store.types, selection: $selection) {
                TableColumn("启用") { type in
                    Toggle("启用 \(type.name)", isOn: Binding(
                        get: { store.types.first { $0.id == type.id }?.isEnabled ?? false },
                        set: { value in
                            guard let index = store.types.firstIndex(where: { $0.id == type.id }) else { return }
                            var types = store.types
                            types[index].isEnabled = value
                            apply(types)
                        }
                    ))
                    .toggleStyle(.checkbox).labelsHidden()
                }
                .width(40)
                TableColumn("名称") { type in
                    Label(type.name, systemImage: "doc").lineLimit(1)
                        .onTapGesture(count: 2) { editingType = type }
                }
                .width(min: 190, ideal: 230)
                TableColumn("扩展名") { type in
                    Text("." + type.fileExtension).foregroundStyle(.secondary).lineLimit(1)
                        .onTapGesture(count: 2) { editingType = type }
                }
            }
            .tableStyle(.inset(alternatesRowBackgrounds: true))
            .frame(minHeight: 140, maxHeight: .infinity)
            .border(Color(nsColor: .separatorColor).opacity(0.6))
            .overlay {
                if store.types.isEmpty {
                    Text("点击下方 ＋ 添加文件类型。")
                        .font(.callout).foregroundStyle(.secondary)
                }
            }
            ConfigurationControls(
                selectionIndex: selectedIndex, count: store.types.count,
                delete: {
                    guard let index = selectedIndex else { return }
                    var types = store.types
                    types.remove(at: index)
                    apply(types)
                    if !store.types.contains(where: { $0.id == selection }) { selection = nil }
                },
                move: { offset in
                    guard let index = selectedIndex, store.types.indices.contains(index + offset) else { return }
                    var types = store.types
                    types.swapAt(index, index + offset)
                    apply(types)
                },
                edit: {
                    if let index = selectedIndex { editingType = store.types[index] }
                },
                previewTitle: "新建文件",
                previewItems: store.savedTypes.filter(\.isEnabled).map { "新建" + $0.name + "…" }
            ) { addMenu }
            Text("创建空白文件，不包含模板内容。双击条目可编辑。")
                .font(.system(size: 11)).foregroundStyle(.secondary)
        }
        .sheet(item: $editingType) { type in
            FileTypeEditor(type: type) { edited in
                var types = store.types
                if let index = types.firstIndex(where: { $0.id == edited.id }) {
                    types[index] = edited
                } else {
                    types.append(edited)
                }
                try store.apply(types)
                selection = edited.id
            }
        }
    }

    private var addMenu: some View {
        Menu {
            ForEach(FileTypes.presetGroups, id: \.name) { group in
                Menu(group.name) {
                    ForEach(group.types) { preset in
                        let isAdded = store.types.contains {
                            $0.fileExtension.caseInsensitiveCompare(preset.fileExtension) == .orderedSame
                        }
                        Button("\(preset.name) (.\(preset.fileExtension))\(isAdded ? " · 已添加" : "")") {
                            editingType = FileType(name: preset.name, fileExtension: preset.fileExtension)
                        }
                        .disabled(isAdded)
                    }
                }
            }
            Divider()
            Button("自定义类型…") { editingType = FileType(name: "", fileExtension: "") }
        } label: { Image(systemName: "plus") }
        .menuIndicator(.hidden)
        .help("添加文件类型").accessibilityLabel("添加文件类型")
    }

    private func apply(_ types: [FileType]) {
        do { try store.apply(types) }
        catch { store.errorMessage = error.localizedDescription }
    }
}

private struct FileTypeEditor: View {
    @Environment(\.dismiss) private var dismiss
    @State var type: FileType
    let save: (FileType) throws -> Void
    @State private var errorMessage: String?

    var body: some View {
        VStack(alignment: .leading, spacing: 18) {
            Text("编辑文件类型").font(.system(size: 13, weight: .semibold))
            Form {
                TextField("显示名称：", text: $type.name)
                    .accessibilityLabel("显示名称")
                TextField("扩展名：", text: $type.fileExtension)
                    .accessibilityLabel("扩展名")
                Toggle("在 Finder 菜单中显示", isOn: $type.isEnabled)
            }
            .formStyle(.columns)
            Text("只创建空白文件，不写入模板内容。支持 tar.gz 等多段扩展名。")
                .font(.system(size: 11)).foregroundStyle(.secondary)
            if let errorMessage {
                Label(errorMessage, systemImage: "exclamationmark.circle")
                    .font(.callout).foregroundStyle(.red).fixedSize(horizontal: false, vertical: true)
            }
            HStack {
                Spacer()
                Button("取消") { dismiss() }.keyboardShortcut(.cancelAction)
                Button("完成") {
                    do { try save(type); dismiss() }
                    catch { errorMessage = error.localizedDescription }
                }
                .keyboardShortcut(.defaultAction)
                .disabled(type.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty || type.fileExtension.isEmpty)
            }
        }
        .padding(24).frame(width: 360)
    }
}
