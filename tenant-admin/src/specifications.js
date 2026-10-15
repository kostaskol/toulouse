/**
 * Specifications as editable rows, one input per value.
 *
 * @param specifications [Array<Object>] as the API returns them
 * @return [Array<Object>] rows of `name` and `values`
 */
export const specificationRows = (specifications) =>
  specifications.map(({ name, values }) => ({ name, values: [...values] }));

/**
 * A blank row for a new specification.
 *
 * @return [Object]
 */
export const blankSpecificationRow = () => ({ name: "", values: [""] });

// Close to how the API folds names, which covers Greek. A duplicate this misses still fails at the API.
const fold = (name) =>
  name.normalize("NFD").replace(/\p{M}/gu, "").toLowerCase().replace(/ς/g, "σ").replace(/[[\]]/g, "");

/**
 * Rows as the API takes them. A fully blank row is left out. A half-filled one is an error, as the API refuses it.
 *
 * @param rows [Array<Object>]
 * @return [Object] `param`, values by name, and `errors`, messages by row index
 */
export function specificationsParam(rows) {
  const param = {};
  const errors = {};
  const seen = new Set();
  rows.forEach((row, index) => {
    const name = row.name.trim();
    const values = row.values.map((value) => value.trim()).filter(Boolean);
    if (!name && !values.length) return;

    if (!name) errors[index] = "Γράψτε όνομα.";
    else if (!values.length) errors[index] = "Γράψτε τουλάχιστον μία τιμή.";
    else if (seen.has(fold(name))) errors[index] = "Η προδιαγραφή υπάρχει ήδη σε άλλη γραμμή.";
    else param[name] = values;
    if (name) seen.add(fold(name));
  });
  return { param, errors };
}
