import AppKit

private final class SourceTextView: NSTextView {
    override func setFrameSize(_ newSize: NSSize) {
        let side: CGFloat = newSize.width < 500 ? 14 : (newSize.width < 800 ? 28 : 40)
        let vertical: CGFloat = newSize.width < 500 ? 14 : 28
        let inset = NSSize(width: side, height: vertical)
        if textContainerInset != inset { textContainerInset = inset }
        super.setFrameSize(newSize)
    }
}

final class SourceView: NSView {
    let scrollView: NSScrollView
    let textView: NSTextView

    override var isFlipped: Bool { true }

    override init(frame: NSRect) {
        let storage = NSTextStorage()
        let layoutManager = NSLayoutManager()
        let container = NSTextContainer(size: NSSize(width: frame.width, height: .greatestFiniteMagnitude))
        container.widthTracksTextView = true
        container.heightTracksTextView = false
        storage.addLayoutManager(layoutManager)
        layoutManager.addTextContainer(container)

        let text = SourceTextView(frame: NSRect(origin: .zero, size: frame.size), textContainer: container)
        text.isEditable = false
        text.isSelectable = true
        text.allowsUndo = false
        text.isRichText = false
        text.drawsBackground = true
        text.backgroundColor = Renderer.background
        text.isVerticallyResizable = true
        text.isHorizontallyResizable = false
        text.autoresizingMask = [.width]
        text.minSize = NSSize(width: 0, height: 0)
        text.maxSize = NSSize(width: CGFloat.greatestFiniteMagnitude, height: CGFloat.greatestFiniteMagnitude)
        textView = text

        let scroll = NSScrollView(frame: NSRect(origin: .zero, size: frame.size))
        scroll.hasVerticalScroller = true
        scroll.hasHorizontalScroller = false
        scroll.autohidesScrollers = true
        scroll.borderType = .noBorder
        scroll.drawsBackground = true
        scroll.backgroundColor = Renderer.background
        scroll.documentView = text
        scrollView = scroll

        super.init(frame: frame)
        addSubview(scroll)
    }

    required init?(coder: NSCoder) {
        return nil
    }

    override func layout() {
        super.layout()
        scrollView.frame = bounds
    }

    func show(_ text: NSAttributedString) {
        textView.textStorage?.setAttributedString(text)
        textView.scrollToBeginningOfDocument(nil)
    }
}
