import SwiftUI

/// ノッチパネルの中身。ノッチから生えるように上端中央を起点に展開する。
struct NotchPanelView: View {
    @Environment(DataStore.self) private var store
    @Environment(PanelState.self) private var panel

    private let notchWidth: CGFloat = 200
    private let cardWidth: CGFloat = 460

    var body: some View {
        let revealed = panel.revealed
        VStack(spacing: 0) {
            card
                .frame(width: cardWidth)
                // 幅: ノッチ幅 → フルへ。高さ: 上端起点でスケール。角丸は畳むと小さく
                .scaleEffect(x: revealed ? 1 : notchWidth / cardWidth,
                             y: revealed ? 1 : 0.02,
                             anchor: .top)
                .opacity(revealed ? 1 : 0)
            Spacer(minLength: 0)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .top)
    }

    private var card: some View {
        VStack(spacing: 0) {
            content
                .padding(.horizontal, 22)
                .padding(.top, 16)
                .padding(.bottom, 20)
        }
        .frame(maxWidth: .infinity, alignment: .top)
        .glassEffect(.regular, in: BottomRoundedShape(radius: 26))
        .overlay(
            BottomRoundedShape(radius: 26)
                .stroke(.white.opacity(0.12), lineWidth: 0.5)
        )
    }

    @ViewBuilder private var content: some View {
        VStack(alignment: .leading, spacing: 18) {
            header
            HeroBalance(value: store.snapshot.effectiveBalance,
                        bank: store.snapshot.bankTotal)
            MetricRow(snapshot: store.snapshot)
            TrendCard(points: store.snapshot.balanceTrend)
            Spacer(minLength: 0)
        }
    }

    private var header: some View {
        HStack {
            Text("FINANCE")
                .font(.system(size: 11, weight: .semibold))
                .tracking(3)
                .foregroundStyle(.secondary)
            Spacer()
            if store.refreshing {
                HStack(spacing: 5) {
                    ProgressView().controlSize(.small)
                    Text("最新取得中")
                        .font(.system(size: 10))
                        .foregroundStyle(.secondary)
                }
            } else if store.loading {
                ProgressView().controlSize(.small)
            } else if let err = store.lastError {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(.orange)
                    .help(err)
            } else {
                Text(store.snapshot.date)
                    .font(.system(size: 11, design: .monospaced))
                    .foregroundStyle(.tertiary)
            }
        }
    }
}

/// 下側だけ角丸の矩形
struct BottomRoundedShape: Shape {
    var radius: CGFloat
    func path(in rect: CGRect) -> Path {
        var p = Path()
        p.move(to: CGPoint(x: rect.minX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.minY))
        p.addLine(to: CGPoint(x: rect.maxX, y: rect.maxY - radius))
        p.addArc(center: CGPoint(x: rect.maxX - radius, y: rect.maxY - radius),
                 radius: radius, startAngle: .degrees(0), endAngle: .degrees(90), clockwise: false)
        p.addLine(to: CGPoint(x: rect.minX + radius, y: rect.maxY))
        p.addArc(center: CGPoint(x: rect.minX + radius, y: rect.maxY - radius),
                 radius: radius, startAngle: .degrees(90), endAngle: .degrees(180), clockwise: false)
        p.closeSubpath()
        return p
    }
}
