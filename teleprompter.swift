import Cocoa

// MARK: - Save file path

let saveURL: URL = {
    let dir = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask).first!
        .appendingPathComponent("Teleprompter", isDirectory: true)
    try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
    return dir.appendingPathComponent("notes.json")
}()

// MARK: - Persisted state

struct AppState: Codable {
    var notes: String
    var x: Double
    var y: Double
    var width: Double
    var height: Double
    var fontSize: Double
    var opacity: Double
}

let defaultNotes = """
# Welcome to Teleprompter!

Click **Edit** to add your notes for the call.

## Tips
- Drag the title bar to **reposition**
- Resize from the bottom-right corner
- Adjust opacity to see through
- Toggle **Pass-through** to click through the notes area

## Markdown Supported
- **bold text** and *italic text*
- `inline code` formatting
- Bullet points and numbered lists
- > Blockquotes for emphasis

---

Your notes save automatically.
"""

func loadState() -> AppState {
    guard let data = try? Data(contentsOf: saveURL),
          let state = try? JSONDecoder().decode(AppState.self, from: data) else {
        let screen = NSScreen.main?.visibleFrame ?? NSRect(x: 0, y: 0, width: 1280, height: 800)
        return AppState(
            notes: defaultNotes,
            x: Double(screen.origin.x),
            y: Double(screen.origin.y),
            width: Double(screen.width),
            height: Double(screen.height),
            fontSize: 20,
            opacity: 0.88
        )
    }
    return state
}

func saveState(_ state: AppState) {
    if let data = try? JSONEncoder().encode(state) {
        try? data.write(to: saveURL, options: .atomic)
    }
}

// MARK: - Markdown Renderer

class MarkdownRenderer {
    let baseFontSize: CGFloat
    let textColor = NSColor(white: 0.92, alpha: 1)

    init(baseFontSize: CGFloat) {
        self.baseFontSize = baseFontSize
    }

    func render(_ markdown: String) -> NSAttributedString {
        let result = NSMutableAttributedString()
        let lines = markdown.components(separatedBy: "\n")

        for (i, line) in lines.enumerated() {
            let rendered = renderLine(line)
            result.append(rendered)
            if i < lines.count - 1 {
                result.append(NSAttributedString(string: "\n"))
            }
        }
        return result
    }

    private func renderLine(_ line: String) -> NSAttributedString {
        let trimmed = line.trimmingCharacters(in: .whitespaces)

        if trimmed.hasPrefix("### ") {
            return renderHeading(String(trimmed.dropFirst(4)), level: 3)
        } else if trimmed.hasPrefix("## ") {
            return renderHeading(String(trimmed.dropFirst(3)), level: 2)
        } else if trimmed.hasPrefix("# ") {
            return renderHeading(String(trimmed.dropFirst(2)), level: 1)
        } else if trimmed == "---" || trimmed == "***" || trimmed == "___" {
            return renderHorizontalRule()
        } else if trimmed.hasPrefix("- ") || trimmed.hasPrefix("* ") {
            let content = String(trimmed.dropFirst(2))
            return renderBullet(content, prefix: "  •  ")
        } else if let match = trimmed.range(of: #"^(\d+)\.\s+"#, options: .regularExpression) {
            let num = trimmed[match].trimmingCharacters(in: .whitespaces)
            let content = String(trimmed[match.upperBound...])
            return renderBullet(content, prefix: "  \(num) ")
        } else if trimmed.hasPrefix("> ") {
            return renderBlockquote(String(trimmed.dropFirst(2)))
        } else if trimmed.hasPrefix("```") {
            return renderCodeLine(trimmed)
        } else {
            return renderInline(line, font: NSFont.systemFont(ofSize: baseFontSize))
        }
    }

    private func renderHeading(_ text: String, level: Int) -> NSAttributedString {
        let sizes: [Int: CGFloat] = [1: baseFontSize * 1.6, 2: baseFontSize * 1.3, 3: baseFontSize * 1.1]
        let size = sizes[level] ?? baseFontSize
        let font = NSFont.boldSystemFont(ofSize: size)
        let color = NSColor(white: 1.0, alpha: 1)

        let para = NSMutableParagraphStyle()
        para.paragraphSpacingBefore = level == 1 ? 12 : 8
        para.paragraphSpacing = 4

        let result = renderInline(text, font: font)
        let mutable = NSMutableAttributedString(attributedString: result)
        mutable.addAttributes([
            .foregroundColor: color,
            .paragraphStyle: para,
        ], range: NSRange(location: 0, length: mutable.length))
        return mutable
    }

