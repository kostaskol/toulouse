import { get } from "./api.js";

/**
 * @return [Array<Object>] the category tree
 */
export async function loadCategories() {
  return (await get("/categories")).categories;
}

/**
 * Flattens the tree in display order, for a select.
 *
 * @param tree [Array<Object>]
 * @return [Array<Object>] each category with its `depth` and a `label` indented by it
 */
export function flatten(tree, depth = 0) {
  return tree.flatMap((category) => [
    { ...category, depth, label: `${"— ".repeat(depth)}${category.name}` },
    ...flatten(category.children, depth + 1)
  ]);
}
