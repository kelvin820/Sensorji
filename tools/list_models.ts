// 列出你的金鑰目前可用的解籤模型（只在本機執行）。
// 用法：在 .env.local 填好金鑰後執行 `npm run models`。金鑰不會印出來。
const gemini = process.env.GEMINI_API_KEY;
if (gemini) {
  const res = await fetch("https://generativelanguage.googleapis.com/v1beta/models?pageSize=200", {
    headers: { "x-goog-api-key": gemini },
  });
  const body = (await res.json()) as { models?: { name: string; supportedGenerationMethods?: string[] }[] };
  console.log(`\nGemini（HTTP ${res.status}），可串流的模型：`);
  for (const m of body.models ?? []) {
    if (m.supportedGenerationMethods?.includes("streamGenerateContent")) console.log("  " + m.name.replace(/^models\//, ""));
  }
} else console.log("未設定 GEMINI_API_KEY");

const nvidia = process.env.NVIDIA_API_KEY;
if (nvidia) {
  const res = await fetch("https://integrate.api.nvidia.com/v1/models", {
    headers: { Authorization: `Bearer ${nvidia}` },
  });
  const body = (await res.json()) as { data?: { id: string }[] };
  console.log(`\nNVIDIA（HTTP ${res.status}）：`);
  for (const m of body.data ?? []) console.log("  " + m.id);
} else console.log("未設定 NVIDIA_API_KEY");
