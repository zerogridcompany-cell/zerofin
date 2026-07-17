import Foundation

/// 音声/テキストコマンドの解釈結果
enum Intent {
    case showEverything
    case metric(key: String, label: String, value: (FinanceSnapshot) -> Int)
    case freeform(String)          // AI に投げる自由質問

    /// 決まり文句はローカル即判定。外れたら freeform
    static func parse(_ raw: String) -> Intent {
        let t = raw.lowercased()
        func has(_ ws: [String]) -> Bool { ws.contains { t.contains($0.lowercased()) } }

        if has(["show everything", "すべて", "全部", "ぜんぶ", "全体", "エブリシング"]) {
            return .showEverything
        }
        if has(["売上", "うりあげ", "sales", "セールス"]) {
            return .metric(key: "sales", label: "今日の売上") { $0.shopifySales }
        }
        if has(["広告", "こうこく", "ad", "アド", "メタ", "meta"]) {
            return .metric(key: "ad", label: "今日の広告費") { $0.adSpend }
        }
        if has(["残高", "ざんだか", "balance", "バランス"]) {
            return .metric(key: "balance", label: "実質残高") { $0.effectiveBalance }
        }
        if has(["入金", "にゅうきん", "payout", "入ってくる"]) {
            return .metric(key: "payout", label: "次の入金") { $0.nextPayoutAmount }
        }
        if has(["paypal", "ペイパル", "抜けて"]) {
            return .metric(key: "paypal", label: "PayPal引落") { $0.paypalOut }
        }
        return .freeform(raw)
    }
}

/// 自由質問を Claude Code CLI (サブスク認証) に投げて回答を得る
enum AIResponder {
    static func ask(_ question: String, context: FinanceSnapshot) async -> String {
        let ctx = """
        あなたはZeroGrid社の財務アシスタント。以下は最新の財務データ(単位:円)。
        日付: \(context.date)
        実質残高: \(context.effectiveBalance)
        銀行残高合計: \(context.bankTotal)
        今日の売上(3店合計): \(context.shopifySales) 内訳: \(context.salesByStore)
        今日の広告費(Meta中心): \(context.adSpend)
        今日の入金: \(context.mfIncome)
        今月のカード利用: \(context.cardExpenseMtd)
        PayPal引落(当日): \(context.paypalOut)
        次の入金予定: \(context.nextPayoutAmount) (\(context.nextPayoutDate ?? "未定"))

        質問に日本語で簡潔に(2〜3文)答えて。金額は¥表記。憶測は避け、データにない事は「データ無し」と言う。
        質問: \(question)
        """
        return await runClaude(prompt: ctx)
    }

    private static func runClaude(prompt: String) async -> String {
        await withCheckedContinuation { cont in
            DispatchQueue.global().async {
                let proc = Process()
                proc.executableURL = URL(fileURLWithPath: "/bin/zsh")
                proc.arguments = ["-lc", "claude -p"]
                let stdin = Pipe(), stdout = Pipe()
                proc.standardInput = stdin
                proc.standardOutput = stdout
                proc.standardError = Pipe()
                do {
                    try proc.run()
                    stdin.fileHandleForWriting.write(prompt.data(using: .utf8) ?? Data())
                    stdin.fileHandleForWriting.closeFile()
                    let data = stdout.fileHandleForReading.readDataToEndOfFile()
                    proc.waitUntilExit()
                    let out = String(data: data, encoding: .utf8)?
                        .trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
                    cont.resume(returning: out.isEmpty ? "（応答なし）" : out)
                } catch {
                    cont.resume(returning: "AI起動に失敗: \(error.localizedDescription)")
                }
            }
        }
    }
}
