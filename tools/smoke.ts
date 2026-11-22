// 對已部署的解籤 API 送一次真實請求，印出串流內容。會使用一次 LLM 額度。
// 用法：npm run smoke -- https://你的專案.vercel.app
const base = process.argv[2]?.replace(/\/$/, "");
if (!base) {
  console.error("用法：npm run smoke -- https://你的專案.vercel.app");
  process.exit(1);
}
const res = await fetch(`${base}/api/interpret`, {
  method: "POST",
  headers: { "Content-Type": "application/json" },
  body: JSON.stringify({ deck: "sensoji", number: 1, category: "work", question: "明年適合換工作嗎？", tone: "gentle" }),
});
console.log(`HTTP ${res.status} ${res.headers.get("content-type")}`);
if (!res.ok || !res.body) {
  console.log(await res.text());
  process.exit(1);
}
const decoder = new TextDecoder();
let event = "";
let buf = "";
const t0 = Date.now();
for await (const chunk of res.body) {
  buf += decoder.decode(chunk, { stream: true });
  let nl: number;
  while ((nl = buf.indexOf("\n")) !== -1) {
    const line = buf.slice(0, nl);
    buf = buf.slice(nl + 1);
    if (line.startsWith("event: ")) event = line.slice(7);
    else if (line.startsWith("data: ")) {
      const data = JSON.parse(line.slice(6));
      if (event === "start") process.stdout.write(`\n【${data.section}】`);
      else if (event === "delta") process.stdout.write(data.text);
      else if (event === "done" || event === "error") console.log(`\n\n${event}：${JSON.stringify(data)}（${Date.now() - t0} ms）`);
    }
  }
}
