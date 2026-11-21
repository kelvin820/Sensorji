# AI 解籤 API

`POST /api/interpret`（Vercel Function，原始碼 `api/interpret.ts`）

## 請求

```json
{
  "deck": "sensoji",        // "sensoji"（1–100）或 "tw60"（1–60）
  "number": 28,
  "category": "trip",       // data/category_map.json 的 id
  "question": "下個月去京都順利嗎？",  // 可空白，最多 200 字
  "tone": "gentle"          // "gentle" 溫和 | "direct" 直白 | "brief" 簡短；其他值視為 gentle
}
```

籤文、吉凶／干支、判語都由伺服器查表，App 不傳、也不被信任。

## 回應

- 400 `bad_request`、413 `too_large`、429 `rate_limited`：JSON `{"error":{"code","message"}}`，`message` 可直接顯示給使用者。
- 200：`text/event-stream`，事件依序：

| 事件 | data | 說明 |
|---|---|---|
| `start` | `{"section"}` | 某段開始 |
| `delta` | `{"section","text"}` | 該段新增的文字，直接接在後面顯示 |
| `end` | `{"section"}` | 該段結束 |
| `done` | `{"truncated"}` | 全部完成；`truncated` 為 true 表示輸出被截斷（極少見） |
| `error` | `{"code","message"}` | 中途失敗（`refused`／`busy`／`upstream`／`internal`），`message` 可直接顯示 |

`section` 依序為 `meaning`（籤意白話）、`relation`（與你的問題對照）、`one_line`（給你的一句話）、`actions`（可以做的事，每行以 `- ` 開頭）。

**例外**：問題透露自傷或危機時，只會有一段 `care`（關懷與求助專線），App 要改顯示關懷畫面、不顯示籤意。

## 設定

環境變數見 `.env.example`。模型預設 `claude-opus-5-5`；安全分類器拒答時會由 API 自動改用合適的模型重跑（server-side fallback）。

## 隱私

伺服器不記錄問題內容；錯誤記錄只留錯誤碼。問題會送到 Anthropic 產生解說，隱私權政策需載明。

## 測試

```bash
npm test
```

```bash
npm run typecheck
```

尚未做：用真實 API 金鑰跑第 8 節的 5–10 組固定案例（會產生費用）。
