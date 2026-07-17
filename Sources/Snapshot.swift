import SwiftUI
import AppKit

/// 画面録画権限なしでパネル見た目を確認するためのオフスクリーンPNG出力。
/// ZEROFIN_SNAPSHOT=1 で起動すると実データ or モックでレンダリングして終了する。
@MainActor
enum SnapshotRenderer {
    static func run() {
        let store = DataStore()
        Task { @MainActor in
            // 見た目確認用なので常にモックで全パーツを描く
            applyMock(store)
            render(store)
            NSApp.terminate(nil)
        }
    }

    private static func applyMock(_ store: DataStore) {
        var s = FinanceSnapshot()
        s.date = "2026-07-15"
        s.effectiveBalance = 43_457_741
        s.bankTotal = 44_579_538
        s.shopifySales = 1_089_519
        s.adSpend = 588_462
        s.mfIncome = 4_837_385
        s.nextPayoutAmount = 4_837_385
        s.nextPayoutDate = "2026-07-17"
        s.paypalOut = 0
        s.cardExpenseMtd = 1_121_797
        s.balanceTrend = [43_900_000, 44_100_000, 43_700_000, 44_569_510, 44_200_000, 44_579_538, 44_300_000, 44_579_538]
        store.snapshot = s
    }

    private static func render(_ store: DataStore) {
        // デスクトップ風の暗い背景の上にパネルを載せてガラス感を再現
        let view = ZStack {
            LinearGradient(colors: [Color(red: 0.10, green: 0.11, blue: 0.16),
                                    Color(red: 0.04, green: 0.05, blue: 0.09)],
                           startPoint: .topLeading, endPoint: .bottomTrailing)
            NotchPanelView()
                .environment(store)
                .environment(VoiceInput())
                .frame(width: 460, height: 560)
                .padding(.horizontal, 30)
                .padding(.vertical, 24)
        }
        .frame(width: 520, height: 608)
        .preferredColorScheme(.dark)
        let renderer = ImageRenderer(content: view)
        renderer.scale = 2
        guard let img = renderer.nsImage,
              let tiff = img.tiffRepresentation,
              let rep = NSBitmapImageRep(data: tiff),
              let png = rep.representation(using: .png, properties: [:]) else { return }
        let path = ("~/.zerofin/resona-shots/mac-panel.png" as NSString).expandingTildeInPath
        try? png.write(to: URL(fileURLWithPath: path))
        FileHandle.standardError.write("SNAPSHOT: \(path)\n".data(using: .utf8)!)
    }
}
