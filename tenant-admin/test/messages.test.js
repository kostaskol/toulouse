import { test } from "node:test";
import assert from "node:assert/strict";
import { ApiError } from "../src/api.js";
import { errorMessage, formErrors } from "../src/messages.js";

const failure = (...errors) => new ApiError(422, errors);

test("never shows the API's English text for an unknown code", () => {
  const message = errorMessage(failure({ code: "no_such_code", message: "English text" }));

  assert.doesNotMatch(message, /English/);
  assert.equal(message, errorMessage(new TypeError("a bug")));
});

test("names the columns a CSV error carries", () => {
  const error = failure({ code: "unknown_columns", message: "Unknown columns: a, b.", columns: ["a", "b"] });

  assert.match(errorMessage(error), /: a, b\.$/);
});

test("puts a shown field's error under it and prefixes the field name otherwise", () => {
  const errors = formErrors(failure({ code: "blank", field: "title" }, { code: "taken", field: "slug" }), ["title"]);

  assert.deepEqual(Object.keys(errors.fields), ["title"]);
  assert.equal(errors.base.length, 1);
  assert.match(errors.base[0], /^slug: /);
});

test("reads the lock time from Retry-After", () => {
  const error = new ApiError(429, [{ code: "too_many_attempts" }], 180);

  assert.match(errorMessage(error), / 3 /);
  assert.match(formErrors(error).base[0], / 3 /);
});
