// 把模型逐字輸出的 <meaning>…</meaning> 等標籤，轉成分段事件，讓 App 逐段顯示。
import { SECTIONS, type Section } from "./prompt.ts";

export type SectionEvent =
  | { type: "start"; section: Section }
  | { type: "delta"; section: Section; text: string }
  | { type: "end"; section: Section };

const OPEN = new Map<string, Section>(SECTIONS.map((s) => [`<${s}>`, s]));
const LONGEST_TAG = Math.max(...SECTIONS.map((s) => s.length)) + 3;

/**
 * 串流解析器。push() 餵入任意切割的文字片段；標籤可能被切在兩個片段之間，
 * 所以遇到未閉合的 "<" 會先暫存。標籤外的文字一律丟棄。
 */
export class SectionParser {
  private buf = "";
  private current: Section | null = null;

  push(chunk: string): SectionEvent[] {
    this.buf += chunk;
    const out: SectionEvent[] = [];
    for (;;) {
      const lt = this.buf.indexOf("<");
      if (lt === -1) {
        this.emitText(this.buf, out);
        this.buf = "";
        break;
      }
      this.emitText(this.buf.slice(0, lt), out);
      this.buf = this.buf.slice(lt);
      const gt = this.buf.indexOf(">");
      if (gt === -1) {
        // 可能是被切開的標籤；太長就不可能是標籤，當一般文字輸出。
        if (this.buf.length > LONGEST_TAG) {
          this.emitText(this.buf[0]!, out);
          this.buf = this.buf.slice(1);
          continue;
        }
        break;
      }
      const tag = this.buf.slice(0, gt + 1);
      if (this.handleTag(tag, out)) {
        this.buf = this.buf.slice(gt + 1);
      } else {
        this.emitText("<", out);
        this.buf = this.buf.slice(1);
      }
    }
    return out;
  }

  /** 串流結束：補發未閉合段落的 end。 */
  finish(): SectionEvent[] {
    const out: SectionEvent[] = [];
    if (this.buf) this.emitText(this.buf, out);
    this.buf = "";
    if (this.current) out.push({ type: "end", section: this.current });
    this.current = null;
    return out;
  }

  private handleTag(tag: string, out: SectionEvent[]): boolean {
    const open = OPEN.get(tag);
    if (open) {
      if (this.current) out.push({ type: "end", section: this.current });
      this.current = open;
      out.push({ type: "start", section: open });
      return true;
    }
    if (this.current && tag === `</${this.current}>`) {
      out.push({ type: "end", section: this.current });
      this.current = null;
      return true;
    }
    return false;
  }

  private emitText(text: string, out: SectionEvent[]): void {
    if (!text || !this.current) return;
    const last = out.at(-1);
    if (last?.type === "delta" && last.section === this.current) last.text += text;
    else out.push({ type: "delta", section: this.current, text });
  }
}
