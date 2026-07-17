import Foundation
import Observation

/// ダッシュボードに出す当日のスナップショット
struct FinanceSnapshot {
    var date: String = "—"
    var effectiveBalance: Int = 0
    var bankTotal: Int = 0
    var shopifySales: Int = 0
    var salesByStore: [String: Int] = [:]
    var adSpend: Int = 0
    var adMeta: Int = 0
    var mfIncome: Int = 0          // 今日の入金
    var paypalOut: Int = 0
    var cardExpenseMtd: Int = 0
    var nextPayoutAmount: Int = 0
    var nextPayoutDate: String? = nil
    var balanceTrend: [Int] = []   // 直近の総残高推移（スパークライン用）
    var expenses: [ExpenseSlice] = []   // 今日の支出内訳
    var updatedAt: Date? = nil
}

struct ExpenseSlice: Identifiable {
    let id = UUID()
    let label: String
    let amount: Int
    let colorHex: String
}

@MainActor
@Observable
final class DataStore {
    var snapshot = FinanceSnapshot()
    var loading = false
    var refreshing = false   // 収集を実走中（銀行残高スクレイプ等）
    var lastError: String?

    private var base: String { Config.supabaseURL.hasSuffix("/") ? String(Config.supabaseURL.dropLast()) : Config.supabaseURL }

    private func request(_ path: String) -> URLRequest? {
        guard !base.isEmpty, let url = URL(string: "\(base)/rest/v1/\(path)") else { return nil }
        var req = URLRequest(url: url)
        req.setValue(Config.supabaseKey, forHTTPHeaderField: "apikey")
        req.setValue("Bearer \(Config.supabaseKey)", forHTTPHeaderField: "Authorization")
        req.timeoutInterval = 15
        return req
    }

    private func fetchJSON(_ path: String) async throws -> [[String: Any]] {
        guard let req = request(path) else { throw NSError(domain: "zerofin", code: 1, userInfo: [NSLocalizedDescriptionKey: "Supabase 未設定 (~/.zerofin/env)"]) }
        let (data, _) = try await URLSession.shared.data(for: req)
        let obj = try JSONSerialization.jsonObject(with: data)
        return (obj as? [[String: Any]]) ?? []
    }

    /// 当日のメトリクスと残高推移をまとめて取得
    func refresh() async {
        loading = true
        lastError = nil
        defer { loading = false }
        do {
            // 最新日付のメトリクス群
            let rows = try await fetchJSON("zf_daily_metrics?select=date,key,value,meta&order=date.desc&limit=40")
            var snap = FinanceSnapshot()
            if let latestDate = rows.first?["date"] as? String {
                snap.date = latestDate
                for r in rows where (r["date"] as? String) == latestDate {
                    let key = r["key"] as? String ?? ""
                    let value = intValue(r["value"])
                    let meta = r["meta"] as? [String: Any]
                    switch key {
                    case "effective_balance": snap.effectiveBalance = value
                    case "bank_total": snap.bankTotal = value
                    case "shopify_sales":
                        snap.shopifySales = value
                        if let byStore = meta?["by_store"] as? [String: Any] {
                            snap.salesByStore = byStore.mapValues { intValue($0) }
                        }
                    case "ad_spend":
                        snap.adSpend = value
                        if let m = meta?["meta"] { snap.adMeta = intValue(m) }
                    case "ad_meta": if snap.adMeta == 0 { snap.adMeta = value }
                    case "mf_income": snap.mfIncome = value
                    case "paypal_out": snap.paypalOut = value
                    case "card_expense_mtd": snap.cardExpenseMtd = value
                    case "next_payout_amount":
                        snap.nextPayoutAmount = value
                        snap.nextPayoutDate = meta?["payout_date"] as? String
                    case "expense_breakdown":
                        snap.expenses = parseExpenses(meta)
                    default: break
                    }
                }
            }
            snap.balanceTrend = try await fetchBalanceTrend()
            snap.updatedAt = Date()
            self.snapshot = snap
        } catch {
            self.lastError = error.localizedDescription
        }
    }

    /// スナップショットを ts ごとに合計して総残高の時系列を作る
    private func fetchBalanceTrend() async throws -> [Int] {
        let rows = try await fetchJSON("zf_snapshots?select=ts,balance&order=ts.desc&limit=200")
        var byTs: [String: Int] = [:]
        var order: [String] = []
        for r in rows {
            guard let ts = r["ts"] as? String else { continue }
            if byTs[ts] == nil { order.append(ts) }
            byTs[ts, default: 0] += intValue(r["balance"])
        }
        // 古い順に最大30点
        let totals = order.reversed().map { byTs[$0] ?? 0 }
        return Array(totals.suffix(30))
    }

    private func parseExpenses(_ meta: [String: Any]?) -> [ExpenseSlice] {
        guard let meta else { return [] }
        let defs: [(String, String, String)] = [
            ("ad", "広告費", "#0a84ff"),
            ("paypal", "PayPal", "#c644fc"),
            ("transfer", "送金・仕入", "#ff9f0a"),
            ("card", "カード利用", "#ff375f"),
            ("other", "その他", "#8a90a0"),
        ]
        return defs
            .map { ExpenseSlice(label: $0.1, amount: intValue(meta[$0.0]), colorHex: $0.2) }
            .filter { $0.amount > 0 }
            .sorted { $0.amount > $1.amount }
    }

    private func intValue(_ any: Any?) -> Int {
        if let i = any as? Int { return i }
        if let d = any as? Double { return Int(d) }
        if let s = any as? String { return Int(s) ?? Int(Double(s) ?? 0) }
        if let n = any as? NSNumber { return n.intValue }
        return 0
    }
}
