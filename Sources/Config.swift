import Foundation

/// ~/.zerofin/env から Supabase 接続情報を読む（コレクタと同じ資格情報を共有）
enum Config {
    static let envPath = ("~/.zerofin/env" as NSString).expandingTildeInPath

    /// 毎回読み直す（インストール後に env が書かれても再起動不要にするため）
    private static func values() -> [String: String] {
        guard let text = try? String(contentsOfFile: envPath, encoding: .utf8) else { return [:] }
        var out: [String: String] = [:]
        for line in text.split(separator: "\n") {
            let s = line.trimmingCharacters(in: .whitespaces)
            if s.isEmpty || s.hasPrefix("#") { continue }
            guard let eq = s.firstIndex(of: "=") else { continue }
            let key = String(s[..<eq]).trimmingCharacters(in: .whitespaces)
            let val = String(s[s.index(after: eq)...]).trimmingCharacters(in: .whitespaces)
            out[key] = val
        }
        return out
    }

    static func value(_ key: String) -> String? { values()[key] }

    static var supabaseURL: String { value("SUPABASE_URL") ?? "" }
    static var supabaseKey: String { value("SUPABASE_SERVICE_KEY") ?? "" }
    static var isConfigured: Bool { !supabaseURL.isEmpty && !supabaseKey.isEmpty }
}