    private func renderHorizontalRule() -> NSAttributedString {
        NSAttributedString(string: "  ─────────────────────────", attributes: [
            .foregroundColor: NSColor(white: 0.35, alpha: 1),
            .font: NSFont.systemFont(ofSize: baseFontSize * 0.6),
        ])
    }

    private func renderBullet(_ text: String, prefix: String) -> NSAttributedString {
        let para = NSMutableParagraphStyle()
        para.headIndent = 24
        para.firstLineHeadIndent = 4

        let bullet = NSMutableAttributedString(string: prefix, attributes: [
            .foregroundColor: NSColor(calibratedRed: 0.4, green: 0.7, blue: 1.0, alpha: 1),
            .font: NSFont.systemFont(ofSize: baseFontSize),
        ])
        let content = renderInline(text, font: NSFont.systemFont(ofSize: baseFontSize))
        bullet.append(content)
        bullet.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: bullet.length))
        return bullet
    }

    private func renderBlockquote(_ text: String) -> NSAttributedString {
        let para = NSMutableParagraphStyle()
        para.firstLineHeadIndent = 16
        para.headIndent = 16

        let bar = NSMutableAttributedString(string: "  ┃ ", attributes: [
            .foregroundColor: NSColor(calibratedRed: 0.5, green: 0.8, blue: 0.5, alpha: 0.7),
            .font: NSFont.systemFont(ofSize: baseFontSize),
        ])
        let content = renderInline(text, font: NSFont(name: "Georgia", size: baseFontSize) ?? NSFont.systemFont(ofSize: baseFontSize))
        let mutable = NSMutableAttributedString(attributedString: content)
        mutable.addAttribute(.foregroundColor, value: NSColor(white: 0.7, alpha: 1), range: NSRange(location: 0, length: mutable.length))
        bar.append(mutable)
        bar.addAttribute(.paragraphStyle, value: para, range: NSRange(location: 0, length: bar.length))
        return bar
    }

    private func renderCodeLine(_ text: String) -> NSAttributedString {
        let mono = NSFont.monospacedSystemFont(ofSize: baseFontSize * 0.85, weight: .regular)
        return NSAttributedString(string: text, attributes: [
            .foregroundColor: NSColor(calibratedRed: 0.6, green: 0.8, blue: 0.6, alpha: 1),
            .font: mono,
            .backgroundColor: NSColor(white: 0.1, alpha: 0.5),
        ])
    }

    private func renderInline(_ text: String, font: NSFont) -> NSAttributedString {
        let result = NSMutableAttributedString()
        var remaining = text[text.startIndex...]

        while !remaining.isEmpty {
            // inline code `...`
            if remaining.hasPrefix("`"),
               let end = remaining.dropFirst().firstIndex(of: "`") {
                let code = String(remaining[remaining.index(after: remaining.startIndex)..<end])
                let mono = NSFont.monospacedSystemFont(ofSize: font.pointSize * 0.88, weight: .regular)
                result.append(NSAttributedString(string: code, attributes: [
                    .font: mono,
                    .foregroundColor: NSColor(calibratedRed: 0.9, green: 0.7, blue: 0.4, alpha: 1),
                    .backgroundColor: NSColor(white: 0.15, alpha: 0.6),
                ]))
                remaining = remaining[remaining.index(after: end)...]
                continue
            }

            // bold **...**
            if remaining.hasPrefix("**"),
               let end = remaining.dropFirst(2).range(of: "**") {
                let bold = String(remaining[remaining.index(remaining.startIndex, offsetBy: 2)..<end.lowerBound])
                let boldFont = NSFontManager.shared.convert(font, toHaveTrait: .boldFontMask)
                result.append(NSAttributedString(string: bold, attributes: [
                    .font: boldFont,
                    .foregroundColor: NSColor(white: 1.0, alpha: 1),
                ]))
                remaining = remaining[end.upperBound...]
                continue
            }

            // italic *...*
            if remaining.hasPrefix("*"),
               let end = remaining.dropFirst().firstIndex(of: "*"),
               end > remaining.index(after: remaining.startIndex) {
                let italic = String(remaining[remaining.index(after: remaining.startIndex)..<end])
                let italicFont = NSFontManager.shared.convert(font, toHaveTrait: .italicFontMask)
                result.append(NSAttributedString(string: italic, attributes: [
                    .font: italicFont,
                    .foregroundColor: NSColor(white: 0.85, alpha: 1),
                ]))
                remaining = remaining[remaining.index(after: end)...]
                continue
            }

            // plain character
            result.append(NSAttributedString(string: String(remaining.first!), attributes: [
                .font: font,
                .foregroundColor: textColor,
            ]))
            remaining = remaining.dropFirst()
        }

        return result
    }
}

