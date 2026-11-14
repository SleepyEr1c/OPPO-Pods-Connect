import AppKit
import SwiftUI

/// 管理刘海下方胶囊弹窗的 NSPanel：定位、动画进出、自动消失。
@MainActor
final class NotchPopupController {
    static let shared = NotchPopupController()

    private var panel: NSPanel?
    private var dismissTask: Task<Void, Never>?
    private var hostingView: NSHostingView<AnyView>?

    private let visibleDuration: TimeInterval = 4.0

    private init() {}

    func show(session: EarbudsSession) {
        dismissTask?.cancel()
        let panel = ensurePanel()
        updateContent(session: session, in: panel)

        panel.alphaValue = 0
        panel.orderFrontRegardless()
        NSAnimationContext.runAnimationGroup { context in
            context.duration = 0.32
            context.timingFunction = CAMediaTimingFunction(name: .easeOut)
            panel.animator().alphaValue = 1
        }

        dismissTask = Task { @MainActor [weak self] in
            try? await Task.sleep(nanoseconds: UInt64((self?.visibleDuration ?? 4) * 1_000_000_000))
            guard !Task.isCancelled else { return }
            self?.hide()
        }
    }

    /// 立即收起（不做淡出）：淡出动画期间若打开菜单面板会与之叠影。
    func hide() {
        dismissTask?.cancel()
        dismissTask = nil
        guard let panel else { return }
        panel.alphaValue = 0
        panel.orderOut(nil)
    }

    private func updateContent(session: EarbudsSession, in panel: NSPanel) {
        let content = AnyView(
            NotchPopupView(session: session)
                .environmentObject(session)
                .padding(28)
        )
        if let hostingView {
            hostingView.rootView = content
        } else {
            let view = NSHostingView(rootView: content)
            view.wantsLayer = true
            view.layer?.backgroundColor = NSColor.clear.cgColor
            view.frame = NSRect(origin: .zero, size: panel.frame.size)
            view.autoresizingMask = [.width, .height]
            panel.contentView = view
            hostingView = view
        }
    }

    private func ensurePanel() -> NSPanel {
        if let panel { return panel }

        // 比胶囊内容大一圈：阴影在面板内部绘制，避免被面板边界裁出矩形框。
        let size = NSSize(width: 436, height: 130)
        let panel = NSPanel(
            contentRect: NSRect(origin: .zero, size: size),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isOpaque = false
        panel.backgroundColor = .clear
        panel.hasShadow = false
        panel.level = NSWindow.Level(rawValue: Int(CGWindowLevelForKey(.statusWindow)) + 1)
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.hidesOnDeactivate = false
        panel.isMovable = false
        panel.ignoresMouseEvents = true
        panel.isReleasedWhenClosed = false

        panel.setFrameOrigin(notchOrigin(for: size))
        self.panel = panel
        return panel
    }

    /// 胶囊顶边贴着刘海（或菜单栏）下沿，水平居中于内建屏幕。
    private func notchOrigin(for size: NSSize) -> NSPoint {
        let screen = NSScreen.screens.first { $0.safeAreaInsets.top > 0 } ?? NSScreen.main
        guard let screen else {
            return NSPoint(x: 0, y: 200)
        }
        let topY: CGFloat
        if screen.safeAreaInsets.top > 0 {
            topY = screen.frame.maxY - screen.safeAreaInsets.top
        } else {
            topY = screen.visibleFrame.maxY
        }
        return NSPoint(
            x: screen.frame.midX - size.width / 2,
            y: topY - size.height
        )
    }
}
