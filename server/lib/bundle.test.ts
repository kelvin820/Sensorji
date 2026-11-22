// 部署用的 api/interpret.js 是打包產物並且進版控；改了 server/ 卻忘了重新打包，這個測試會失敗。
import assert from "node:assert/strict";
import { execFileSync } from "node:child_process";
import { mkdtempSync, readFileSync } from "node:fs";
import { tmpdir } from "node:os";
import { join } from "node:path";
import { it } from "node:test";

it("api/interpret.js 與 server/ 原始碼一致（不一致請執行 npm run build:api）", () => {
  const pkg = JSON.parse(readFileSync("package.json", "utf8")) as { scripts: Record<string, string> };
  const out = join(mkdtempSync(join(tmpdir(), "sensoji-")), "interpret.js");
  const cmd = pkg.scripts["build:api"]!.replace("--outfile=api/interpret.js", `--outfile=${out}`);
  execFileSync(cmd, { shell: true, stdio: "pipe" });
  // Windows 簽出時可能把換行轉成 CRLF，比較前統一成 LF。
  const norm = (p: string) => readFileSync(p, "utf8").replaceAll("\r\n", "\n");
  assert.ok(norm(out) === norm("api/interpret.js"), "api/interpret.js 過期了");
});
