// 解籤用的 LLM 供應商：Gemini 為主、NVIDIA（OpenAI 相容 API）為備援。
// 兩家都用 REST 串流，不依賴 SDK；每家只負責把模型輸出的文字逐段 yield 出來。
// 金鑰只從環境變數讀取（Vercel 專案設定），App 端不會出現。

export type ProviderName = "gemini" | "nvidia";

/** 供應商錯誤。code 決定 App 看到的訊息，以及要不要換下一家。 */
export class ProviderError extends Error {
  readonly code: "config" | "busy" | "upstream" | "refused";
  readonly detail: string;
  constructor(code: ProviderError["code"], detail: string) {
    super(`${code}: ${detail}`);
    this.code = code;
    this.detail = detail;
  }
}

export interface StreamResult {
  /** 輸出因長度上限被截斷。 */
  truncated: boolean;
}

export interface Provider {
  name: ProviderName;
  /** 逐段 yield 文字，結束時回傳結果。開始輸出前失敗才會換下一家。 */
  stream(system: string, user: string, signal: AbortSignal): AsyncGenerator<string, StreamResult>;
}

const MAX_OUTPUT_TOKENS = Number(process.env.INTERPRET_MAX_TOKENS ?? 4096);
const TEMPERATURE = 0.7;

/** 讀 SSE 回應，逐一 yield 每個 `data:` 的內容。 */
export async function* readSse(body: ReadableStream<Uint8Array>): AsyncGenerator<string> {
  const reader = body.getReader();
  const decoder = new TextDecoder();
  let buf = "";
  for (;;) {
    const { value, done } = await reader.read();
    if (done) break;
    buf += decoder.decode(value, { stream: true });
    let nl: number;
    while ((nl = buf.indexOf("\n")) !== -1) {
      const line = buf.slice(0, nl).replace(/\r$/, "");
      buf = buf.slice(nl + 1);
      if (line.startsWith("data:")) yield line.slice(5).trimStart();
    }
  }
  const last = buf.trim();
  if (last.startsWith("data:")) yield last.slice(5).trimStart();
}

function httpError(status: number, who: string): ProviderError {
  if (status === 429 || status === 503) return new ProviderError("busy", `${who} ${status}`);
  if (status === 401 || status === 403) return new ProviderError("config", `${who} ${status}`);
  return new ProviderError("upstream", `${who} ${status}`);
}

// ---------------------------------------------------------------- Gemini

export function gemini(): Provider | null {
  const key = process.env.GEMINI_API_KEY;
  if (!key) return null;
  const model = process.env.GEMINI_MODEL ?? "gemini-3.6-flash";
  return {
    name: "gemini",
    async *stream(system, user, signal) {
      const url =
        `https://generativelanguage.googleapis.com/v1beta/models/${encodeURIComponent(model)}` +
        `:streamGenerateContent?alt=sse`;
      const res = await fetch(url, {
        method: "POST",
        signal,
        headers: { "Content-Type": "application/json", "x-goog-api-key": key },
        body: JSON.stringify({
          systemInstruction: { parts: [{ text: system }] },
          contents: [{ role: "user", parts: [{ text: user }] }],
          generationConfig: { maxOutputTokens: MAX_OUTPUT_TOKENS, temperature: TEMPERATURE },
        }),
      });
      if (!res.ok || !res.body) throw httpError(res.status, "gemini");

      let finish = "";
      for await (const data of readSse(res.body)) {
        const chunk = JSON.parse(data) as GeminiChunk;
        if (chunk.promptFeedback?.blockReason) {
          throw new ProviderError("refused", `gemini prompt ${chunk.promptFeedback.blockReason}`);
        }
        const cand = chunk.candidates?.[0];
        for (const part of cand?.content?.parts ?? []) {
          if (part.text && !part.thought) yield part.text;
        }
        if (cand?.finishReason) finish = cand.finishReason;
      }
      if (["SAFETY", "PROHIBITED_CONTENT", "BLOCKLIST", "SPII", "RECITATION"].includes(finish)) {
        throw new ProviderError("refused", `gemini finish ${finish}`);
      }
      return { truncated: finish === "MAX_TOKENS" };
    },
  };
}

