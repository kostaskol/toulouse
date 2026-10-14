import { test } from "node:test";
import assert from "node:assert/strict";
import { specificationRows, specificationsParam } from "../src/specifications.js";

test("round-trips the API's specifications through rows", () => {
  const specifications = [{ id: "1", name: "A", values: ["x", "y"] }];

  assert.deepEqual(specificationRows(specifications), [{ name: "A", values: "x, y" }]);
  assert.deepEqual(specificationsParam(specificationRows(specifications)), { A: ["x", "y"] });
});

test("trims names and values and drops blank values", () => {
  assert.deepEqual(specificationsParam([{ name: " A ", values: " x ,, y , " }]), { A: ["x", "y"] });
});

test("leaves out rows with no name or no values, which the API would refuse", () => {
  assert.deepEqual(specificationsParam([{ name: "A", values: " , " }, { name: " ", values: "x" }]), {});
});
