// 速率限制（BUILD_PLAN 第 8 節「防濫用」）。網頁版公開後任何人都能呼叫 /api/interpret，
// 每次都會花 Gemini／NVIDIA 的額度，所以有三道上限：
//   1. 每個 IP 每小時（RATE_LIMIT_PER_HOUR，預設 10）
//   2. 每個 IP 每天（RATE_LIMIT_PER_DAY，預設 30）
//   3. 全站每天（RATE_LIMIT_GLOBAL_PER_DAY，預設 500）——換 IP 也擋得住，保護總花費
// 「天」以台灣時間 00:00 換日。
//
// serverless 之間不共用記憶體，計數放在 Upstash Redis（REST）。變數名稱兩種都認：
// 自己到 Upstash 建立的 UPSTASH_REDIS_REST_URL／_TOKEN，或從 Vercel Marketplace 加 Upstash 時
// 自動帶入的 KV_REST_API_URL／KV_REST_API_TOKEN。
// 沒設定或 Redis 故障時退回「單一執行個體的記憶體計數」：擋不住分散的請求，但不會完全不設防。

export type LimitReason = "hour" | "day" | "global";
export type LimitResult = { ok: true } | { ok: false; reason: LimitReason; retryAfter: number };

const HOUR = 60 * 60;
const DAY = 24 * HOUR;
const TZ_OFFSET = 8 * HOUR; // 台灣時間

function limits() {
  const num = (name: string, fallback: number) => {
    const v = Number(process.env[name]);
    return Number.isFinite(v) && v > 0 ? v : fallback;
  };
  return {
    hour: num("RATE_LIMIT_PER_HOUR", 10),
    day: num("RATE_LIMIT_PER_DAY", 30),
    global: num("RATE_LIMIT_GLOBAL_PER_DAY", 500),
  };
}

function redisConfig(): { url: string; token: string } | null {
  const url = process.env.UPSTASH_REDIS_REST_URL || process.env.KV_REST_API_URL;
  const token = process.env.UPSTASH_REDIS_REST_TOKEN || process.env.KV_REST_API_TOKEN;
  return url && token ? { url, token } : null;
}

/** 目前的時間桶與距離下一桶的秒數。 */
function buckets(nowMs: number) {
  const s = Math.floor(nowMs / 1000);
  const hour = Math.floor(s / HOUR);
  const local = s + TZ_OFFSET;
  const day = Math.floor(local / DAY);
  return {
    hour,
    day,
    hourLeft: HOUR - (s % HOUR),
    dayLeft: DAY - (local % DAY),
  };
}

// ── Redis（REST pipeline） ─────────────────────────────────────

async function redisIncr(cfg: { url: string; token: string }, keys: [string, number][]): Promise<number[]> {
  const commands = keys.flatMap(([k, ttl]) => [
    ["INCR", k],
    ["EXPIRE", k, String(ttl)],
  ]);
  const res = await fetch(`${cfg.url}/pipeline`, {
    method: "POST",
    headers: { Authorization: `Bearer ${cfg.token}`, "Content-Type": "application/json" },
    body: JSON.stringify(commands),
    signal: AbortSignal.timeout(2000), // 限流不能拖慢解籤
  });
  if (!res.ok) throw new Error(`redis ${res.status}`);
  const out = (await res.json()) as { result?: unknown; error?: string }[];
  return keys.map((_, i) => {
    const r = out[i * 2];
    if (r?.error || typeof r?.result !== "number") throw new Error("redis result");
    return r.result;
  });
}

// ── 記憶體退路 ─────────────────────────────────────────────

const memory = new Map<string, number>();

function memoryIncr(keys: [string, number][]): number[] {
  if (memory.size > 10_000) memory.clear(); // 桶的鍵會一直換，偶爾整個清掉
  return keys.map(([k]) => {
    const n = (memory.get(k) ?? 0) + 1;
    memory.set(k, n);
    return n;
  });
}

/** 測試用：清掉記憶體計數。 */
export function resetMemoryLimiter(): void {
  memory.clear();
}

let warned = false;

async function incr(keys: [string, number][]): Promise<number[]> {
  const cfg = redisConfig();
  if (cfg) {
    try {
      return await redisIncr(cfg, keys);
    } catch (e) {
      console.error(`ratelimit: redis failed (${e instanceof Error ? e.message : "error"}), using memory`);
    }
  } else if (!warned) {
    warned = true;
    console.warn("ratelimit: no Upstash Redis configured, using per-instance memory");
  }
  return memoryIncr(keys);
}

/**
 * 算一次請求。先算這個 IP 的小時與當日次數；沒超過才算進全站當日次數
 * （被擋下的請求不佔全站額度，免得有人狂刷就讓所有人都不能用）。
 */
export async function checkRequest(key: string, nowMs = Date.now()): Promise<LimitResult> {
  const max = limits();
  const b = buckets(nowMs);
  const [perHour, perDay] = await incr([
    [`rl:interpret:${key}:h${b.hour}`, HOUR],
    [`rl:interpret:${key}:d${b.day}`, DAY],
  ]);
  if (perDay > max.day) return { ok: false, reason: "day", retryAfter: b.dayLeft };
  if (perHour > max.hour) return { ok: false, reason: "hour", retryAfter: b.hourLeft };

  const [global] = await incr([[`rl:interpret:all:d${b.day}`, DAY]]);
  if (global > max.global) return { ok: false, reason: "global", retryAfter: b.dayLeft };
  return { ok: true };
}

export const LIMIT_MESSAGES: Record<LimitReason, string> = {
  hour: "這一小時求籤的次數已經滿了，休息一下，稍後再來",
  day: "今天求籤的次數已經滿了，明天再來吧",
  global: "今天的解籤服務已經額滿，請明天再試",
};

/**
 * 取用戶端 IP（Vercel 會設 x-forwarded-for）。只拿來當限流鍵，不記錄。
 * 不用 App 自報的裝置 ID：那可以任意偽造來繞過限制。
 * 行動網路常多人共用 IP，上限請依實際流量用環境變數調整。
 */
export function clientKey(req: Request): string {
  const fwd = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim();
  return `ip:${fwd || req.headers.get("x-real-ip") || "unknown"}`;
}
