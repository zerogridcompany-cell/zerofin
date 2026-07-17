import Foundation

enum Yen {
    private static let f: NumberFormatter = {
        let n = NumberFormatter()
        n.numberStyle = .decimal
        n.groupingSeparator = ","
        return n
    }()

    /// ¥43,457,741
    static func full(_ v: Int) -> String {
        "¥" + (f.string(from: NSNumber(value: v)) ?? "\(v)")
    }

    /// 大きい数字を万/億で丸めた短縮表記（¥4,345万 など）
    static func short(_ v: Int) -> String {
        let a = abs(v)
        let sign = v < 0 ? "-" : ""
        if a >= 100_000_000 {
            return sign + "¥" + trim(Double(a) / 100_000_000) + "億"
        } else if a >= 10_000 {
            return sign + "¥" + trim(Double(a) / 10_000) + "万"
        }
        return full(v)
    }

    private static func trim(_ d: Double) -> String {
        let r = (d * 10).rounded() / 10
        return r.truncatingRemainder(dividingBy: 1) == 0 ? String(Int(r)) : String(r)
    }
}
