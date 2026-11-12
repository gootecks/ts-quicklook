import AppKit

final class PreviewToolbar: NSView {
    static let height: CGFloat = 28

    var status: String = "" {
        didSet { label.stringValue = status }
    }

    var backgroundColor: NSColor = NSColor.textBackgroundColor {
        didSet { needsDisplay = true }
    }

    var copyText: (() -> String)? {
        didSet { button.isEnabled = copyText != nil }
    }

    private let label = NSTextField(labelWithString: "")
    private let button = NSButton(title: "Copy", target: nil, action: nil)
    private var resetWork: DispatchWorkItem?

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        super.init(frame: frame)
        label.isEditable = false
        label.isSelectable = false
        label.isBordered = false
        label.drawsBackground = false
        label.font = NSFont.systemFont(ofSize: 11)
        label.textColor = NSColor.secondaryLabelColor
        label.lineBreakMode = .byTruncatingTail
        label.maximumNumberOfLines = 1
        label.usesSingleLineMode = true
        label.stringValue = status
        addSubview(label)

        button.image = NSImage(systemSymbolName: "doc.on.doc", accessibilityDescription: "Copy")
        button.imagePosition = .imageLeading
        button.controlSize = .small
        button.bezelStyle = .recessed
        button.isBordered = true
        button.target = self
        button.action = #selector(copyClicked)
        button.isEnabled = copyText != nil
        addSubview(button)
    }

    required init?(coder: NSCoder) {
        fatalError("not used")
    }

    @objc private func copyClicked() {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(copyText?() ?? "", forType: .string)
        button.title = "Copied"
        needsLayout = true
        resetWork?.cancel()
        let work = DispatchWorkItem { [weak self] in
            self?.button.title = "Copy"
            self?.needsLayout = true
        }
        resetWork = work
        DispatchQueue.main.asyncAfter(deadline: .now() + 1.5, execute: work)
    }

    override func draw(_ dirtyRect: NSRect) {
        backgroundColor.setFill()
        bounds.fill()
        NSColor.separatorColor.setFill()
        let y = isFlipped ? bounds.maxY - 1 : bounds.minY
        NSRect(x: bounds.minX, y: y, width: bounds.width, height: 1).fill()
    }

    override func layout() {
        super.layout()
        button.sizeToFit()
        let bs = button.frame.size
        let bx = bounds.width - 8 - bs.width
        button.frame = NSRect(x: bx, y: ((bounds.height - bs.height) / 2).rounded(), width: bs.width, height: bs.height)

        label.isHidden = bounds.width < 220
        let lh = label.intrinsicContentSize.height
        let lw = max(0, bx - 8 - 10)
        label.frame = NSRect(x: 10, y: ((bounds.height - lh) / 2).rounded(), width: lw, height: lh)
    }
}
