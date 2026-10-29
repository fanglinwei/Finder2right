import AppKit

final class TerminalCommandAlert: NSAlert {
    static func confirmation(command: TerminalCommand, directory: URL) -> NSAlert {
        let alert = TerminalCommandAlert()
        alert.messageText = "执行“\(command.name)”？"
        alert.informativeText = "将在终端中运行。"
        alert.alertStyle = .informational
        alert.icon = NSImage(systemSymbolName: "terminal", accessibilityDescription: "终端命令")
        alert.addButton(withTitle: "执行").keyEquivalent = "\r"
        alert.addButton(withTitle: "取消").keyEquivalent = "\u{1b}"

        let content = NSStackView()
        content.orientation = .vertical
        content.alignment = .leading
        content.spacing = 6
        let previews: [(title: String, value: String, maximumHeight: CGFloat, font: NSFont)] = [
            ("命令", command.command, 96, .monospacedSystemFont(ofSize: 13, weight: .regular)),
            ("执行目录", directory.path, 64, .systemFont(ofSize: 12))
        ]
        for (title, value, maximumHeight, font) in previews {
            let label = NSTextField(labelWithString: title)
            label.font = .systemFont(ofSize: 11, weight: .medium)
            label.textColor = .secondaryLabelColor
            content.addArrangedSubview(label)

            let scrollView = NSScrollView()
            scrollView.borderType = .noBorder
            scrollView.drawsBackground = false
            scrollView.wantsLayer = true
            scrollView.layer?.cornerRadius = 8
            scrollView.layer?.masksToBounds = true
            scrollView.layer?.borderWidth = 1
            scrollView.layer?.borderColor = NSColor.gray.withAlphaComponent(0.25).cgColor
            scrollView.hasVerticalScroller = true
            scrollView.autohidesScrollers = true
            let textView = NSTextView(frame: NSRect(x: 0, y: 0, width: 360, height: maximumHeight))
            textView.string = value
            textView.font = font
            textView.textColor = .labelColor
            textView.backgroundColor = NSColor(name: nil) { appearance in
                appearance.bestMatch(from: [.darkAqua, .aqua]) == .darkAqua
                    ? NSColor(white: 0.22, alpha: 1) : .textBackgroundColor
            }
            textView.isEditable = false
            textView.isSelectable = true
            textView.isRichText = false
            textView.textContainerInset = NSSize(width: 8, height: 8)
            textView.isVerticallyResizable = true
            textView.autoresizingMask = [.width]
            textView.textContainer?.widthTracksTextView = true
            textView.setAccessibilityLabel(title)
            var height = maximumHeight
            if let container = textView.textContainer, let layout = textView.layoutManager {
                layout.ensureLayout(for: container)
                height = min(maximumHeight, ceil(layout.usedRect(for: container).height) + 16)
            }
            scrollView.documentView = textView
            content.addArrangedSubview(scrollView)
            NSLayoutConstraint.activate([
                scrollView.widthAnchor.constraint(equalToConstant: 360),
                scrollView.heightAnchor.constraint(equalToConstant: height)
            ])
            content.setCustomSpacing(10, after: scrollView)
        }
        content.frame.size = content.fittingSize
        alert.accessoryView = content
        return alert
    }

    override func layout() {
        super.layout()
        // Keep the system alert styling while tightening the header spacing.
        guard let content = window.contentView else { return }
        let textFields = content.subviews.compactMap { $0 as? NSTextField }
        guard let iconView = content.subviews.compactMap({ $0 as? NSImageView }).first,
              let heading = textFields.first(where: { $0.stringValue == messageText }),
              let subtitle = textFields.first(where: { $0.stringValue == informativeText }) else { return }
        let x = iconView.frame.maxX + 16
        let width = content.bounds.width - x - 20
        let bounds = NSRect(x: 0, y: 0, width: width, height: .greatestFiniteMagnitude)
        let headingHeight = ceil(heading.cell?.cellSize(forBounds: bounds).height ?? heading.frame.height)
        let subtitleHeight = subtitle.frame.height
        let height = headingHeight + 8 + subtitleHeight
        guard height <= iconView.frame.height else { return }
        if let details = accessoryView?.superview {
            let reduction = max(0, iconView.frame.minY - details.frame.maxY - 12)
            let frames = content.subviews.map { ($0, $0.frame) }
            window.setContentSize(NSSize(width: content.bounds.width, height: content.bounds.height - reduction))
            for (view, frame) in frames {
                view.frame = view === iconView ? frame.offsetBy(dx: 0, dy: -reduction) : frame
            }
        }
        let y = iconView.frame.midY - height / 2
        heading.frame = NSRect(x: x, y: y + subtitleHeight + 8, width: width, height: headingHeight)
        subtitle.frame = NSRect(x: x, y: y, width: width, height: subtitleHeight)
    }
}
