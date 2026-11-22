# AI 解籤 API

`POST /api/interpret`（Vercel Function）。原始碼在 `server/`，部署的是打包後的 `api/interpret.js`：改了 `server/` 之後要執行 `npm run build:api`（`npm test` 會檢查打包檔是否過期）。

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

- 400 `bad_request`、413 `too_large`、429 `rate_limited`、503 `unavailable`（後端沒有設定任何供應商金鑰）：JSON `{"error":{"code","message"}}`，`message` 可直接顯示給使用者。
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

環境變數見 `.env.example`。供應商依 `INTERPRET_PROVIDERS` 的順序使用，預設 Gemini 為主、NVIDIA 為備援：前一家在**開始輸出前**失敗（忙線、錯誤、安全攔截）就改用下一家；已經開始輸出後才失敗，就回 `error` 事件，不換家。模型 ID 用 `GEMINI_MODEL`、`NVIDIA_MODEL` 設定，`npm run models` 可列出你的金鑰目前可用的模型（需要 `.env.local`）。

## 隱私

伺服器不記錄問題內容；錯誤記錄只留錯誤碼。問題會送到 Google（Gemini）或 NVIDIA 產生解說，隱私權政策需載明。

## 測試

```bash
npm test
```

```bash
npm run typecheck
```

尚未做：用真實 API 金鑰跑第 8 節的 5–10 組固定案例（會產生費用）。

## 部署到 Vercel

1. Vercel 後台 → Add New → Project → 匯入 GitHub 的這個 repo（Framework Preset 選 Other，其餘照 `vercel.json`）。
2. Settings → Environment Variables 填 `GEMINI_API_KEY`、`NVIDIA_API_KEY`（金鑰只放這裡）；模型可用 `GEMINI_MODEL`、`NVIDIA_MODEL` 覆寫。
3. 重新部署後測試（會用一次 LLM 額度）：

```bash
npm run smoke -- https://你的專案.vercel.app
```

4. App 端：把網址填進 `app/dart_defines.json` 的 `API_BASE`，用 `--dart-define-from-file=dart_defines.json` 建置。