// MARK: - Transparent Window

class TransparentWindow: NSWindow {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { true }
}


class ControlsPanel: NSPanel {
    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}

// MARK: - Traffic light button with hover

class TrafficLightButton: NSButton {
    let circleColor: NSColor
    let symbol: String
    let size: CGFloat = 12
    private var isHovered = false
    private var trackingArea: NSTrackingArea?

    init(color: NSColor, symbol: String) {
        self.circleColor = color
        self.symbol = symbol
        super.init(frame: NSRect(x: 0, y: 0, width: 12, height: 12))
        isBordered = false
        title = ""
        wantsLayer = true
        translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            widthAnchor.constraint(equalToConstant: size),
            heightAnchor.constraint(equalToConstant: size),
        ])
    }

    required init?(coder: NSCoder) { fatalError() }

    override func updateTrackingAreas() {
        super.updateTrackingAreas()
        if let t = trackingArea { removeTrackingArea(t) }
        trackingArea = NSTrackingArea(
            rect: bounds, options: [.mouseEnteredAndExited, .activeAlways],
            owner: self, userInfo: nil
        )
        addTrackingArea(trackingArea!)
    }

    override func mouseEntered(with event: NSEvent) {
        isHovered = true
        needsDisplay = true
    }

    override func mouseExited(with event: NSEvent) {
        isHovered = false
        needsDisplay = true
    }

    override func draw(_ dirtyRect: NSRect) {
        let circle = NSBezierPath(ovalIn: bounds.insetBy(dx: 0.5, dy: 0.5))
        circleColor.setFill()
        circle.fill()

        let borderColor = circleColor.blended(withFraction: 0.25, of: .black) ?? circleColor
        borderColor.setStroke()
        circle.lineWidth = 0.5
        circle.stroke()

        if isHovered {
            let attrs: [NSAttributedString.Key: Any] = [
                .font: NSFont.systemFont(ofSize: 8, weight: .bold),
                .foregroundColor: NSColor(white: 0.15, alpha: 0.9),
            ]
            let str = NSAttributedString(string: symbol, attributes: attrs)
            let strSize = str.size()
            let pt = NSPoint(
                x: (bounds.width - strSize.width) / 2,
                y: (bounds.height - strSize.height) / 2
            )
            str.draw(at: pt)
        }
    }
}

// MARK: - Text view that always pastes as plain text

class PlainPasteTextView: NSTextView {
    override func paste(_ sender: Any?) {
        pasteAsPlainText(sender)
    }
}

// MARK: - Main View Controller

class TeleprompterVC: NSViewController {
    var state: AppState
    var scrollTimer: Timer?
    var scrollSpeed: CGFloat = 1.0
    var isScrolling = false
    var isEditing = false
    var isPassthrough = false

    let scrollView = NSScrollView()
    let textView = PlainPasteTextView()
    let editButton = NSButton()
    let scrollButton = NSButton()
    let passthroughButton = NSButton()
    let opacityLabel = NSTextField(labelWithString: "")


    init() {
        self.state = loadState()
        super.init(nibName: nil, bundle: nil)
    }

    required init?(coder: NSCoder) { fatalError() }

    override func loadView() {
        let container = NSView(frame: NSRect(x: 0, y: 0, width: state.width, height: state.height))
        container.wantsLayer = true
        container.layer?.backgroundColor = .clear
        self.view = container
    }

    override func viewDidLoad() {
        super.viewDidLoad()
        buildTextArea()
    }

