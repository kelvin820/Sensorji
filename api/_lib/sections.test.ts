import assert from "node:assert/strict";
import { test } from "node:test";
import { SectionParser, type SectionEvent } from "./sections.ts";

function run(chunks: string[]): Record<string, string> {
  const p = new SectionParser();
  const events: SectionEvent[] = [];
  for (const c of chunks) events.push(...p.push(c));
  events.push(...p.finish());
  const out: Record<string, string> = {};
  for (const e of events) if (e.type === "delta") out[e.section] = (out[e.section] ?? "") + e.text;
  return out;
}

const FULL =
  "<meaning>月被浮雲遮</meaning>\n<relation>對照</relation><one_line>慢慢來</one_line><actions>\n- 一\n- 二\n</actions>";

test("一次整段", () => {
  assert.deepEqual(run([FULL]), {
    meaning: "月被浮雲遮",
    relation: "對照",
    one_line: "慢慢來",
    actions: "\n- 一\n- 二\n",
  });
});

test("每個字元切開也一樣", () => {
  assert.deepEqual(run([...FULL]), run([FULL]));
});

test("標籤外文字丟棄、內文的 < 保留", () => {
  assert.deepEqual(run(["好的。<meaning>a < b，<b>c</meaning>結尾"]), { meaning: "a < b，<b>c" });
});

test("未閉合段落在 finish 時補 end", () => {
  const p = new SectionParser();
  const ev = [...p.push("<care>請撥 1925"), ...p.finish()];
  assert.deepEqual(ev.at(-1), { type: "end", section: "care" });
});

test("事件順序 start → delta → end", () => {
  const p = new SectionParser();
  const ev = [...p.push("<one_line>"), ...p.push("加油"), ...p.push("</one_line>")];
  assert.deepEqual(
    ev.map((e) => e.type),
    ["start", "delta", "end"],
  );
});
