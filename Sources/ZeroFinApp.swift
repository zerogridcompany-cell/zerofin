import SwiftUI
import AppKit
import Carbon.HIToolbox

@main
struct ZeroFinApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) var delegate
    var body: some Scene {
        Settings { EmptyView() }   // LSUIElement アプリなので通常ウィンドウは持たない
    }
}

final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem?
    private var hotKey: GlobalHotKey?

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        // オフスクリーン描画モード（見た目確認用）
        if ProcessInfo.processInfo.environment["ZEROFIN_SNAPSHOT"] == "1" {
            SnapshotRenderer.run()
            return
        }

        setupStatusItem()

        // ⌘F グローバルホットキー（デフォルト。競合時は後で変更可能に）
        hotKey = GlobalHotKey(keyCode: UInt32(kVK_ANSI_F), modifiers: UInt32(cmdKey)) {
            Task { @MainActor in NotchController.shared.toggle() }
        }

        // テスト用: 起動時に自動でパネルを開く
        if ProcessInfo.processInfo.environment["ZEROFIN_AUTOOPEN"] == "1" {
            Task { @MainActor in NotchController.shared.open() }
        }
    }

    private func setupStatusItem() {
        let item = NSStatusBar.system.statusItem(withLength: NSStatusItem.variableLength)
        item.button?.image = NSImage(systemSymbolName: "yensign.circle", accessibilityDescription: "ZeroFin")
        let menu = NSMenu()
        menu.addItem(withTitle: "ダッシュボードを開く (⌘F)", action: #selector(openPanel), keyEquivalent: "")
        menu.addItem(.separator())
        menu.addItem(withTitle: "更新", action: #selector(refresh), keyEquivalent: "")
        menu.addItem(withTitle: "終了", action: #selector(quit), keyEquivalent: "q")
        for i in menu.items { i.target = self }
        item.menu = menu
        statusItem = item
    }

    @objc private func openPanel() { Task { @MainActor in NotchController.shared.open() } }
    @objc private func refresh() { Task { @MainActor in await NotchController.shared.store.refresh() } }
    @objc private func quit() { NSApp.terminate(nil) }
}

/// Carbon による最小のグローバルホットキー。
/// 並行性安全のため、共有 static は持たず refcon 経由で自身を C コールバックへ渡す。
final class GlobalHotKey {
    private var ref: EventHotKeyRef?
    private var handler: EventHandlerRef?
    private let callback: () -> Void

    init?(keyCode: UInt32, modifiers: UInt32, callback: @escaping () -> Void) {
        self.callback = callback
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard),
                                      eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, _, userData -> OSStatus in
            guard let userData else { return noErr }
            let me = Unmanaged<GlobalHotKey>.fromOpaque(userData).takeUnretainedValue()
            me.callback()
            return noErr
        }, 1, &eventType, selfPtr, &handler)

        let hotID = EventHotKeyID(signature: OSType(0x5A46494E /* 'ZFIN' */), id: 1)
        let status = RegisterEventHotKey(keyCode, modifiers, hotID, GetApplicationEventTarget(), 0, &ref)
        if status != noErr { return nil }
    }

    deinit {
        if let ref { UnregisterEventHotKey(ref) }
        if let handler { RemoveEventHandler(handler) }
    }
}