    func buildControlsInto(_ container: NSView) {
        let leftStack = NSStackView()
        leftStack.orientation = .horizontal
        leftStack.spacing = 1
        leftStack.translatesAutoresizingMaskIntoConstraints = false

        let rightStack = NSStackView()
        rightStack.orientation = .horizontal
        rightStack.spacing = 1
        rightStack.translatesAutoresizingMaskIntoConstraints = false

        container.addSubview(leftStack)
        container.addSubview(rightStack)
        NSLayoutConstraint.activate([
            leftStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            leftStack.leadingAnchor.constraint(equalTo: container.leadingAnchor, constant: 8),

            rightStack.centerYAnchor.constraint(equalTo: container.centerYAnchor),
            rightStack.trailingAnchor.constraint(equalTo: container.trailingAnchor, constant: -4),

            rightStack.leadingAnchor.constraint(greaterThanOrEqualTo: leftStack.trailingAnchor, constant: 8),
        ])

        let closeBtn = makeTrafficLight(
            color: NSColor(calibratedRed: 1.0, green: 0.38, blue: 0.34, alpha: 1),
            symbol: "\u{2715}", action: #selector(closeWindow)
        )
        let minimizeBtn = makeTrafficLight(
            color: NSColor(calibratedRed: 1.0, green: 0.74, blue: 0.21, alpha: 1),
            symbol: "\u{2013}", action: #selector(minimizeWindow)
        )
        let zoomBtn = makeTrafficLight(
            color: NSColor(calibratedRed: 0.28, green: 0.78, blue: 0.25, alpha: 1),
            symbol: "\u{2b}", action: #selector(zoomWindow)
        )

        leftStack.spacing = 7
        for v in [closeBtn, minimizeBtn, zoomBtn] as [NSView] {
            leftStack.addArrangedSubview(v)
        }

        configureCtrlButton(editButton, title: "Edit")
        editButton.target = self
        editButton.action = #selector(toggleEdit)

        configureCtrlButton(scrollButton, title: "Scroll")
        scrollButton.target = self
        scrollButton.action = #selector(toggleScroll)

        configureCtrlButton(passthroughButton, title: "Pass-through: OFF")
        passthroughButton.target = self
        passthroughButton.action = #selector(togglePassthrough)

        let fontDown = makeCtrlButton("A-")
        fontDown.target = self; fontDown.action = #selector(fontSmaller)

        let fontUp = makeCtrlButton("A+")
        fontUp.target = self; fontUp.action = #selector(fontLarger)

        let opDown = makeCtrlButton("-")
        opDown.target = self; opDown.action = #selector(opacityDown)

        let opUp = makeCtrlButton("+")
        opUp.target = self; opUp.action = #selector(opacityUp)

        opacityLabel.font = NSFont.monospacedSystemFont(ofSize: 10, weight: .regular)
        opacityLabel.textColor = NSColor(white: 0.5, alpha: 1)
        updateOpacityLabel()

        let rightItems: [NSView] = [
            opDown, opacityLabel, opUp, makeDivider(),
            fontDown, fontUp, makeDivider(),
            passthroughButton, makeDivider(),
            scrollButton, makeDivider(),
            editButton
        ]
        for v in rightItems {
            rightStack.addArrangedSubview(v)
        }
    }

    var savedFrame: NSRect?

    @objc func closeWindow() {
        state.notes = textView.string
        persistState()
        NSApp.terminate(nil)
    }

    @objc func minimizeWindow() {
        view.window?.miniaturize(nil)
    }

    @objc func zoomWindow() {
        guard let window = view.window,
              let screen = window.screen?.visibleFrame else { return }
        if let saved = savedFrame {
            window.setFrame(saved, display: true, animate: true)
            savedFrame = nil
        } else {
            savedFrame = window.frame
            window.setFrame(screen, display: true, animate: true)
        }
    }

    func makeTrafficLight(color: NSColor, symbol: String, action: Selector) -> TrafficLightButton {
        let btn = TrafficLightButton(color: color, symbol: symbol)
        btn.target = self
        btn.action = action
        return btn
    }

    func makeDivider() -> NSView {
        let d = NSView()
        d.wantsLayer = true
        d.layer?.backgroundColor = NSColor(white: 0.3, alpha: 0.5).cgColor
        d.translatesAutoresizingMaskIntoConstraints = false
        NSLayoutConstraint.activate([
            d.widthAnchor.constraint(equalToConstant: 1),
            d.heightAnchor.constraint(equalToConstant: 18),
        ])
        return d
    }

    // ── Text area ──────────────────────────────────────────────

