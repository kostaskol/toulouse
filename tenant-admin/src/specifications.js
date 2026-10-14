/**
 * Specifications as editable rows, values joined by commas.
 *
 * @param specifications [Array<Object>] as the API returns them
 * @return [Array<Object>] rows of `name` and `values`
 */
export const specificationRows = (specifications) =>
  specifications.map(({ name, values }) => ({ name, values: values.join(", ") }));

/**
 * Rows as the API takes them. A row without a name or values states nothing, so it is left out.
 *
 * @param rows [Array<Object>]
 * @return [Object] values by name
 */
export function specificationsParam(rows) {
  const entries = rows.map((row) => [
    row.name.trim(), row.values.split(",").map((value) => value.trim()).filter(Boolean)
  ]);
  return Object.fromEntries(entries.filter(([name, values]) => name && values.length));
}
