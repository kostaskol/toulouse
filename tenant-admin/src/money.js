const EURO = new Intl.NumberFormat("el-GR", { style: "currency", currency: "EUR" });
const AMOUNT = /^(\d+)(?:[.,](\d{1,2}))?$/;

export const formatPrice = (cents) => (cents === null || cents === undefined ? "" : EURO.format(cents / 100));

/**
 * Reads a euro amount typed with a comma or a dot. String arithmetic, so no float rounding touches money.
 *
 * @param text [String]
 * @return [Number, null] cents, or null when blank or not an amount
 */
export function parseEuros(text) {
  const match = AMOUNT.exec(String(text ?? "").trim());
  if (!match) return null;

  return Number(match[1]) * 100 + Number((match[2] ?? "").padEnd(2, "0"));
}

/**
 * @param cents [Number, null]
 * @return [String] the amount as a merchant types it
 */
export function eurosInput(cents) {
  if (cents === null || cents === undefined) return "";

  return `${Math.floor(cents / 100)},${String(cents % 100).padStart(2, "0")}`;
}
