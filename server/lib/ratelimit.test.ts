import assert from "node:assert/strict";
import { afterEach, beforeEach, describe, it } from "node:test";
import { checkRequest, clientIp, clientKey, LIMIT_MESSAGES, resetMemoryLimiter } from "./ratelimit.ts";

const realFetch = globalThis.fetch;
const ENV = [
  "UPSTASH_REDIS_REST_URL",
  "UPSTASH_REDIS_REST_TOKEN",
  "KV_REST_API_URL",
  "KV_REST_API_TOKEN",
  "RATE_LIMIT_PER_HOUR",
  "RATE_LIMIT_PER_DAY",
  "RATE_LIMIT_GLOBAL_PER_DAY",
];
beforeEach(() => resetMemoryLimiter());
afterEach(() => {
  globalThis.fetch = realFetch;
  for (const k of ENV) delete process.env[k];
});

// 2026-11-28 10:00 台灣時間
const T = Date.UTC(2026, 10, 28, 2, 0, 0);

async function run(key: string, times: number, now = T) {
  const out = [];
  for (let i = 0; i < times; i++) out.push(await checkRequest(key, now));
  return out;
}

/** 假的 Upstash：記憶體裡的 INCR，順便記下收到的指令。 */
function fakeUpstash() {
  const store = new Map<string, number>();
  const calls: { url: string; auth: string | null; body: string[][] }[] = [];
  globalThis.fetch = (async (url: string, init: RequestInit) => {
    const body = JSON.parse(init.body as string) as string[][];
    calls.push({ url, auth: new Headers(init.headers).get("Authorization"), body });
    const result = body.map(([cmd, key]) => {
      if (cmd === "INCR") {
        const n = (store.get(key) ?? 0) + 1;
        store.set(key, n);
        return { result: n };
      }
      return { result: 1 };
    });
    return new Response(JSON.stringify(result), { status: 200 });
  }) as typeof fetch;
  return { store, calls };
}

describe("速率限制", () => {
  it("每個 IP 每小時上限（預設 10），超過回 hour 並給到整點的秒數", async () => {
    const r = await run("ip:1.1.1.1", 11);
    assert.ok(r.slice(0, 10).every((x) => x.ok));
    assert.deepEqual(r[10], { ok: false, reason: "hour", retryAfter: 3600 });
    // 另一個 IP 不受影響
    assert.equal((await checkRequest("ip:2.2.2.2", T)).ok, true);
  });

  it("下一個小時重新計算，但每天上限（預設 30）跨小時累計", async () => {
    let ok = 0;
    let last;
    for (let h = 0; h < 4; h++) {
      for (const x of await run("ip:3.3.3.3", 10, T + h * 3600_000)) {
        if (x.ok) ok++;
        last = x;
      }
    }
    assert.equal(ok, 30);
    assert.equal(last?.ok, false);
    assert.equal(last && !last.ok && last.reason, "day");
  });

  it("每天以台灣時間 00:00 換日", async () => {
    process.env.RATE_LIMIT_PER_DAY = "1";
    const beforeMidnight = Date.UTC(2026, 10, 28, 15, 59, 0); // 台灣 23:59
    assert.equal((await checkRequest("ip:4.4.4.4", beforeMidnight)).ok, true);
    const blocked = await checkRequest("ip:4.4.4.4", beforeMidnight);
    assert.deepEqual(blocked, { ok: false, reason: "day", retryAfter: 60 });
    assert.equal((await checkRequest("ip:4.4.4.4", beforeMidnight + 120_000)).ok, true, "台灣 00:01 重新計算");
  });

  it("全站每天上限：換 IP 也擋得住；被 IP 上限擋下的請求不佔全站額度", async () => {
    process.env.RATE_LIMIT_GLOBAL_PER_DAY = "5";
    process.env.RATE_LIMIT_PER_HOUR = "2";
    // 同一個 IP 打 10 次：只有 2 次算進全站
    await run("ip:5.5.5.5", 10);
    const others = await Promise.all([1, 2, 3, 4].map((i) => checkRequest(`ip:6.6.6.${i}`, T)));
    assert.deepEqual(
      others.map((x) => x.ok),
      [true, true, true, false],
    );
    assert.equal(!others[3].ok && others[3].reason, "global");
  });

  it("有 Upstash 時用 Redis 計數；也認 Vercel Marketplace 的 KV_ 變數名", async () => {
    process.env.KV_REST_API_URL = "https://redis.example";
    process.env.KV_REST_API_TOKEN = "t";
    const { calls } = fakeUpstash();
    assert.equal((await checkRequest("ip:7.7.7.7", T)).ok, true);
    assert.equal(calls[0].url, "https://redis.example/pipeline");
    assert.equal(calls[0].auth, "Bearer t");
    assert.deepEqual(
      calls[0].body.map((c) => c[0]),
      ["INCR", "EXPIRE", "INCR", "EXPIRE"],
    );
    assert.equal(calls.length, 2, "IP 沒超過才另外算全站");
  });

  it("Redis 故障時退回記憶體計數，仍然有上限", async () => {
    process.env.UPSTASH_REDIS_REST_URL = "https://redis.example";
    process.env.UPSTASH_REDIS_REST_TOKEN = "t";
    globalThis.fetch = (async () => new Response("down", { status: 500 })) as typeof fetch;
    const r = await run("ip:8.8.8.8", 11);
    assert.equal(r[9].ok, true);
    assert.equal(r[10].ok, false);
  });

  it("每種上限都有可以直接顯示的中文訊息；IP 取 x-forwarded-for 第一個", () => {
    for (const m of Object.values(LIMIT_MESSAGES)) assert.match(m, /[一-鿿]/);
    const req = new Request("https://x", { headers: { "x-forwarded-for": "9.9.9.9, 10.0.0.1" } });
    assert.equal(clientIp(req), "9.9.9.9");
  });

  it("限流鍵是 IP 的雜湊，不含 IP 原文；同一 IP 得到同一把鍵", async () => {
    const a = (ip: string) => new Request("https://x", { headers: { "x-forwarded-for": ip } });
    const k1 = await clientKey(a("9.9.9.9"));
    assert.match(k1, /^ip:[0-9a-f]{16}$/);
    assert.ok(!k1.includes("9.9.9.9"));
    assert.equal(await clientKey(a("9.9.9.9")), k1);
    assert.notEqual(await clientKey(a("9.9.9.8")), k1);
  });
});
