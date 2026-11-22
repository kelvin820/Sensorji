// POST /api/interpret — AI 解籤（BUILD_PLAN 第 8 節，介面見 docs/API.md）。
// 原始碼在 server/；部署用的 api/interpret.js 由 `npm run build:api` 打包產生（Vercel 不吃 .ts 副檔名的 import）。
// 供應商：Gemini 為主、NVIDIA 為備援（server/lib/providers.ts）。
// 隱私：不記錄使用者問題；錯誤記錄只留供應商名稱與錯誤碼。
import { BadRequest, buildUserMessage, parseRequest, SYSTEM_PROMPT } from "./lib/prompt.ts";
import { configuredProviders, ProviderError } from "./lib/providers.ts";
import { allowRequest, clientKey } from "./lib/ratelimit.ts";
import { SectionParser, type SectionEvent } from "./lib/sections.ts";

export const maxDuration = 60;

const MAX_BODY_BYTES = 4096;

const MESSAGES: Record<string, string> = {
  refused: "這個問題暫時無法解籤，換個方式問問看",
  busy: "解籤的人太多了，請稍後再試",
  upstream: "暫時無法解籤，請稍後再試",
  config: "暫時無法解籤，請稍後再試",
  internal: "暫時無法解籤，請稍後再試",
};

function json(status: number, code: string, message: string): Response {
  return new Response(JSON.stringify({ error: { code, message } }), {
    status,
    headers: { "Content-Type": "application/json; charset=utf-8" },
  });
}

function sse(event: string, data: unknown): string {
  return `event: ${event}\ndata: ${JSON.stringify(data)}\n\n`;
}

export async function POST(request: Request): Promise<Response> {
  const raw = await request.text();
  if (raw.length > MAX_BODY_BYTES) return json(413, "too_large", "內容太長了");

  let req;
  try {
    req = parseRequest(JSON.parse(raw));
  } catch (e) {
    const msg = e instanceof BadRequest ? e.message : "請求格式錯誤";
    return json(400, "bad_request", msg);
  }

  const providers = configuredProviders();
  if (providers.length === 0) {
    console.error("interpret: no provider key configured");
    return json(503, "unavailable", "解籤服務尚未設定");
  }

  if (!(await allowRequest(clientKey(request)))) {
    return json(429, "rate_limited", "求籤太頻繁了，請稍後再試");
  }

  const user = buildUserMessage(req);
  const encoder = new TextEncoder();
  const body = new ReadableStream<Uint8Array>({
    async start(controller) {
      const send = (event: string, data: unknown) => controller.enqueue(encoder.encode(sse(event, data)));
      const forward = (events: SectionEvent[]) => {
        for (const ev of events) {
          if (ev.type === "delta") send("delta", { section: ev.section, text: ev.text });
          else send(ev.type, { section: ev.section });
        }
      };

      let lastCode = "internal";
      try {
        for (const provider of providers) {
          const parser = new SectionParser();
          let started = false;
          try {
            const it = provider.stream(SYSTEM_PROMPT, user, request.signal);
            let step = await it.next();
            while (!step.done) {
              const events = parser.push(step.value);
              if (events.length) started = true;
              forward(events);
              step = await it.next();
            }
            forward(parser.finish());
            send("done", { truncated: step.value.truncated });
            return;
          } catch (e) {
            if (request.signal.aborted) return; // 使用者離開畫面
            lastCode = e instanceof ProviderError ? e.code : "internal";
            const detail = e instanceof ProviderError ? e.detail : e instanceof Error ? e.name : "error";
            console.error(`interpret: ${provider.name} failed (${detail})`);
            // 已經開始輸出就不能換家，否則畫面上會接到另一份解說。
            if (started) break;
          }
        }
        send("error", { code: lastCode === "config" ? "upstream" : lastCode, message: MESSAGES[lastCode] });
      } finally {
        controller.close();
      }
    },
  });

  return new Response(body, {
    headers: {
      "Content-Type": "text/event-stream; charset=utf-8",
      "Cache-Control": "no-cache, no-transform",
      "X-Accel-Buffering": "no",
    },
  });
}
