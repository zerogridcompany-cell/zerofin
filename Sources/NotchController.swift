import AppKit
import SwiftUI
import Observation

/// パネルの展開状態。SwiftUI 側がこれを監視してノッチから生える演出をする。
@MainActor
@Observable
final class PanelState {
    var revealed = false
}

/// ノッチから降りてくるパネルを管理するコントローラ。
/// 画面上端中央に貼り付き、開くとカードがノッチから展開する。
@MainActor
final class NotchController: NSObject {
    static let shared = NotchController()

    let store = DataStore()
    let panelState = PanelState()
    private var window: NSPanel?
    private(set) var isOpen = false

    // 上部にノッチ用の余白を確保（この分だけカードが下に降りる）
    let topInset: CGFloat = 8
    private let panelWidth: CGFloat = 460
    private let panelHeight: CGFloat = 720

    func toggle() { isOpen ? close() : open() }

    func open() {
        guard !isOpen else { return }
        isOpen = true
        let win = window ?? makeWindow()
        window = win
        positionWindow(win)
        win.alphaValue = 1
        panelState.revealed = false
        win.makeKeyAndOrderFront(nil)
        NSApp.activate(ignoringOtherApps: true)
        // 1) キャッシュを即表示 → 2) 収集を実走して銀行残高含め最新化 → 3) 再読込
        Task {
            await store.refresh()
            if Refresher.hasCollector {
                store.refreshing = true
                let ok = await Refresher.runCollect()
                if ok { await store.refresh() }
                store.refreshing = false
            }
        }
        // 次のフレームで reveal をトグル → SwiftUI 側のスプリングで生える
        DispatchQueue.main.async { [weak self] in
            withAnimation(.spring(response: 0.42, dampingFraction: 0.74)) {
                self?.panelState.revealed = true
            }
        }
    }

    func close() {
        guard isOpen, let win = window else { return }
        isOpen = false
        withAnimation(.spring(response: 0.32, dampingFraction: 0.9)) {
            panelState.revealed = false
        }
        // 縮むアニメの後にウィンドウを隠す
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.34) {
            if !self.isOpen { win.orderOut(nil) }
        }
    }

    private func makeWindow() -> NSPanel {
        let panel = NSPanel(
            contentRect: NSRect(x: 0, y: 0, width: panelWidth, height: panelHeight),
            styleMask: [.borderless, .nonactivatingPanel],
            backing: .buffered,
            defer: false
        )
        panel.isFloatingPanel = true
        panel.level = .statusBar
        panel.backgroundColor = .clear
        panel.isOpaque = false
        panel.hasShadow = true
        panel.collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary, .stationary]
        panel.isMovable = false
        panel.hidesOnDeactivate = false

        let root = NotchPanelView()
            .environment(store)
            .environment(panelState)
        let hosting = NSHostingView(rootView: root)
        hosting.frame = panel.contentView!.bounds
        hosting.autoresizingMask = [.width, .height]
        hosting.layer?.masksToBounds = false
        panel.contentView = hosting
        return panel
    }

    /// メニューバー直下・画面中央に配置（ノッチから生えるように見せる）
    private func positionWindow(_ win: NSWindow) {
        guard let screen = NSScreen.main else { return }
        let vf = screen.frame
        let x = vf.midX - panelWidth / 2
        // 画面最上端に上辺を合わせる（ノッチ位置）
        let y = vf.maxY - panelHeight
        win.setFrame(NSRect(x: x, y: y, width: panelWidth, height: panelHeight), display: true)
    }
}
