// 籤詩資料（伺服器端查表，不信任 App 傳來的籤文與判語）。
import sensojiFile from "../../app/assets/data/poems_sensoji.json" with { type: "json" };
import tw60File from "../../app/assets/data/poems_tw60.json" with { type: "json" };
import judgmentsFile from "../../app/assets/data/judgments_sensoji.json" with { type: "json" };
import categoryFile from "../../app/assets/data/category_map.json" with { type: "json" };

export type Deck = "sensoji" | "tw60";

export interface Category {
  id: string;
  label: string;
  sensoji: string;
  tw60: string;
}

export interface SensojiPoem {
  number: number;
  rank: string;
  lines: string[];
}

export interface Tw60Poem {
  number: number;
  ganzhi: string;
  lines: string[];
}

interface Judgment {
  number: number;
  rank: string;
  judgment_original: string;
  items: Record<string, string>;
}

const sensoji = new Map<number, SensojiPoem>(
  (sensojiFile.poems as SensojiPoem[]).map((p) => [p.number, p]),
);
const tw60 = new Map<number, Tw60Poem>((tw60File.poems as Tw60Poem[]).map((p) => [p.number, p]));
const judgments = new Map<number, Judgment>(
  (judgmentsFile as Judgment[]).map((j) => [j.number, j]),
);
const categories = new Map<string, Category>(
  (categoryFile.categories as Category[]).map((c) => [c.id, c]),
);

export function getCategory(id: string): Category | undefined {
  return categories.get(id);
}

export function getSensojiPoem(n: number): SensojiPoem | undefined {
  return sensoji.get(n);
}

export function getTw60Poem(n: number): Tw60Poem | undefined {
  return tw60.get(n);
}

/** 該分項的判語原文；缺分項（例：第 28 籤沒有「旅行」）時回傳整段原文。 */
export function getJudgment(
  n: number,
  item: string,
): { text: string; isWhole: boolean } | undefined {
  const j = judgments.get(n);
  if (!j) return undefined;
  const part = j.items[item];
  return part ? { text: part, isWhole: false } : { text: j.judgment_original, isWhole: true };
}
