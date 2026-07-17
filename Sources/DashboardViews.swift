import SwiftUI

/// 一番上のデカい「実質残高」
struct HeroBalance: View {
    let value: Int
    let bank: Int

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("実質残高")
                .font(.system(size: 12, weight: .medium))
                .foregroundStyle(.secondary)
            Text(Yen.full(value))
                .font(.system(size: 40, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .contentTransition(.numericText())
                .minimumScaleFactor(0.6)
                .lineLimit(1)
            Text("銀行残高 \(Yen.short(bank))")
                .font(.system(size: 11))
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

/// 横一列の指標カード群
struct MetricRow: View {
    let snapshot: FinanceSnapshot

    var body: some View {
        HStack(spacing: 10) {
            MetricCell(label: "今日の売上", value: Yen.short(snapshot.shopifySales),
                       tint: .green, icon: "cart.fill")
            MetricCell(label: "今日の広告費", value: Yen.short(snapshot.adSpend),
                       tint: .blue, icon: "megaphone.fill")
            MetricCell(label: "今日の入金", value: Yen.short(snapshot.mfIncome),
                       tint: .teal, icon: "arrow.down.circle.fill")
            MetricCell(label: nextPayoutLabel, value: Yen.short(snapshot.nextPayoutAmount),
                       tint: .orange, icon: "clock.fill")
        }
    }

    private var nextPayoutLabel: String {
        if let d = snapshot.nextPayoutDate { return "次の入金 \(d.suffix(5))" }
        return "次の入金"
    }
}

struct MetricCell: View {
    let label: String
    let value: String
    let tint: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 12))
                .foregroundStyle(tint)
            Text(value)
                .font(.system(size: 15, weight: .semibold, design: .rounded))
                .foregroundStyle(.primary)
                .minimumScaleFactor(0.7)
                .lineLimit(1)
            Text(label)
                .font(.system(size: 9.5))
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 11)
        .padding(.horizontal, 11)
        .background(.white.opacity(0.06), in: RoundedRectangle(cornerRadius: 14))
        .overlay(RoundedRectangle(cornerRadius: 14).stroke(.white.opacity(0.06), lineWidth: 0.5))
    }
}

/// 残高推移のミニスパークライン
struct TrendCard: View {
    let points: [Int]

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text("残高推移")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                if let first = points.first, let last = points.last, first != 0 {
                    let delta = last - first
                    Text((delta >= 0 ? "+" : "") + Yen.short(delta))
                        .font(.system(size: 11, weight: .semibold, design: .rounded))
                        .foregroundStyle(delta >= 0 ? .green : .red)
                }
            }
            Sparkline(points: points)
                .frame(height: 46)
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
    }
}

/// 今日の支出内訳（広告費・PayPal・送金・カード・その他）
struct ExpenseBreakdown: View {
    let slices: [ExpenseSlice]

    private var total: Int { max(slices.reduce(0) { $0 + $1.amount }, 1) }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("今日の支出")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(.secondary)
                Spacer()
                Text(Yen.short(slices.reduce(0) { $0 + $1.amount }))
                    .font(.system(size: 11, weight: .semibold, design: .rounded))
                    .foregroundStyle(.primary)
            }
            if slices.isEmpty {
                Text("支出なし")
                    .font(.system(size: 11)).foregroundStyle(.tertiary)
            } else {
                // 積み上げバー
                GeometryReader { geo in
                    HStack(spacing: 2) {
                        ForEach(slices) { s in
                            Color(hex: s.colorHex)
                                .frame(width: max(4, geo.size.width * CGFloat(s.amount) / CGFloat(total)))
                        }
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 7)
                // 凡例
                VStack(spacing: 6) {
                    ForEach(slices) { s in
                        HStack(spacing: 8) {
                            Circle().fill(Color(hex: s.colorHex)).frame(width: 7, height: 7)
                            Text(s.label).font(.system(size: 11.5)).foregroundStyle(.secondary)
                            Spacer()
                            Text(Yen.short(s.amount))
                                .font(.system(size: 11.5, weight: .medium, design: .rounded))
                                .foregroundStyle(.primary)
                        }
                    }
                }
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity)
        .background(.white.opacity(0.05), in: RoundedRectangle(cornerRadius: 16))
    }
}

extension Color {
    init(hex: String) {
        let h = hex.hasPrefix("#") ? String(hex.dropFirst()) : hex
        var v: UInt64 = 0
        Scanner(string: h).scanHexInt64(&v)
        self.init(.sRGB,
                  red: Double((v >> 16) & 0xff) / 255,
                  green: Double((v >> 8) & 0xff) / 255,
                  blue: Double(v & 0xff) / 255)
    }
}

struct Sparkline: View {
    let points: [Int]

    var body: some View {
        GeometryReader { geo in
            let pts = points
            if pts.count >= 2 {
                let minV = pts.min() ?? 0
                let maxV = pts.max() ?? 1
                let range = max(maxV - minV, 1)
                let stepX = geo.size.width / CGFloat(pts.count - 1)
                let coords = pts.enumerated().map { i, v in
                    CGPoint(x: CGFloat(i) * stepX,
                            y: geo.size.height * (1 - CGFloat(v - minV) / CGFloat(range)))
                }
                ZStack {
                    Path { p in
                        p.move(to: CGPoint(x: coords[0].x, y: geo.size.height))
                        coords.forEach { p.addLine(to: $0) }
                        p.addLine(to: CGPoint(x: coords.last!.x, y: geo.size.height))
                        p.closeSubpath()
                    }
                    .fill(LinearGradient(colors: [.green.opacity(0.25), .clear],
                                         startPoint: .top, endPoint: .bottom))
                    Path { p in
                        p.move(to: coords[0])
                        coords.dropFirst().forEach { p.addLine(to: $0) }
                    }
                    .stroke(.green, style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
                }
            } else {
                Text("データ収集中…")
                    .font(.system(size: 11))
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
    }
}
