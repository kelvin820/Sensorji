// 速率限制：serverless 之間不共用記憶體，所以計數放在 Upstash Redis（REST）。
// 未設定 UPSTASH_REDIS_REST_URL / _TOKEN 時不限制（本機開發用），正式環境務必設定。

const WINDOW_SECONDS = 60 * 60;
const MAX_PER_WINDOW = Number(process.env.RATE_LIMIT_PER_HOUR ?? 30);

export async function allowRequest(key: string): Promise<boolean> {
  const url = process.env.UPSTASH_REDIS_REST_URL;
  const token = process.env.UPSTASH_REDIS_REST_TOKEN;
  if (!url || !token) return true;

  const bucket = Math.floor(Date.now() / 1000 / WINDOW_SECONDS);
  const redisKey = `rl:interpret:${key}:${bucket}`;
  try {
    const res = await fetch(`${url}/pipeline`, {
      method: "POST",
      headers: { Authorization: `Bearer ${token}`, "Content-Type": "application/json" },
      body: JSON.stringify([
        ["INCR", redisKey],
        ["EXPIRE", redisKey, String(WINDOW_SECONDS)],
      ]),
    });
    if (!res.ok) return true; // 限流服務故障時不擋使用者
    const [incr] = (await res.json()) as [{ result: number }];
    return incr.result <= MAX_PER_WINDOW;
  } catch {
    return true;
  }
}

/**
 * 取用戶端 IP（Vercel 會設 x-forwarded-for）。只拿來當限流鍵，不記錄。
 * 不用 App 自報的裝置 ID：那可以任意偽造來繞過限制。
 * 行動網路常多人共用 IP，上限請依實際流量用 RATE_LIMIT_PER_HOUR 調整。
 */
export function clientKey(req: Request): string {
  const fwd = req.headers.get("x-forwarded-for")?.split(",")[0]?.trim();
  return `ip:${fwd || req.headers.get("x-real-ip") || "unknown"}`;
}