    func buildTextArea() {
        scrollView.translatesAutoresizingMaskIntoConstraints = false
        scrollView.drawsBackground = false
        scrollView.hasVerticalScroller = true
        scrollView.scrollerStyle = .overlay
        scrollView.autohidesScrollers = true
        scrollView.borderType = .noBorder
        view.addSubview(scrollView)

        NSLayoutConstraint.activate([
            scrollView.topAnchor.constraint(equalTo: view.topAnchor),
            scrollView.leadingAnchor.constraint(equalTo: view.leadingAnchor),
            scrollView.trailingAnchor.constraint(equalTo: view.trailingAnchor),
            scrollView.bottomAnchor.constraint(equalTo: view.bottomAnchor),
        ])

        textView.drawsBackground = false
        textView.backgroundColor = .clear
        textView.isEditable = false
        textView.isSelectable = false
        textView.isRichText = true
        textView.font = NSFont.systemFont(ofSize: CGFloat(state.fontSize), weight: .regular)
        textView.textColor = NSColor(white: 0.92, alpha: 1)
        textView.textContainerInset = NSSize(width: 24, height: 44)
        textView.isVerticallyResizable = true
        textView.isHorizontallyResizable = false
        textView.textContainer?.widthTracksTextView = true
        textView.autoresizingMask = [.width]
        textView.insertionPointColor = .white

        scrollView.documentView = textView
        renderMarkdownView()
    }

    // ── Actions ────────────────────────────────────────────────

    @objc func toggleEdit() {
        isEditing.toggle()
        if isEditing {
            textView.isRichText = false
            textView.string = state.notes
            textView.font = NSFont.monospacedSystemFont(ofSize: CGFloat(state.fontSize) * 0.9, weight: .regular)
            textView.textColor = NSColor(white: 0.85, alpha: 1)
            textView.isEditable = true
            textView.isSelectable = true
            editButton.title = "Save"
            view.window?.makeFirstResponder(textView)
        } else {
            state.notes = textView.string
            textView.isEditable = false
            textView.isSelectable = false
            textView.isRichText = true
            editButton.title = "Edit"
            renderMarkdownView()
            persistState()
        }
    }

    @objc func pasteMarkdown() {
        guard let clipboard = NSPasteboard.general.string(forType: .string) else { return }
        if isEditing {
            textView.pasteAsPlainText(nil)
        } else {
            state.notes = clipboard
            renderMarkdownView()
            persistState()
        }
    }

    func renderMarkdownView() {
        let renderer = MarkdownRenderer(baseFontSize: CGFloat(state.fontSize))
        let attributed = renderer.render(state.notes)
        textView.textStorage?.setAttributedString(attributed)
    }

    @objc func toggleScroll() {
        isScrolling.toggle()
        if isScrolling {
            scrollButton.title = "Pause"
            scrollSpeed = 1.0
            scrollTimer = Timer.scheduledTimer(withTimeInterval: 0.04, repeats: true) { [weak self] _ in
                self?.doScroll()
            }
        } else {
            scrollButton.title = "Scroll"
            scrollTimer?.invalidate()
            scrollTimer = nil
        }
    }

    func doScroll() {
        let clip = scrollView.contentView
        var pt = clip.bounds.origin
        pt.y += scrollSpeed
        let maxY = (scrollView.documentView?.frame.height ?? 0) - clip.bounds.height
        if pt.y >= maxY {
            pt.y = maxY
            isScrolling = false
            scrollButton.title = "Scroll"
            scrollTimer?.invalidate()
            scrollTimer = nil
            return
        }
        clip.scroll(to: pt)
        scrollView.reflectScrolledClipView(clip)
    }

    @objc func fontLarger() {
        state.fontSize = min(60, state.fontSize + 2)
        refreshFont()
        persistState()
    }

    @objc func fontSmaller() {
        state.fontSize = max(10, state.fontSize - 2)
        refreshFont()
        persistState()
    }

    func refreshFont() {
        if isEditing {
            textView.font = NSFont.monospacedSystemFont(ofSize: CGFloat(state.fontSize) * 0.9, weight: .regular)
        } else {
            renderMarkdownView()
        }
    }

    @objc func opacityUp() {
        state.opacity = min(1.0, state.opacity + 0.08)
        view.window?.alphaValue = CGFloat(state.opacity)
        updateOpacityLabel()
        persistState()
    }

