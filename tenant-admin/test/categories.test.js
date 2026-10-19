import { test } from "node:test";
import assert from "node:assert/strict";
import { lineageLinks } from "../src/categories.js";

test("collects the links of a category and every category above it", () => {
  const categories = [
    { id: "root", parent_id: null, specification_links: [{ specification_id: "a", required: true }] },
    { id: "child", parent_id: "root", specification_links: [{ specification_id: "b", required: false }] },
    { id: "other", parent_id: null, specification_links: [{ specification_id: "c", required: true }] }
  ];

  assert.deepEqual(lineageLinks(categories, "child").map((link) => link.specification_id), ["b", "a"]);
  assert.deepEqual(lineageLinks(categories, null), []);
});