interface GeminiChunk {
  promptFeedback?: { blockReason?: string };
  candidates?: {
    content?: { parts?: { text?: string; thought?: boolean }[] };
    finishReason?: string;
  }[];
}

// ---------------------------------------------------------------- NVIDIA

export function nvidia(): Provider | null {
  const key = process.env.NVIDIA_API_KEY;
  if (!key) return null;
  const model = process.env.NVIDIA_MODEL ?? "deepseek-ai/deepseek-v4.1-flash";
  return {
    name: "nvidia",
    async *stream(system, user, signal) {
      const res = await fetch("https://integrate.api.nvidia.com/v1/chat/completions", {
        method: "POST",
        signal,
        headers: {
          "Content-Type": "application/json",
          Accept: "text/event-stream",
          Authorization: `Bearer ${key}`,
        },
        body: JSON.stringify({
          model,
          stream: true,
          max_tokens: MAX_OUTPUT_TOKENS,
          temperature: TEMPERATURE,
          messages: [
            { role: "system", content: system },
            { role: "user", content: user },
          ],
        }),
      });
      if (!res.ok || !res.body) throw httpError(res.status, "nvidia");

      const think = new ThinkStripper();
      let finish = "";
      for await (const data of readSse(res.body)) {
        if (data === "[DONE]") break;
        const chunk = JSON.parse(data) as OpenAiChunk;
        const choice = chunk.choices?.[0];
        // 推理模型的思考內容放在 reasoning_content，不轉給使用者。
        const text = choice?.delta?.content;
        if (text) {
          const visible = think.push(text);
          if (visible) yield visible;
        }
        if (choice?.finish_reason) finish = choice.finish_reason;
      }
      if (finish === "content_filter") throw new ProviderError("refused", "nvidia content_filter");
      return { truncated: finish === "length" };
    },
  };
}

interface OpenAiChunk {
  choices?: { delta?: { content?: string | null }; finish_reason?: string | null }[];
}

/** 有些模型把思考寫在內文的 <think>…</think> 裡，串流時把它濾掉。 */
export class ThinkStripper {
  private inThink = false;
  private buf = "";

  push(chunk: string): string {
    this.buf += chunk;
    let out = "";
    for (;;) {
      const tag = this.inThink ? "</think>" : "<think>";
      const i = this.buf.indexOf(tag);
      if (i !== -1) {
        if (!this.inThink) out += this.buf.slice(0, i);
        this.buf = this.buf.slice(i + tag.length);
        this.inThink = !this.inThink;
        continue;
      }
      // 標籤可能被切在兩段之間：保留結尾可能是標籤開頭的部分。
      const keep = partialSuffix(this.buf, tag);
      if (!this.inThink) out += this.buf.slice(0, this.buf.length - keep);
      this.buf = this.buf.slice(this.buf.length - keep);
      return out;
    }
  }
}

function partialSuffix(s: string, tag: string): number {
  for (let n = Math.min(tag.length - 1, s.length); n > 0; n--) {
    if (s.endsWith(tag.slice(0, n))) return n;
  }
  return 0;
}

// ---------------------------------------------------------------- 順序

/** 依 INTERPRET_PROVIDERS（預設 "gemini,nvidia"）排出有設定金鑰的供應商。 */
export function configuredProviders(): Provider[] {
  const factories: Record<ProviderName, () => Provider | null> = { gemini, nvidia };
  const order = (process.env.INTERPRET_PROVIDERS ?? "gemini,nvidia")
    .split(",")
    .map((s) => s.trim())
    .filter((s): s is ProviderName => s in factories);
  return order.map((n) => factories[n]()).filter((p): p is Provider => p !== null);
}
