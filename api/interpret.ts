// POST /api/interpret — AI 解籤（BUILD_PLAN 第 8 節，介面見 docs/API.md）。
// 隱私：不記錄使用者問題；錯誤記錄只留錯誤碼。
import Anthropic from "@anthropic-ai/sdk";
import { BadRequest, buildUserMessage, parseRequest, SYSTEM_PROMPT } from "./_lib/prompt.ts";
import { allowRequest, clientKey } from "./_lib/ratelimit.ts";
import { SectionParser, type SectionEvent } from "./_lib/sections.ts";

export const maxDuration = 60;

const MODEL = process.env.INTERPRET_MODEL ?? "claude-opus-5-5";
const EFFORT = (process.env.INTERPRET_EFFORT ?? "medium") as "low" | "medium" | "high";
const MAX_BODY_BYTES = 4096;

const client = new Anthropic(); // 讀 ANTHROPIC_API_KEY（只放在 Vercel 環境變數）

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

  if (!(await allowRequest(clientKey(request)))) {
    return json(429, "rate_limited", "求籤太頻繁了，請稍後再試");
  }

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

      try {
        const parser = new SectionParser();
        const stream = client.beta.messages.stream(
          {
            model: MODEL,
            max_tokens: 16000,
            output_config: { effort: EFFORT },
            system: [{ type: "text", text: SYSTEM_PROMPT, cache_control: { type: "ephemeral" } }],
            messages: [{ role: "user", content: buildUserMessage(req) }],
            // 安全分類器拒答時，由伺服器自動改用合適的模型重跑。
            betas: ["server-side-fallback-2026-07-01"],
            fallbacks: "default",
          },
          { signal: request.signal },
        );

        for await (const event of stream) {
          if (event.type === "content_block_delta" && event.delta.type === "text_delta") {
            forward(parser.push(event.delta.text));
          }
        }
        forward(parser.finish());

        const final = await stream.finalMessage();
        if (final.stop_reason === "refusal") {
          send("error", { code: "refused", message: "這個問題暫時無法解籤，換個方式問問看" });
        } else {
          send("done", { truncated: final.stop_reason === "max_tokens" });
        }
      } catch (e) {
        if (request.signal.aborted) {
          // 使用者離開畫面，不需回應
        } else if (e instanceof Anthropic.RateLimitError) {
          console.error("interpret: upstream 429");
          send("error", { code: "busy", message: "解籤的人太多了，請稍後再試" });
        } else if (e instanceof Anthropic.APIError) {
          console.error(`interpret: upstream ${e.status ?? "?"}`);
          send("error", { code: "upstream", message: "暫時無法解籤，請稍後再試" });
        } else {
          console.error(`interpret: internal ${e instanceof Error ? e.name : "error"}`);
          send("error", { code: "internal", message: "暫時無法解籤，請稍後再試" });
        }
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
