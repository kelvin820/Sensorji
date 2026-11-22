import assert from "node:assert/strict";
import { afterEach, describe, it } from "node:test";
import { POST } from "../interpret.ts";
import { configuredProviders, readSse, ThinkStripper } from "./providers.ts";

const realFetch = globalThis.fetch;
const ENV_KEYS = ["GEMINI_API_KEY", "NVIDIA_API_KEY", "INTERPRET_PROVIDERS"];
afterEach(() => {
  globalThis.fetch = realFetch;
  for (const k of ENV_KEYS) delete process.env[k];
});

function sseBody(datas: string[], splitEvery = 7): ReadableStream<Uint8Array> {
  const text = datas.map((d) => `data: ${d}\n\n`).join("");
  const enc = new TextEncoder();
  return new ReadableStream({
    start(c) {
      for (let i = 0; i < text.length; i += splitEvery) c.enqueue(enc.encode(text.slice(i, i + splitEvery)));
      c.close();
    },
  });
}

const geminiChunks = (texts: string[], finish = "STOP") =>
  texts.map((t, i) =>
    JSON.stringify({
      candidates: [{ content: { parts: [{ text: t }] }, ...(i === texts.length - 1 ? { finishReason: finish } : {}) }],
    }),
  );

const nvidiaChunks = (texts: string[]) => [
  ...texts.map((t) => JSON.stringify({ choices: [{ delta: { content: t } }] })),
  JSON.stringify({ choices: [{ delta: {}, finish_reason: "stop" }] }),
  "[DONE]",
];

const REPLY = ["<meaning>籤意", "說明</meaning><one_line>一句話</one_line>"];

async function interpret(): Promise<string> {
  const res = await POST(
    new Request("http://x/api/interpret", {
      method: "POST",
      body: JSON.stringify({ deck: "sensoji", number: 1, category: "wish", question: "會順利嗎" }),
    }),
  );
  return await res.text();
}

describe("readSse", () => {
  it("處理被任意切開的 data 行", async () => {
    const out: string[] = [];
    for await (const d of readSse(sseBody(["a", '{"x":1}', "[DONE]"], 3))) out.push(d);
    assert.deepEqual(out, ["a", '{"x":1}', "[DONE]"]);
  });
});

describe("ThinkStripper", () => {
  it("濾掉 <think> 區塊，即使標籤被切開", () => {
    const s = new ThinkStripper();
    const parts = ["<thi", "nk>想一想</th", "ink><meaning>", "好</meaning>"];
    assert.equal(parts.map((p) => s.push(p)).join(""), "<meaning>好</meaning>");
  });
});

describe("configuredProviders", () => {
  it("只列出有金鑰的供應商，並照設定順序", () => {
    process.env.NVIDIA_API_KEY = "n";
    assert.deepEqual(configuredProviders().map((p) => p.name), ["nvidia"]);
    process.env.GEMINI_API_KEY = "g";
    process.env.INTERPRET_PROVIDERS = "nvidia,gemini";
    assert.deepEqual(configuredProviders().map((p) => p.name), ["nvidia", "gemini"]);
  });
});

describe("POST /api/interpret", () => {
  it("沒有任何金鑰時回 503", async () => {
    const res = await POST(
      new Request("http://x/api/interpret", {
        method: "POST",
        body: JSON.stringify({ deck: "sensoji", number: 1, category: "wish" }),
      }),
    );
    assert.equal(res.status, 503);
  });

  it("Gemini 正常時分段串流，且不碰 NVIDIA", async () => {
    process.env.GEMINI_API_KEY = "g";
    process.env.NVIDIA_API_KEY = "n";
    const urls: string[] = [];
    globalThis.fetch = (async (url: string) => {
      urls.push(url);
      return new Response(sseBody(geminiChunks(REPLY)));
    }) as typeof fetch;
    const out = await interpret();
    assert.equal(urls.length, 1);
    assert.match(urls[0]!, /generativelanguage/);
    assert.match(out, /event: delta\ndata: \{"section":"meaning","text":"籤意"\}/);
    assert.match(out, /event: done\ndata: \{"truncated":false\}/);
  });

  it("Gemini 忙線時改用 NVIDIA", async () => {
    process.env.GEMINI_API_KEY = "g";
    process.env.NVIDIA_API_KEY = "n";
    globalThis.fetch = (async (url: string) =>
      /generativelanguage/.test(url)
        ? new Response("busy", { status: 429 })
        : new Response(sseBody(nvidiaChunks(REPLY)))) as typeof fetch;
    const out = await interpret();
    assert.match(out, /"section":"one_line","text":"一句話"/);
    assert.match(out, /event: done/);
    assert.doesNotMatch(out, /event: error/);
  });

  it("兩家都失敗時回錯誤事件", async () => {
    process.env.GEMINI_API_KEY = "g";
    process.env.NVIDIA_API_KEY = "n";
    globalThis.fetch = (async () => new Response("x", { status: 500 })) as typeof fetch;
    const out = await interpret();
    assert.match(out, /event: error\ndata: \{"code":"upstream"/);
  });

  it("Gemini 安全攔截時回 refused", async () => {
    process.env.GEMINI_API_KEY = "g";
    globalThis.fetch = (async () => new Response(sseBody(geminiChunks([""], "SAFETY")))) as typeof fetch;
    const out = await interpret();
    assert.match(out, /"code":"refused"/);
  });
});
