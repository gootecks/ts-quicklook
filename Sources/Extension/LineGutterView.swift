import AppKit

final class LineGutterView: NSRulerView {
    private static let leftPadding: CGFloat = 8
    private static let gap: CGFloat = 6
    private static let barWidth: CGFloat = 3
    private static let rightPadding: CGFloat = 2

    private weak var textView: NSTextView?
    private weak var observedScrollView: NSScrollView?
    private var lineStarts: [Int] = [0]

    var changes: GitChanges? {
        didSet { needsDisplay = true }
    }

    var font: NSFont {
        didSet {
            updateThickness()
            needsDisplay = true
        }
    }

    init(scrollView: NSScrollView, textView: NSTextView) {
        font = NSFont.monospacedDigitSystemFont(ofSize: 11, weight: .regular)
        self.textView = textView
        observedScrollView = scrollView
        super.init(scrollView: scrollView, orientation: .verticalRuler)
        clientView = textView

        scrollView.contentView.postsBoundsChangedNotifications = true
        textView.postsFrameChangedNotifications = true
        NotificationCenter.default.addObserver(
            self, selector: #selector(viewportChanged(_:)),
            name: NSView.boundsDidChangeNotification, object: scrollView.contentView
        )
        NotificationCenter.default.addObserver(
            self, selector: #selector(viewportChanged(_:)),
            name: NSView.frameDidChangeNotification, object: textView
        )
        reload()
    }

    @available(*, unavailable)
    required init(coder _: NSCoder) {
        fatalError("not used")
    }

    deinit {
        NotificationCenter.default.removeObserver(self)
    }

    @objc private func viewportChanged(_: Notification) {
        needsDisplay = true
    }

    func reload() {
        let text = (textView?.string ?? "") as NSString
        let length = text.length
        var starts = [0]
        var index = 0
        while index < length {
            let unit = text.character(at: index)
            if unit == 0x0A {
                starts.append(index + 1)
            } else if unit == 0x0D {
                if index + 1 < length, text.character(at: index + 1) == 0x0A {
                    index += 1
                }
                starts.append(index + 1)
            }
            index += 1
        }
        lineStarts = starts
        updateThickness()
        needsDisplay = true
    }

    private func updateThickness() {
        let digits = max(2, String(lineStarts.count).count)
        let digitWidth = ("0" as NSString).size(withAttributes: [.font: font]).width
        ruleThickness = ceil(digitWidth * CGFloat(digits))
            + Self.leftPadding + Self.gap + Self.barWidth + Self.rightPadding
    }

    private func lineIndex(forCharacter character: Int) -> Int {
        var low = 0
        var high = lineStarts.count - 1
        while low < high {
            let mid = (low + high + 1) / 2
            if lineStarts[mid] <= character {
                low = mid
            } else {
                high = mid - 1
            }
        }
        return low
    }

    private struct DrawContext {
        let dirtyRect: NSRect
        let origin: NSPoint
        let barX: CGFloat
        let numberRight: CGFloat
        let attributes: [NSAttributedString.Key: Any]
        let lineHeight: CGFloat
        let deletions: Set<Int>
    }

    override func draw(_ dirtyRect: NSRect) {
        let background = textView?.backgroundColor ?? NSColor.textBackgroundColor
        background.setFill()
        bounds.fill()

        NSColor.separatorColor.setFill()
        NSRect(x: bounds.maxX - 1, y: bounds.minY, width: 1, height: bounds.height).fill()

        guard let textView,
              let layoutManager = textView.layoutManager,
              let container = textView.textContainer
        else { return }

        let origin = textView.textContainerOrigin
        let containerRect = textView.visibleRect.offsetBy(dx: -origin.x, dy: -origin.y)
        let barX = bounds.maxX - Self.rightPadding - Self.barWidth
        let context = DrawContext(
            dirtyRect: dirtyRect,
            origin: origin,
            barX: barX,
            numberRight: barX - Self.gap,
            attributes: [.font: font, .foregroundColor: NSColor.tertiaryLabelColor],
            lineHeight: ceil(font.ascender - font.descender + font.leading),
            deletions: changes?.deletions ?? []
        )
        let lineCount = lineStarts.count
        var lastLineRect: NSRect?

        if layoutManager.numberOfGlyphs > 0 {
            let glyphRange = layoutManager.glyphRange(forBoundingRect: containerRect, in: container)
            layoutManager.enumerateLineFragments(forGlyphRange: glyphRange) { rect, _, _, fragmentGlyphs, _ in
                let character = layoutManager.characterIndexForGlyph(at: fragmentGlyphs.location)
                let line = self.lineIndex(forCharacter: character)
                let first = self.lineStarts[line] == character
                self.drawFragment(rect, line: line, first: first, context: context)
                if line == lineCount - 1 {
                    lastLineRect = rect
                }
            }
        }

        let extra = layoutManager.extraLineFragmentRect
        if extra.height > 0, extra.maxY >= containerRect.minY, extra.minY <= containerRect.maxY {
            drawFragment(extra, line: lineCount - 1, first: true, context: context)
            lastLineRect = extra
        }

        if context.deletions.contains(lineCount + 1), let rect = lastLineRect {
            let ruler = rulerRect(rect, origin: origin)
            drawMarker(atY: isFlipped ? ruler.maxY : ruler.minY)
        }
    }

    private func rulerRect(_ rect: NSRect, origin: NSPoint) -> NSRect {
        guard let textView else { return rect }
        return convert(rect.offsetBy(dx: origin.x, dy: origin.y), from: textView)
    }

    private func drawFragment(_ rect: NSRect, line: Int, first: Bool, context: DrawContext) {
        let ruler = rulerRect(rect, origin: context.origin)
        if ruler.maxY < context.dirtyRect.minY || ruler.minY > context.dirtyRect.maxY {
            return
        }
        let number = line + 1
        if let kind = changes?.lines[number] {
            (kind == .added ? NSColor.systemGreen : NSColor.systemOrange).setFill()
            NSRect(x: context.barX, y: ruler.minY, width: Self.barWidth, height: ruler.height).fill()
        }
        if first {
            let label = String(number) as NSString
            let size = label.size(withAttributes: context.attributes)
            let labelY = ruler.minY + (ruler.height - max(size.height, context.lineHeight)) / 2
            label.draw(
                at: NSPoint(x: context.numberRight - size.width, y: labelY),
                withAttributes: context.attributes
            )
            if context.deletions.contains(number) {
                drawMarker(atY: isFlipped ? ruler.minY : ruler.maxY)
            }
        }
    }

    private func drawMarker(atY markerY: CGFloat) {
        let right = bounds.maxX - 1
        let path = NSBezierPath()
        path.move(to: NSPoint(x: right - 6, y: markerY - 3))
        path.line(to: NSPoint(x: right, y: markerY))
        path.line(to: NSPoint(x: right - 6, y: markerY + 3))
        path.close()
        NSColor.systemRed.setFill()
        path.fill()
    }
}
