import assert from "node:assert/strict";
import { test } from "node:test";
import { BadRequest, buildUserMessage, parseRequest } from "./prompt.ts";

const base = { deck: "sensoji", number: 1, category: "wish", question: "會順利嗎？", tone: "gentle" };

test("合法請求", () => {
  assert.deepEqual(parseRequest(base), base);
});

test("籤號範圍依籤種", () => {
  assert.throws(() => parseRequest({ ...base, number: 101 }), BadRequest);
  assert.throws(() => parseRequest({ ...base, deck: "tw60", number: 61 }), BadRequest);
  assert.equal(parseRequest({ ...base, deck: "tw60", number: 60 }).number, 60);
  assert.throws(() => parseRequest({ ...base, number: 1.5 }), BadRequest);
});

test("類別、長度、語氣", () => {
  assert.throws(() => parseRequest({ ...base, category: "nope" }), BadRequest);
  assert.throws(() => parseRequest({ ...base, question: "字".repeat(201) }), BadRequest);
  assert.equal(parseRequest({ ...base, question: "字".repeat(200) }).question.length, 200);
  assert.equal(parseRequest({ ...base, tone: "weird" }).tone, "gentle");
});

test("空白問題", () => {
  const msg = buildUserMessage(parseRequest({ ...base, question: "   " }));
  assert.match(msg, /未輸入問題/);
});

test("淺草寺附分項判語與吉凶", () => {
  const msg = buildUserMessage(parseRequest({ ...base, category: "health" }));
  assert.match(msg, /第 1 籤（大吉）/);
  assert.match(msg, /判語（病人）：病人本ぶくすべし/);
});

test("第 28 籤缺「旅行」改附整段判語", () => {
  const msg = buildUserMessage(parseRequest({ ...base, number: 28, category: "trip" }));
  assert.match(msg, /整段判語（此籤沒有「旅行」分項）/);
});

test("六十甲子籤不附判語、附干支", () => {
  const msg = buildUserMessage(parseRequest({ ...base, deck: "tw60", number: 1 }));
  assert.match(msg, /第 1 籤（甲子）/);
  assert.doesNotMatch(msg, /判語/);
});