    @objc func togglePassthrough() {
        isPassthrough.toggle()
        guard let window = view.window else { return }
        if isPassthrough {
            window.ignoresMouseEvents = true
            window.level = .screenSaver
            window.hasShadow = false
            passthroughButton.title = "Pass-through: ON"
            passthroughButton.contentTintColor = NSColor(calibratedRed: 0.3, green: 0.9, blue: 0.5, alpha: 1)
        } else {
            window.ignoresMouseEvents = false
            window.level = .floating
            window.hasShadow = true
            passthroughButton.title = "Pass-through: OFF"
            passthroughButton.contentTintColor = NSColor(white: 0.65, alpha: 1)
        }
        NotificationCenter.default.post(name: .init("PassthroughStateChanged"), object: nil)
    }

    @objc func opacityDown() {
        state.opacity = max(0.12, state.opacity - 0.08)
        view.window?.alphaValue = CGFloat(state.opacity)
        updateOpacityLabel()
        persistState()
    }

    func persistState() {
        if let w = view.window {
            state.x = Double(w.frame.origin.x)
            state.y = Double(w.frame.origin.y)
            state.width = Double(w.frame.width)
            state.height = Double(w.frame.height)
        }
        saveState(state)
    }

    func updateOpacityLabel() {
        let pct = Int(state.opacity * 100)
        opacityLabel.stringValue = " \(pct)%"
    }

    // ── Helpers ────────────────────────────────────────────────

    func makeCtrlButton(_ title: String) -> NSButton {
        let btn = NSButton(title: title, target: nil, action: nil)
        configureCtrlButton(btn, title: title)
        return btn
    }

    func configureCtrlButton(_ btn: NSButton, title: String) {
        btn.title = title
        btn.isBordered = false
        btn.font = NSFont.systemFont(ofSize: 11, weight: .medium)
        (btn.cell as? NSButtonCell)?.highlightsBy = .changeBackgroundCellMask
        btn.contentTintColor = NSColor(white: 0.65, alpha: 1)
    }
}

// MARK: - App Delegate

class AppDelegate: NSObject, NSApplicationDelegate {
    var window: TransparentWindow!
    var controlsPanel: ControlsPanel!
    var vc: TeleprompterVC?
    var statusItem: NSStatusItem!
    var passthroughMenuItem: NSMenuItem!
    var showMenuItem: NSMenuItem!

    let controlsHeight: CGFloat = 32

    func applicationDidFinishLaunching(_ notification: Notification) {
        setupMainMenu()
        setupStatusBar()

        let state = loadState()

        let frame = NSRect(x: state.x, y: state.y, width: state.width, height: state.height)
        window = TransparentWindow(
            contentRect: frame,
            styleMask: [.borderless, .resizable, .miniaturizable],
            backing: .buffered,
            defer: false
        )

        window.isOpaque = false
        window.backgroundColor = NSColor(white: 0.012, alpha: 0.72)
        window.hasShadow = true
        window.level = .floating
        window.alphaValue = CGFloat(state.opacity)
        window.isMovableByWindowBackground = true
        window.minSize = NSSize(width: 280, height: 150)

        let vc = TeleprompterVC()
        self.vc = vc
        window.contentViewController = vc
        window.delegate = self

        setupControlsPanel()

        window.makeKeyAndOrderFront(nil)
        controlsPanel.orderFront(nil)
        NSApp.activate(ignoringOtherApps: true)

        NotificationCenter.default.addObserver(
            self, selector: #selector(passthroughStateChanged),
            name: .init("PassthroughStateChanged"), object: nil
        )
    }

