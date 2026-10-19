import { formatPrice } from "./money.js";
import { session } from "./session.js";

/**
 * @param product [Object]
 * @return [String] the lowest to highest active variant price
 */
export function priceRange(product) {
  const prices = product.variants
    .filter((variant) => variant.status === "active")
    .map((variant) => variant.price_cents);
  if (!prices.length) return "";

  const low = Math.min(...prices);
  const high = Math.max(...prices);
  return low === high ? formatPrice(low) : `${formatPrice(low)} – ${formatPrice(high)}`;
}

/**
 * @param product [Object]
 * @return [Number, null] stock across tracked variants, or null when none is tracked
 */
export function stockTotal(product) {
  const tracked = product.variants.filter((variant) => variant.track_stock);
  return tracked.length ? tracked.reduce((sum, variant) => sum + variant.stock_quantity, 0) : null;
}

/**
 * @param product [Object]
 * @return [String, undefined] the smallest size of the first image
 */
export const thumbnail = (product) => product.images[0]?.sizes[0]?.url ?? product.images[0]?.url;

/**
 * @param product [Object]
 * @return [Boolean] true when the store needs weights and a published product has an active variant without one
 */
export const missingWeight = (product) => Boolean(session.tenant?.weight_required) && product.status === "published" &&
  product.variants.some((variant) => variant.status === "active" && variant.weight_grams === null);
