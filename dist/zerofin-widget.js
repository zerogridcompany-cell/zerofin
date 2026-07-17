// ZeroFin — iPhone ホーム画面ウィジェット (Scriptable)
// 初回だけ Supabase の URL と読み取りキーを聞いて Keychain に保存する。
// 使い方: Scriptable に新規スクリプトとして貼付 → ホーム画面に Scriptable ウィジェット追加 → このスクリプトを選択。

const K_URL = "zerofin_supabase_url";
const K_KEY = "zerofin_supabase_key";

async function ensureCreds() {
  if (!Keychain.contains(K_URL) || !Keychain.contains(K_KEY)) {
    const a = new Alert();
    a.title = "ZeroFin 初期設定";
    a.message = "Supabase の URL と読み取りキーを入力";
    a.addTextField("https://xxxx.supabase.co", "");
    a.addSecureTextField("service_role または anon key", "");
    a.addAction("保存");
    a.addCancelAction("キャンセル");
    const idx = await a.present();
    if (idx === -1) throw new Error("設定がキャンセルされました");
    Keychain.set(K_URL, a.textFieldValue(0).trim());
    Keychain.set(K_KEY, a.textFieldValue(1).trim());
  }
  return { url: Keychain.get(K_URL).replace(/\/$/, ""), key: Keychain.get(K_KEY) };
}

async function fetchMetrics({ url, key }) {
  const req = new Request(`${url}/rest/v1/zf_daily_metrics?select=date,key,value&order=date.desc&limit=40`);
  req.headers = { apikey: key, Authorization: `Bearer ${key}` };
  const rows = await req.loadJSON();
  const latest = rows.length ? rows[0].date : null;
  const m = {};
  for (const r of rows) if (r.date === latest) m[r.key] = Number(r.value);
  m._date = latest;
  return m;
}

function yen(v) {
  if (v == null) return "—";
  const a = Math.abs(v), s = v < 0 ? "-" : "";
  if (a >= 1e8) return `${s}¥${(a / 1e8).toFixed(1)}億`;
  if (a >= 1e4) return `${s}¥${Math.round(a / 1e4).toLocaleString()}万`;
  return `${s}¥${a.toLocaleString()}`;
}

function buildWidget(m) {
  const w = new ListWidget();
  const bg = new LinearGradient();
  bg.colors = [new Color("#0b0d14"), new Color("#12151f")];
  bg.locations = [0, 1];
  w.backgroundGradient = bg;
  w.setPadding(16, 18, 16, 18);

  const head = w.addStack();
  const label = head.addText("FINANCE");
  label.font = Font.mediumSystemFont(9);
  label.textColor = new Color("#8a90a0");
  head.addSpacer();
  const date = head.addText(m._date || "");
  date.font = Font.systemFont(9);
  date.textColor = new Color("#5a6070");

  w.addSpacer(8);
  const t = w.addText("実質残高");
  t.font = Font.systemFont(11);
  t.textColor = new Color("#9aa0b0");
  const bal = w.addText(yen(m.effective_balance));
  bal.font = Font.boldSystemFont(28);
  bal.textColor = Color.white();
  bal.minimumScaleFactor = 0.5;

  w.addSpacer(10);
  const row = w.addStack();
  row.spacing = 10;
  metricCell(row, "売上", yen(m.shopify_sales), "#34c759");
  metricCell(row, "広告", yen(m.ad_spend), "#0a84ff");
  metricCell(row, "入金", yen(m.mf_income), "#30d0c0");
  w.addSpacer();
  return w;
}

function metricCell(row, label, value, color) {
  const s = row.addStack();
  s.layoutVertically();
  s.spacing = 2;
  const v = s.addText(value);
  v.font = Font.semiboldSystemFont(13);
  v.textColor = new Color(color);
  v.minimumScaleFactor = 0.6;
  const l = s.addText(label);
  l.font = Font.systemFont(9);
  l.textColor = new Color("#7a8090");
}

try {
  const creds = await ensureCreds();
  const m = await fetchMetrics(creds);
  const widget = buildWidget(m);
  if (config.runsInWidget) Script.setWidget(widget);
  else await widget.presentMedium();
} catch (e) {
  const w = new ListWidget();
  w.addText("ZeroFin エラー\n" + e.message).textColor = Color.white();
  if (config.runsInWidget) Script.setWidget(w);
  else await w.presentMedium();
}
Script.complete();
