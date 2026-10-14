import { shop } from "./shop.js";

// The router decodes params, which would split a value that holds & or =. The raw path keeps them.
export const routeFilter = (route) => shop.parseFilterPath(route.path.split("/")[3] ?? "");

/**
 * @param base [String] the page path without filters
 * @param filter [Object]
 * @return [String]
 */
export function filteredPath(base, filter) {
  const segment = shop.filterPath(filter);
  return segment ? `${base}/${segment}` : base;
}
