import { test } from "node:test";
import assert from "node:assert/strict";
import { linkedFirst, singleValue, specificationRows, specificationsParam } from "../src/specifications.js";

test("round-trips the API's specifications through rows", () => {
  const specifications = [{ id: "1", name: "A", values: ["x, with a comma", "y"] }];

  assert.deepEqual(specificationRows(specifications), [{ name: "A", values: ["x, with a comma", "y"] }]);
  assert.deepEqual(specificationsParam(specificationRows(specifications)), {
    param: { A: ["x, with a comma", "y"] }, errors: {}
  });
});

test("trims names and values and drops blank values", () => {
  assert.deepEqual(specificationsParam([{ name: " A ", values: [" x ", "", " y"] }]).param, { A: ["x", "y"] });
});

test("leaves out a fully blank row", () => {
  assert.deepEqual(specificationsParam([{ name: " ", values: ["", " "] }]), { param: {}, errors: {} });
});

test("refuses a row with a name and no values, or values and no name", () => {
  const { param, errors } = specificationsParam([
    { name: "A", values: [" "] }, { name: "B", values: ["x"] }, { name: "", values: ["y"] }
  ]);

  assert.deepEqual(param, { B: ["x"] });
  assert.deepEqual(Object.keys(errors), ["0", "2"]);
});

test("refuses a second row whose name folds like an earlier one", () => {
  const { param, errors } = specificationsParam([
    { name: "Χρώμα", values: ["Κόκκινο"] }, { name: "χρωμα", values: ["Μπλε"] }
  ]);

  assert.deepEqual(param, { Χρώμα: ["Κόκκινο"] });
  assert.deepEqual(Object.keys(errors), ["1"]);
});

test("finds a single-value spec by its folded name", () => {
  const definitions = [{ name: "Χρώμα", multiple: false }, { name: "Υλικό", multiple: true }];

  assert.equal(singleValue(definitions, " ΧΡΩΜΑ "), true);
  assert.equal(singleValue(definitions, "Υλικό"), false);
  assert.equal(singleValue(definitions, "Οθόνη"), false);
});

test("puts linked definitions first and keeps each group's order", () => {
  const definitions = [{ id: "1" }, { id: "2" }, { id: "3" }, { id: "4" }];

  const sorted = linkedFirst(definitions, [{ specification_id: "4" }, { specification_id: "2" }]);
  assert.deepEqual(sorted.map((definition) => definition.id), ["2", "4", "1", "3"]);
});
