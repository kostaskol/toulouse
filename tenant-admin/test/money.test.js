import { test } from "node:test";
import assert from "node:assert/strict";
import { eurosInput, parseEuros } from "../src/money.js";

test("reads whole euros, a comma and a dot", () => {
  assert.equal(parseEuros("12"), 1200);
  assert.equal(parseEuros("12,5"), 1250);
  assert.equal(parseEuros(" 12.05 "), 1205);
  assert.equal(parseEuros("0,99"), 99);
});

test("keeps cents exact where a float would drift", () => {
  assert.equal(parseEuros("1,15"), 115);
  assert.equal(parseEuros("4,35"), 435);
});

test("refuses blanks, negatives, thousand separators and a third decimal", () => {
  for (const text of ["", "  ", "-1", "1.234,56", "1,234", "abc", null, undefined]) {
    assert.equal(parseEuros(text), null, String(text));
  }
});

test("writes cents back as a merchant types them", () => {
  assert.equal(eurosInput(1205), "12,05");
  assert.equal(eurosInput(99), "0,99");
  assert.equal(eurosInput(null), "");
  assert.equal(parseEuros(eurosInput(123456)), 123456);
});