    func setupControlsPanel() {
        let mainFrame = window.frame
        let panelFrame = NSRect(
            x: mainFrame.origin.x,
            y: mainFrame.origin.y + mainFrame.height - controlsHeight,
            width: mainFrame.width,
            height: controlsHeight
        )

        controlsPanel = ControlsPanel(
            contentRect: panelFrame,
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        controlsPanel.isOpaque = false
        controlsPanel.backgroundColor = NSColor(white: 0.02, alpha: 0.94)
        controlsPanel.hasShadow = false
        controlsPanel.level = .floating + 1
        controlsPanel.isFloatingPanel = true
        controlsPanel.hidesOnDeactivate = false
        controlsPanel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let container = controlsPanel.contentView!
        container.wantsLayer = true
        vc?.buildControlsInto(container)

        window.addChildWindow(controlsPanel, ordered: .above)
    }

    // ── Status bar icon ────────────────────────────────────────

    func setupStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        if let button = statusItem.button {
            button.title = "T"
            button.font = NSFont.boldSystemFont(ofSize: 14)
        }

        let menu = NSMenu()

        passthroughMenuItem = NSMenuItem(title: "Pass-through: OFF", action: #selector(statusTogglePassthrough), keyEquivalent: "l")
        passthroughMenuItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(passthroughMenuItem)

        showMenuItem = NSMenuItem(title: "Hide window", action: #selector(statusToggleVisibility), keyEquivalent: "t")
        showMenuItem.keyEquivalentModifierMask = [.command, .shift]
        menu.addItem(showMenuItem)

        menu.addItem(NSMenuItem.separator())
        menu.addItem(withTitle: "Quit", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")

        statusItem.menu = menu
    }

    @objc func statusTogglePassthrough() {
        vc?.togglePassthrough()
    }

    @objc func statusToggleVisibility() {
        if window.isVisible {
            window.orderOut(nil)
            controlsPanel.orderOut(nil)
            showMenuItem.title = "Show window"
        } else {
            window.makeKeyAndOrderFront(nil)
            controlsPanel.orderFront(nil)
            showMenuItem.title = "Hide window"
        }
    }

    @objc func passthroughStateChanged() {
        if vc?.isPassthrough == true {
            passthroughMenuItem.title = "Pass-through: ON  ✓"
            statusItem.button?.title = "T"
            controlsPanel.level = .screenSaver + 1
        } else {
            passthroughMenuItem.title = "Pass-through: OFF"
            statusItem.button?.title = "T"
            controlsPanel.level = .floating + 1
        }
    }

    // ── Menus ──────────────────────────────────────────────────

    func setupMainMenu() {
        let mainMenu = NSMenu()

        let appMenuItem = NSMenuItem()
        mainMenu.addItem(appMenuItem)
        let appMenu = NSMenu()
        appMenu.addItem(withTitle: "Quit Teleprompter", action: #selector(NSApplication.terminate(_:)), keyEquivalent: "q")
        appMenuItem.submenu = appMenu

        let editMenuItem = NSMenuItem()
        mainMenu.addItem(editMenuItem)
        let editMenu = NSMenu(title: "Edit")
        editMenu.addItem(withTitle: "Undo", action: Selector(("undo:")), keyEquivalent: "z")
        editMenu.addItem(withTitle: "Redo", action: Selector(("redo:")), keyEquivalent: "Z")
        editMenu.addItem(NSMenuItem.separator())
        editMenu.addItem(withTitle: "Cut", action: #selector(NSText.cut(_:)), keyEquivalent: "x")
        editMenu.addItem(withTitle: "Copy", action: #selector(NSText.copy(_:)), keyEquivalent: "c")
        editMenu.addItem(withTitle: "Paste", action: #selector(TeleprompterVC.pasteMarkdown), keyEquivalent: "v")
        editMenu.addItem(withTitle: "Select All", action: #selector(NSText.selectAll(_:)), keyEquivalent: "a")
        editMenuItem.submenu = editMenu

        NSApp.mainMenu = mainMenu
    }

    func applicationShouldTerminateAfterLastWindowClosed(_ sender: NSApplication) -> Bool { false }

    func applicationWillTerminate(_ notification: Notification) {
        vc?.state.notes = vc?.textView.string ?? ""
        vc?.persistState()
    }
}

extension AppDelegate: NSWindowDelegate {
    func repositionControlsPanel() {
        let mainFrame = window.frame
        controlsPanel.setFrame(NSRect(
            x: mainFrame.origin.x,
            y: mainFrame.origin.y + mainFrame.height - controlsHeight,
            width: mainFrame.width,
            height: controlsHeight
        ), display: true)
    }

    func windowDidMove(_ notification: Notification) {
        repositionControlsPanel()
        vc?.persistState()
    }

    func windowDidResize(_ notification: Notification) {
        repositionControlsPanel()
        vc?.persistState()
    }
}

// MARK: - Entry point

let app = NSApplication.shared
let delegate = AppDelegate()
app.delegate = delegate
app.setActivationPolicy(.accessory)
app.run()
