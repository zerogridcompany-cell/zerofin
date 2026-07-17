import Foundation

/// 収集器(zerofin TS プロジェクト)がこのマシンにあれば、パネルを開くたびに
/// 実収集を走らせて銀行残高含め最新化する。無ければ Supabase 読取のみ。
enum Refresher {
    /// 収集器プロジェクトのパス候補（Mac mini）
    private static let collectorDir =
        ("~/.openclaw/workspace/projects/zerofin" as NSString).expandingTildeInPath

    static var hasCollector: Bool {
        FileManager.default.fileExists(atPath: collectorDir + "/src/collect.ts")
    }

    /// 収集を1回実走。完了後に true を返す（失敗時 false）。重複起動はロックで防ぐ。
    @discardableResult
    static func runCollect() async -> Bool {
        guard hasCollector else { return false }
        let lock = collectorDir + "/.zerofin-refresh.lock"
        // 既に走っていれば待たずに抜ける（launchd の3h収集と衝突しないように）
        if FileManager.default.fileExists(atPath: lock),
           let attr = try? FileManager.default.attributesOfItem(atPath: lock),
           let date = attr[.modificationDate] as? Date,
           Date().timeIntervalSince(date) < 120 {
            return false
        }
        FileManager.default.createFile(atPath: lock, contents: nil)
        defer { try? FileManager.default.removeItem(atPath: lock) }

        return await withCheckedContinuation { cont in
            DispatchQueue.global().async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
                proc.arguments = ["-lc", "cd \(collectorDir) && ZEROFIN_HEADLESS=1 npm run collect"]
                proc.standardOutput = Pipe()
                proc.standardError = Pipe()
                do {
                    try proc.run()
                    proc.waitUntilExit()
                    cont.resume(returning: proc.terminationStatus == 0)
                } catch {
                    cont.resume(returning: false)
                }
            }
        }
    }
}
